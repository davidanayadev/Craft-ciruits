extends GutTest
## Robot melee combat (spec 007) with real physics: the robot fights with one
## arm (R-007-02), the attack input starts a swing with its animation and the
## impact hurts what is in front (R-007-06), not with a depleted battery or a
## screen open (R-007-09), every swing costs battery (R-007-10), the impact
## hurts every enemy in the box once (R-007-11) and nothing else (R-007-12),
## without auto-aim (R-007-13), while the robot keeps moving and turning
## (R-007-14). The robot has a player uid (R-007-18) and earns the XP of what
## it kills (R-007-20).
## Values come from the real .tres files; target HP is a test input.

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const ZOMBIE_SCENE := preload("res://scenes/entities/zombie.tscn")
const ONE_ARM_PATH := "res://resources/combat/one_arm.tres"
const COMBAT_CONFIG_PATH := "res://resources/config/combat.tres"
const SLOW_PATH := "res://resources/enemies/zombie_slow.tres"
const HEX_PATTERN := "^[0-9a-f]{32}$"
const TARGET_HP := 1000
const BRAIN_SEED := 7
const DROP_SEED := 4321
## Far from the origin, where the other tests put their robots.
const FAR := Vector3(60.0, 0.0, 60.0)
## Frames for a new or moved hurtbox to be where the physics server sees it.
const SETTLE_FRAMES := 2
## Passive battery drain while a test waits (BALANCE §1.1), with slack.
const DRAIN_SLACK := 0.1
const ACTIONS: Array[StringName] = [&"move_forward", &"attack"]

var _robot: Robot
var _attack: AttackStatsData
var _config: CombatConfigData


func before_each() -> void:
	_attack = load(ONE_ARM_PATH) as AttackStatsData
	_config = load(COMBAT_CONFIG_PATH) as CombatConfigData
	_robot = _new_robot(Vector3.ZERO)
	watch_signals(_robot.melee)


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _new_robot(at: Vector3) -> Robot:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.global_position = at
	return robot


## A hittable target with the body of a zombie, standing at the given point.
func _new_target(at: Vector3) -> HurtboxComponent:
	var health: HealthComponent = HealthComponent.new()
	add_child_autofree(health)
	health.reset(TARGET_HP)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.health = health
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	hurtbox.add_child(shape)
	hurtbox.position = at
	add_child_autofree(hurtbox)
	return hurtbox


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _lost(target: HurtboxComponent) -> int:
	return TARGET_HP - target.health.get_current()


## One tap of the attack button, then the frames for its impact to land.
func _swing_once() -> void:
	_robot.player_input.set_attack_button_held(true)
	_robot.player_input.set_attack_button_held(false)
	await wait_physics_frames(_frames_for(_config.impact_time_s) + SETTLE_FRAMES)


func test_r_007_02_robot_attacks_with_one_arm() -> void:
	assert_not_null(_attack, "one_arm.tres exists")
	assert_same(_robot.melee.attack, _attack, "the robot fights with one arm")
	assert_same(_robot.melee.config, _config, "and the shared combat config")


func test_r_007_06_button_starts_swing_and_animation() -> void:
	var player: AnimationPlayer = _robot.get_node("%AnimationPlayer") as AnimationPlayer
	assert_true(player.has_animation(Robot.ANIMATION_ATTACK), "the robot has an attack animation")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_signal_not_emitted(_robot.melee, "swing_started", "no swing without input")
	_robot.player_input.set_attack_button_held(true)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "the button starts a swing")
	assert_eq(player.current_animation, String(Robot.ANIMATION_ATTACK), "with its animation")


func test_r_007_06_attack_action_starts_swing() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"attack"
	event.pressed = true
	Input.parse_input_event(event)
	await wait_physics_frames(SETTLE_FRAMES * 2)
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "the attack action starts a swing")


func test_r_007_06_short_tap_not_lost() -> void:
	_robot.player_input.set_attack_button_held(true)
	_robot.player_input.set_attack_button_held(false)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "a tap between two steps still swings")


func test_r_007_06_impact_at_impact_moment() -> void:
	var target: HurtboxComponent = _new_target(Vector3(0.0, 0.0, -1.5))
	await wait_physics_frames(SETTLE_FRAMES)
	_robot.player_input.set_attack_button_held(true)
	_robot.player_input.set_attack_button_held(false)
	await wait_physics_frames(_frames_for(_config.impact_time_s * 0.5))
	assert_eq(_lost(target), 0, "no damage before the impact moment")
	await wait_physics_frames(_frames_for(_config.impact_time_s * 0.5) + SETTLE_FRAMES)
	assert_eq(_lost(target), _attack.damage, "the damage of the arms lands at the impact")
	await wait_physics_frames(_frames_for(_config.impact_time_s))
	assert_eq(_lost(target), _attack.damage, "once per swing")


