extends GutTest
## MeleeAttackComponent (spec 007), driven by hand through tick(): its box
## comes from the data (R-007-04), a swing starts when asked and lands after
## the impact time (R-007-06), holding swings at the rate of the attack and a
## press in between is not kept (R-007-07), the start carries the battery cost
## (R-007-10), the impact hurts each living target once (R-007-11), the query
## sees only hurtbox areas (R-007-12) and nothing turns the owner (R-007-13).
## No physics targets here: apply_impact() gets hand-made hurtboxes.
## The numbers are arbitrary test inputs, exact in binary, not balance values.

const DAMAGE := 6
const ATTACKS_PER_SECOND := 2.0
const INTERVAL := 0.5
const COST := 1.5
const REACH := 3.0
const WIDTH := 1.5
const IMPACT_TIME := 0.25
const HEIGHT := 2.0
const CENTER_Y := 1.0
const STEP := 0.125
const TARGET_HP := 20
const ATTACKER_UID := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _owner: Node3D
var _melee: MeleeAttackComponent


func before_each() -> void:
	_owner = Node3D.new()
	add_child_autofree(_owner)
	_melee = _new_melee(_attack(), _config())
	_owner.add_child(_melee)
	watch_signals(_melee)


func _attack() -> AttackStatsData:
	var attack: AttackStatsData = AttackStatsData.new()
	attack.damage = DAMAGE
	attack.attacks_per_second = ATTACKS_PER_SECOND
	attack.battery_cost = COST
	return attack


func _config() -> CombatConfigData:
	var config: CombatConfigData = CombatConfigData.new()
	config.hitbox_reach_m = REACH
	config.hitbox_width_m = WIDTH
	config.impact_time_s = IMPACT_TIME
	return config


func _new_melee(attack: AttackStatsData, config: CombatConfigData) -> MeleeAttackComponent:
	var melee: MeleeAttackComponent = MeleeAttackComponent.new()
	melee.name = "Melee"
	melee.set_attack(attack)
	melee.config = config
	melee.hitbox_height_m = HEIGHT
	melee.hitbox_center_y_m = CENTER_Y
	melee.attacker_uid = ATTACKER_UID
	return melee


func _new_target() -> HurtboxComponent:
	var health: HealthComponent = HealthComponent.new()
	add_child_autofree(health)
	health.reset(TARGET_HP)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.health = health
	add_child_autofree(hurtbox)
	return hurtbox


## Ticks for the given number of steps with the same inputs.
func _tick(steps: int, wants_to_swing: bool) -> void:
	for i: int in steps:
		_melee.tick(STEP, wants_to_swing, false, false)


func test_r_007_04_hitbox_size_from_config() -> void:
	var shape: BoxShape3D = _melee.get_hitbox_shape()
	assert_not_null(shape, "the box is created in code")
	if shape == null:
		return
	assert_eq(shape.size, Vector3(WIDTH, HEIGHT, REACH), "width and reach from the config")
	var other: MeleeAttackComponent = _new_melee(_attack(), _config())
	_owner.add_child(other)
	assert_ne(other.get_hitbox_shape(), shape, "no two instances share the shape")


func test_r_007_04_hitbox_in_front_of_owner() -> void:
	_owner.global_position = Vector3(10.0, 0.0, 5.0)
	var box: Transform3D = _melee.get_hitbox_transform()
	assert_almost_eq(box.origin, Vector3(10.0, CENTER_Y, 5.0 - REACH / 2.0), Vector3.ONE * 0.0001)
	# From the owner's centre to the reach, towards -Z.
	assert_almost_eq(box.origin.z + REACH / 2.0, 5.0, 0.0001, "it starts at the owner's centre")
	assert_almost_eq(box.origin.z - REACH / 2.0, 5.0 - REACH, 0.0001, "and ends at the reach")


func test_r_007_04_missing_data_reports_error() -> void:
	var broken: MeleeAttackComponent = _new_melee(_attack(), null)
	broken.name = "Broken"
	_owner.add_child(broken)
	assert_push_error("Broken")
	watch_signals(broken)
	broken.tick(STEP, true, false, false)
	assert_signal_not_emitted(broken, "swing_started", "without a config it never swings")


