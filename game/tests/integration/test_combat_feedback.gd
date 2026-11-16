extends GutTest
## Combat feedback (spec 007): a hit dealt shakes the camera with the "hit
## dealt" values and plays pooled sparks at the enemy (R-007-24), a hit
## received shakes it with the "hit received" values and flashes the screen
## edges (R-007-25), none of it changes battery, HP or XP (R-007-26) and the
## sparks come from the pool and go back to it (R-007-27).
## Values come from combat_feedback.tres; the signals are emitted by hand.

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const RIG_SCENE := preload("res://scenes/camera/camera_rig.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const SPARKS_SCENE := preload("res://scenes/effects/impact_sparks.tscn")
const FEEDBACK_PATH := "res://resources/config/combat_feedback.tres"
const TARGET_HP := 20
const TARGET_POSITION := Vector3(3.0, 0.0, -4.0)
const HIT_DAMAGE := 5.0
## A sliver of time, to read the strength a shake starts with.
const TINY_STEP := 0.0001

var _robot: Robot
var _rig: CameraRig
var _hud: Hud
var _pool: ObjectPool
var _effects_root: Node3D
var _feedback: CombatFeedback
var _config: CombatFeedbackData
var _target: HurtboxComponent


func before_each() -> void:
	_config = load(FEEDBACK_PATH) as CombatFeedbackData
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	# The battery only moves if the feedback moves it.
	_robot.set_physics_process(false)
	_rig = RIG_SCENE.instantiate() as CameraRig
	add_child_autofree(_rig)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child_autofree(_hud)
	_pool = ObjectPool.new()
	_pool.name = "ImpactPool"
	_pool.scene = SPARKS_SCENE
	add_child_autofree(_pool)
	_effects_root = Node3D.new()
	add_child_autofree(_effects_root)
	_feedback = _new_feedback(_pool)
	_feedback.bind(_robot, _rig, _hud)
	_target = _new_target()


func _new_feedback(pool: ObjectPool) -> CombatFeedback:
	var feedback: CombatFeedback = CombatFeedback.new()
	feedback.name = "CombatFeedback"
	feedback.config = _config
	feedback.impact_pool = pool
	feedback.effects_root = _effects_root
	add_child_autofree(feedback)
	return feedback


func _new_target() -> HurtboxComponent:
	var health: HealthComponent = HealthComponent.new()
	add_child_autofree(health)
	health.reset(TARGET_HP)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.health = health
	hurtbox.position = TARGET_POSITION
	add_child_autofree(hurtbox)
	return hurtbox


func _playing_sparks() -> Array[ImpactSparks]:
	var playing: Array[ImpactSparks] = []
	for child: Node in _effects_root.get_children():
		var sparks: ImpactSparks = child as ImpactSparks
		if sparks != null:
			playing.append(sparks)
	return playing


func _shake_offset() -> float:
	_rig.advance_shake(TINY_STEP)
	return Vector2(_rig.camera.h_offset, _rig.camera.v_offset).length()


func _damage_flash() -> DamageFlash:
	return _hud.get_node("%DamageFlash") as DamageFlash


func test_r_007_24_hit_dealt_shakes_and_sparks() -> void:
	_robot.melee.hit_dealt.emit(_target)
	assert_true(_rig.is_shaking(), "a hit dealt shakes the camera")
	assert_almost_eq(_shake_offset(), _config.hit_dealt_shake_m, 0.001, "with the hit dealt strength")
	var playing: Array[ImpactSparks] = _playing_sparks()
	assert_eq(playing.size(), 1, "and plays one burst of sparks")
	if playing.size() == 1:
		assert_almost_eq(playing[0].global_position, TARGET_POSITION, Vector3.ONE * 0.001, "at the enemy")
	assert_false(_damage_flash().visible, "the screen edge is for hits received")


func test_r_007_24_shake_lasts_hit_dealt_time() -> void:
	_robot.melee.hit_dealt.emit(_target)
	_rig.advance_shake(_config.hit_dealt_shake_s * 0.5)
	assert_true(_rig.is_shaking(), "still shaking halfway")
	_rig.advance_shake(_config.hit_dealt_shake_s * 0.5)
	assert_false(_rig.is_shaking(), "over after the hit dealt duration")


func test_r_007_25_hit_received_shakes_and_flashes() -> void:
	_robot.hit_received.emit(HIT_DAMAGE, _target)
	assert_true(_rig.is_shaking(), "a hit received shakes the camera")
	assert_almost_eq(_shake_offset(), _config.hit_received_shake_m, 0.001, "with the hit received strength")
	var flash: DamageFlash = _damage_flash()
	assert_true(flash.visible, "and the screen edges flash red")
	flash.advance(_config.screen_edge_flash_s * 0.5)
	assert_true(flash.visible, "still red halfway")
	flash.advance(_config.screen_edge_flash_s * 0.5)
	assert_false(flash.visible, "gone after the screen edge duration")
	assert_eq(_playing_sparks().size(), 0, "no sparks for a hit received")


func test_r_007_25_shake_lasts_hit_received_time() -> void:
	_robot.hit_received.emit(HIT_DAMAGE, _target)
	_rig.advance_shake(_config.hit_received_shake_s * 0.5)
	assert_true(_rig.is_shaking(), "still shaking halfway")
	_rig.advance_shake(_config.hit_received_shake_s * 0.5)
	assert_false(_rig.is_shaking(), "over after the hit received duration")


func test_r_007_26_feedback_changes_no_state() -> void:
	var battery: float = _robot.battery.get_current()
	watch_signals(_robot.battery)
	watch_signals(_target.health)
	watch_signals(_robot.experience)
	_robot.melee.hit_dealt.emit(_target)
	_robot.hit_received.emit(HIT_DAMAGE, _target)
	assert_eq(_robot.battery.get_current(), battery, "the battery is as it was")
	assert_eq(_target.health.get_current(), TARGET_HP, "so is the enemy HP")
	assert_eq(_robot.experience.get_total(), 0, "and the XP")
	assert_signal_not_emitted(_robot.battery, "battery_changed")
	assert_signal_not_emitted(_target.health, "health_changed")
	assert_signal_not_emitted(_robot.experience, "xp_changed")
	assert_eq(_target.get_last_attacker_uid(), "", "the feedback attacked nobody")


func test_r_007_27_sparks_from_pool_and_back() -> void:
	_pool.prewarm(1)
	assert_eq(_pool.get_free_count(), 1, "one burst waiting in the pool")
	_robot.melee.hit_dealt.emit(_target)
	assert_eq(_pool.get_free_count(), 0, "the burst came from the pool")
	var playing: Array[ImpactSparks] = _playing_sparks()
	if playing.size() != 1:
		fail_test("expected one burst playing, got %d" % playing.size())
		return
	var sparks: ImpactSparks = playing[0]
	var particles: GPUParticles3D = sparks.get_node("%Particles") as GPUParticles3D
	assert_true(particles.one_shot, "a one-shot emitter")
	# The emitter's own signal ends the burst: no real time in tests.
	particles.finished.emit()
	await wait_process_frames(2)
	assert_eq(_pool.get_free_count(), 1, "it went back to the pool when it finished")
	assert_false(sparks.is_inside_tree(), "out of the scene")
	_robot.melee.hit_dealt.emit(_target)
	var again: Array[ImpactSparks] = _playing_sparks()
	assert_eq(again.size(), 1, "the next hit plays a burst")
	if again.size() == 1:
		assert_same(again[0], sparks, "the same instance, reused")
	particles.finished.emit()
	await wait_process_frames(2)
	assert_eq(_pool.get_free_count(), 1, "and it goes back again, once")
	assert_push_error_count(0)


func test_r_007_27_pool_grows_when_empty() -> void:
	_robot.melee.hit_dealt.emit(_target)
	_robot.melee.hit_dealt.emit(_target)
	assert_eq(_playing_sparks().size(), 2, "two hits at once play two bursts")


func test_r_007_27_sparks_within_budget() -> void:
	var sparks: ImpactSparks = SPARKS_SCENE.instantiate() as ImpactSparks
	add_child_autofree(sparks)
	var particles: GPUParticles3D = sparks.get_node("%Particles") as GPUParticles3D
	assert_false(particles.emitting, "silent until played")
	assert_lte(particles.amount, 16, "a handful of particles per burst")
	assert_eq(sparks.find_children("*", "Light3D", true, false).size(), 0, "and no light (PMV §3.2)")


func test_r_007_26_bind_without_data_reports_error() -> void:
	var broken: CombatFeedback = _new_feedback(null)
	broken.name = "Broken"
	broken.bind(_robot, _rig, _hud)
	assert_push_error("Broken")