func test_r_007_07_held_swings_once_per_interval() -> void:
	var seconds: float = CombatSystem.swing_interval(_attack) * 1.5
	_robot.player_input.set_attack_button_held(true)
	await wait_physics_frames(_frames_for(seconds))
	assert_signal_emit_count(_robot.melee, "swing_started", 2, "the first at once, the second an interval later")


func test_r_007_09_no_swing_when_depleted_or_screen_open() -> void:
	var before: float = _robot.battery.get_current()
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_SCREEN)
	_robot.player_input.set_attack_button_held(true)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_signal_not_emitted(_robot.melee, "swing_started", "no swing while a screen is open")
	assert_almost_eq(_robot.battery.get_current(), before, DRAIN_SLACK, "and no battery spent")
	_robot.battery.consume(_robot.battery.get_current())
	_robot.player_input.set_input_blocked(false, PlayerInput.REASON_SCREEN)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_signal_not_emitted(_robot.melee, "swing_started", "nor with a depleted battery")


func test_r_007_10_swing_costs_battery_on_miss() -> void:
	var before: float = _robot.battery.get_current()
	await _swing_once()
	assert_signal_not_emitted(_robot.melee, "hit_dealt", "the swing hit nothing")
	var lost: float = before - _robot.battery.get_current()
	assert_between(lost, _attack.battery_cost, _attack.battery_cost + DRAIN_SLACK, "it cost its battery")


func test_r_007_10_swing_can_deplete_battery() -> void:
	_robot.battery.consume(_robot.battery.get_current() - _attack.battery_cost * 0.5)
	watch_signals(_robot.battery)
	assert_false(_robot.battery.is_depleted(), "some battery left, less than a swing costs")
	_robot.player_input.set_attack_button_held(true)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "the swing still starts")
	assert_true(_robot.battery.is_depleted(), "and it empties the battery")
	assert_signal_emit_count(_robot.battery, "battery_depleted", 1)


func test_r_007_11_hits_every_enemy_in_box() -> void:
	var near: HurtboxComponent = _new_target(Vector3(-0.3, 0.0, -1.0))
	var far: HurtboxComponent = _new_target(Vector3(0.3, 0.0, -1.9))
	await wait_physics_frames(SETTLE_FRAMES)
	await _swing_once()
	assert_eq(_lost(near), _attack.damage, "the near enemy is hit once")
	assert_eq(_lost(far), _attack.damage, "and so is the far one")
	assert_signal_emit_count(_robot.melee, "hit_dealt", 2, "one hit_dealt per enemy")
	assert_eq(near.get_last_attacker_uid(), _robot.player_uid, "in the name of this robot")


func test_r_007_11_out_of_the_box_is_not_hit() -> void:
	var behind: HurtboxComponent = _new_target(Vector3(0.0, 0.0, 1.5))
	var beside: HurtboxComponent = _new_target(Vector3(1.5, 0.0, -1.0))
	var beyond: HurtboxComponent = _new_target(Vector3(0.0, 0.0, -_config.hitbox_reach_m - 1.0))
	await wait_physics_frames(SETTLE_FRAMES)
	await _swing_once()
	assert_eq(_lost(behind), 0, "behind the robot")
	assert_eq(_lost(beside), 0, "beside the box")
	assert_eq(_lost(beyond), 0, "beyond the reach")
	assert_signal_not_emitted(_robot.melee, "hit_dealt")


func test_r_007_12_ignores_robot_boxes_and_scenery() -> void:
	var scenery: StaticBody3D = StaticBody3D.new()
	var scenery_shape: CollisionShape3D = CollisionShape3D.new()
	scenery_shape.shape = BoxShape3D.new()
	scenery.add_child(scenery_shape)
	scenery.position = Vector3(0.0, 0.5, -1.5)
	add_child_autofree(scenery)
	var interactable: InteractableComponent = InteractableComponent.new()
	var interactable_shape: CollisionShape3D = CollisionShape3D.new()
	interactable_shape.shape = SphereShape3D.new()
	interactable.add_child(interactable_shape)
	interactable.position = Vector3(0.0, 0.5, -1.0)
	add_child_autofree(interactable)
	var other_player: Robot = _new_robot(Vector3(0.0, 0.0, -1.2))
	var other_battery: float = other_player.battery.get_current()
	var own_battery: float = _robot.battery.get_current()
	await wait_physics_frames(SETTLE_FRAMES)
	await _swing_once()
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "the swing happened")
	assert_signal_not_emitted(_robot.melee, "hit_dealt", "nothing in the box is an enemy")
	assert_almost_eq(other_player.battery.get_current(), other_battery, DRAIN_SLACK, "no friendly fire")
	assert_almost_eq(
		_robot.battery.get_current(), own_battery - _attack.battery_cost, DRAIN_SLACK, "only the cost"
	)
	assert_push_error_count(0)