## Spec 015 (plan D11): the attack arrives from its owner after _ready().
func test_r_015_16_no_attack_yet_never_swings() -> void:
	var waiting: MeleeAttackComponent = _new_melee(null, _config())
	_owner.add_child(waiting)
	watch_signals(waiting)
	waiting.tick(STEP, true, false, false)
	assert_signal_not_emitted(waiting, "swing_started", "without an attack it never swings")
	assert_push_error_count(0, "not an error: the owner sets it later")
	waiting.set_attack(_attack())
	waiting.tick(STEP, true, false, false)
	assert_signal_emit_count(waiting, "swing_started", 1, "it swings once it has one")


func test_r_007_06_swing_emits_started() -> void:
	_tick(1, false)
	assert_signal_not_emitted(_melee, "swing_started", "no swing unless asked")
	_tick(1, true)
	assert_signal_emit_count(_melee, "swing_started", 1, "the first swing starts at once")
	assert_true(_melee.is_impact_pending(), "and its impact is on its way")


func test_r_007_06_impact_after_impact_time() -> void:
	_tick(1, true)
	_tick(1, false)
	assert_true(_melee.is_impact_pending(), "half the impact time: not yet")
	_tick(1, false)
	assert_false(_melee.is_impact_pending(), "the impact lands at the impact time")


func test_r_007_06_no_impact_without_swing() -> void:
	_tick(8, false)
	assert_false(_melee.is_impact_pending(), "nothing is pending")
	assert_signal_not_emitted(_melee, "hit_dealt")


func test_r_007_07_held_swings_at_rate() -> void:
	# 2 seconds held at 2 swings per second: starts at 0, 0.5, 1.0 and 1.5 s.
	_tick(16, true)
	assert_signal_emit_count(_melee, "swing_started", 4, "one swing per interval")
	_tick(1, true)
	assert_signal_emit_count(_melee, "swing_started", 5, "the fifth at exactly 2.0 s")


func test_r_007_07_press_during_swing_not_queued() -> void:
	_tick(1, true)
	_tick(1, true)
	_tick(1, false)
	assert_signal_emit_count(_melee, "swing_started", 1, "a press during the swing does nothing")
	_tick(6, false)
	assert_signal_emit_count(_melee, "swing_started", 1, "and is not kept for later")
	_tick(1, true)
	assert_signal_emit_count(_melee, "swing_started", 2, "a new press after the interval swings")


func test_r_007_09_depleted_or_blocked_does_not_start() -> void:
	_melee.tick(STEP, true, true, false)
	_melee.tick(STEP, true, false, true)
	assert_signal_not_emitted(_melee, "swing_started", "neither depleted nor blocked starts a swing")
	_melee.tick(STEP, true, false, false)
	assert_signal_emit_count(_melee, "swing_started", 1, "it starts once both clear")


func test_r_007_09_started_swing_still_lands() -> void:
	_tick(1, true)
	_melee.tick(STEP, false, true, true)
	_melee.tick(STEP, false, true, true)
	assert_false(_melee.is_impact_pending(), "a swing already paid for reaches its impact")


func test_r_007_10_started_carries_cost() -> void:
	_tick(1, true)
	assert_signal_emitted_with_parameters(_melee, "swing_started", [COST])


func test_r_007_11_damages_each_living_target_once() -> void:
	var first: HurtboxComponent = _new_target()
	var second: HurtboxComponent = _new_target()
	var dead: HurtboxComponent = _new_target()
	dead.receive_attack(TARGET_HP, ATTACKER_UID)
	var targets: Array[HurtboxComponent] = [first, second, first, dead, null]
	_melee.apply_impact(targets)
	assert_eq(first.health.get_current(), TARGET_HP - DAMAGE, "hit once, although listed twice")
	assert_eq(second.health.get_current(), TARGET_HP - DAMAGE, "every target in the box is hit")
	assert_signal_emit_count(_melee, "hit_dealt", 2, "one hit_dealt per target damaged")
	assert_eq(first.get_last_attacker_uid(), ATTACKER_UID, "in the name of the owner")
	assert_push_error_count(0)


func test_r_007_11_impact_without_targets() -> void:
	var targets: Array[HurtboxComponent] = []
	_melee.apply_impact(targets)
	assert_signal_not_emitted(_melee, "hit_dealt", "a miss hurts nobody")