func test_r_007_12_no_hitbox_node_outside_the_impact() -> void:
	assert_eq(_robot.melee.find_children("*", "Area3D", true, false).size(), 0, "no standing hitbox")


func test_r_007_13_no_auto_aim() -> void:
	var beside: HurtboxComponent = _new_target(Vector3(1.5, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	var facing: float = _robot.rotation.y
	await _swing_once()
	assert_eq(_robot.rotation.y, facing, "the swing does not turn the robot toward the enemy")
	assert_eq(_lost(beside), 0, "and the enemy at its side is not hit")


func test_r_007_14_moves_while_swinging() -> void:
	var start: Vector3 = _robot.global_position
	Input.action_press(&"move_forward")
	_robot.player_input.set_attack_button_held(true)
	await wait_physics_frames(_frames_for(_config.impact_time_s) + SETTLE_FRAMES)
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "swinging")
	assert_false(_robot.melee.is_impact_pending(), "through its impact")
	var walked: float = _robot.global_position.distance_to(start)
	var expected: float = _robot.movement_stats.walk_speed * _config.impact_time_s
	assert_gt(walked, expected * 0.8, "while walking at full speed")


func test_r_007_14_hitbox_follows_facing() -> void:
	var front_at_start: HurtboxComponent = _new_target(Vector3(0.0, 0.0, -1.5))
	var front_at_impact: HurtboxComponent = _new_target(Vector3(1.5, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	_robot.player_input.set_attack_button_held(true)
	_robot.player_input.set_attack_button_held(false)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_robot.melee.is_impact_pending(), "the swing started facing -Z")
	# Turns to +X in the middle of the swing.
	_robot.rotation.y = LocomotionSystem.target_yaw(Vector3.RIGHT)
	await wait_physics_frames(_frames_for(_config.impact_time_s) + SETTLE_FRAMES)
	assert_eq(_lost(front_at_impact), _attack.damage, "the impact lands where the robot faces then")
	assert_eq(_lost(front_at_start), 0, "not where it faced when the swing started")


func test_r_007_18_robot_has_player_uid() -> void:
	var regex: RegEx = RegEx.create_from_string(HEX_PATTERN)
	assert_not_null(regex.search(_robot.player_uid), "a generated uid: '%s'" % _robot.player_uid)
	var other: Robot = _new_robot(FAR)
	assert_ne(other.player_uid, _robot.player_uid, "each robot has its own")


func test_r_007_18_melee_uses_player_uid() -> void:
	assert_eq(_robot.melee.attacker_uid, _robot.player_uid, "kills count for this robot")


func test_r_007_19_robot_owns_experience() -> void:
	assert_not_null(_robot.experience, "the robot has an ExperienceComponent")
	assert_eq(_robot.experience.get_total(), 0, "starting at 0")


func test_r_007_20_kill_adds_xp() -> void:
	var slow: EnemyData = load(SLOW_PATH) as EnemyData
	var bystander: Robot = _new_robot(FAR + Vector3(30.0, 0.0, 0.0))
	_robot.global_position = FAR
	var zombie: Zombie = ZOMBIE_SCENE.instantiate() as Zombie
	add_child_autofree(zombie)
	# Inside its attack range, so it stands still in front of the robot.
	zombie.activate(slow, FAR + Vector3(0.0, 0.0, -slow.ai.attack_range * 0.9), BRAIN_SEED, DROP_SEED)
	watch_signals(EventBus)
	watch_signals(_robot.experience)
	await wait_physics_frames(SETTLE_FRAMES)
	_robot.player_input.set_attack_button_held(true)
	var hits_to_kill: int = ceili(float(slow.hp_max) / float(_attack.damage))
	var seconds: float = (
		CombatSystem.swing_interval(_attack) * (hits_to_kill - 1) + _config.impact_time_s
	)
	await wait_physics_frames(_frames_for(seconds) - SETTLE_FRAMES * 2)
	assert_false(zombie.get_health().is_dead(), "alive until the last hit lands")
	assert_eq(_robot.experience.get_total(), 0, "no XP before the kill")
	await wait_physics_frames(SETTLE_FRAMES * 4)
	_robot.player_input.set_attack_button_held(false)
	assert_true(zombie.get_health().is_dead(), "%d hits kill a slow zombie" % hits_to_kill)
	assert_signal_emit_count(EventBus, "enemy_killed", 1, "the kill is announced once")
	assert_signal_emitted_with_parameters(EventBus, "enemy_killed", [slow.id, _robot.player_uid])
	assert_eq(_robot.experience.get_total(), slow.xp_reward, "the robot earns the XP of its data")
	assert_signal_emit_count(_robot.experience, "xp_changed", 1)
	assert_eq(bystander.experience.get_total(), 0, "another player earns nothing from this kill")
	assert_signal_emit_count(_robot.melee, "hit_dealt", hits_to_kill, "one hit_dealt per hit")