func test_r_007_12_query_masks_only_hurtboxes() -> void:
	var query: PhysicsShapeQueryParameters3D = _melee.build_query()
	assert_eq(query.collision_mask, 1 << (HurtboxComponent.PHYSICS_LAYER - 1), "only the hurtbox layer")
	assert_true(query.collide_with_areas, "hurtboxes are areas")
	assert_false(query.collide_with_bodies, "no body: not the owner, a box or the scenery")
	assert_same(query.shape, _melee.get_hitbox_shape(), "with its own box")
	assert_eq(query.transform, _melee.get_hitbox_transform(), "placed in front of the owner")


func test_r_007_12_no_area_of_its_own() -> void:
	assert_eq(_melee.find_children("*", "Area3D", true, false).size(), 0, "no hitbox outside the impact")
	assert_eq(_melee.find_children("*", "CollisionShape3D", true, false).size(), 0, "nor a shape")


func test_r_007_13_swing_does_not_turn_owner() -> void:
	_owner.rotation.y = 1.0
	var before: Transform3D = _owner.global_transform
	_tick(8, true)
	assert_eq(_owner.global_transform, before, "the swing leaves the owner as it was")
	assert_almost_eq(
		_melee.get_hitbox_transform().basis.get_euler().y, 1.0, 0.0001, "the box follows its facing"
	)


# --- Spec 008: cancel_swing (a dead robot does not strike) -----------------------


func test_r_008_25_cancel_drops_pending_impact() -> void:
	_tick(1, true)
	assert_true(_melee.is_impact_pending(), "setup: the impact is on its way")
	_melee.cancel_swing()
	assert_false(_melee.is_impact_pending(), "the impact is gone")
	_tick(4, false)
	assert_false(_melee.is_impact_pending(), "and does not come back past the impact time")
	assert_signal_not_emitted(_melee, "hit_dealt", "nothing was hit")


func test_r_008_25_cancel_keeps_the_swing_interval() -> void:
	_tick(1, true)
	assert_signal_emit_count(_melee, "swing_started", 1)
	_melee.cancel_swing()
	# The cost stays paid: a new swing waits the normal interval (0.5 s = 4 steps).
	_tick(3, true)
	assert_signal_emit_count(_melee, "swing_started", 1, "still inside the interval")
	_tick(1, true)
	assert_signal_emit_count(_melee, "swing_started", 2, "a new swing at the normal interval")
	assert_true(_melee.is_impact_pending(), "and its impact is pending again")


func test_r_008_25_cancel_with_nothing_pending_is_noop() -> void:
	_melee.cancel_swing()
	assert_false(_melee.is_impact_pending())
	assert_signal_not_emitted(_melee, "swing_started")
	assert_push_error_count(0)
	_tick(1, true)
	assert_signal_emit_count(_melee, "swing_started", 1, "the first swing still starts at once")


# --- Arms that change (spec 015) ---------------------------------------------


func _stronger_attack() -> AttackStatsData:
	var attack: AttackStatsData = _attack()
	attack.damage = DAMAGE * 2
	return attack


func test_r_015_17_pending_swing_keeps_its_values() -> void:
	var target: HurtboxComponent = _new_target()
	_melee.tick(STEP, true, false, false)
	_melee.set_attack(_stronger_attack())
	_melee.apply_impact([target])
	assert_eq(target.health.get_current(), TARGET_HP - DAMAGE, "the swing lands with the values it started with")


func test_r_015_17_next_swing_uses_new_values() -> void:
	_melee.set_attack(_stronger_attack())
	var target: HurtboxComponent = _new_target()
	_melee.tick(STEP, true, false, false)
	_melee.apply_impact([target])
	assert_eq(target.health.get_current(), TARGET_HP - DAMAGE * 2, "a new swing uses the new values")


func test_r_015_17_new_cost_from_next_swing() -> void:
	_melee.tick(STEP, true, false, false)
	var cheaper: AttackStatsData = _attack()
	cheaper.battery_cost = COST / 2.0
	_melee.set_attack(cheaper)
	_melee.tick(INTERVAL, true, false, false)
	assert_signal_emitted_with_parameters(_melee, "swing_started", [COST / 2.0], 1)
