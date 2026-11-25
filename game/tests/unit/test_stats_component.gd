extends GutTest
## StatsComponent (spec 015): the stats of one entity, computed from its base
## and the modifiers it is given (R-015-05), with one stats_changed per
## recompute (R-015-13), and typed views for movement and attack (plan D2).

const BASE_STATS_PATH := "res://resources/robot/robot_base_stats.tres"
const BASIC_ARMS_PATH := "res://resources/pieces/basic_arms.tres"
const BASIC_LEGS_PATH := "res://resources/pieces/basic_legs.tres"


func _make_stats() -> StatsComponent:
	var stats: StatsComponent = StatsComponent.new()
	stats.base_stats = load(BASE_STATS_PATH) as RobotBaseStatsData
	add_child_autofree(stats)
	return stats


func _modifiers_of(path: String) -> Array[StatModifier]:
	var piece: PieceData = load(path) as PieceData
	return piece.modifiers.duplicate()


func test_r_015_05_base_until_first_recompute() -> void:
	var stats: StatsComponent = _make_stats()
	assert_eq(stats.get_stat(StatIds.ATTACK_DAMAGE), 5.0, "one arm (BALANCE §4.2)")
	assert_eq(stats.get_stat(StatIds.WALK_SPEED), 0.5, "no legs (BALANCE §4.2)")


func test_r_015_05_only_given_modifiers_count() -> void:
	var stats: StatsComponent = _make_stats()
	stats.recompute(_modifiers_of(BASIC_ARMS_PATH))
	assert_eq(stats.get_stat(StatIds.ATTACK_DAMAGE), 10.0, "basic arms (BALANCE §4.2)")
	assert_eq(stats.get_stat(StatIds.WALK_SPEED), 0.5, "legs not given: no legs")
	stats.recompute([])
	assert_eq(stats.get_stat(StatIds.ATTACK_DAMAGE), 5.0, "back to one arm: the base never changes")


func test_r_015_13_recompute_emits_once() -> void:
	var stats: StatsComponent = _make_stats()
	watch_signals(stats)
	stats.recompute(_modifiers_of(BASIC_LEGS_PATH))
	assert_signal_emit_count(stats, "stats_changed", 1, "one stats_changed per recompute")
	stats.recompute(_modifiers_of(BASIC_LEGS_PATH))
	assert_signal_emit_count(stats, "stats_changed", 2, "state signal: also when nothing changed")


func test_r_015_13_unknown_stat_reported() -> void:
	var stats: StatsComponent = _make_stats()
	assert_eq(stats.get_stat(&"armour"), 0.0, "an unknown stat reads 0")
	assert_push_error("armour")


func test_r_015_15_movement_without_legs_cannot_run() -> void:
	var stats: StatsComponent = _make_stats()
	var movement: MovementStatsData = stats.get_movement()
	assert_eq(movement.walk_speed, 0.5, "no legs walk speed")
	assert_eq(movement.run_speed, 0.0, "no legs run speed")
	assert_false(movement.can_run, "can_run = run_speed > 0 (plan D2)")
	assert_eq(movement.walk_drain, 0.1, "no legs walk drain")


func test_r_015_15_movement_with_legs() -> void:
	var stats: StatsComponent = _make_stats()
	stats.recompute(_modifiers_of(BASIC_LEGS_PATH))
	var movement: MovementStatsData = stats.get_movement()
	assert_eq(movement.walk_speed, 3.0, "basic legs walk speed")
	assert_eq(movement.run_speed, 4.8, "basic legs run speed")
	assert_true(movement.can_run, "legs that run")
	assert_eq(movement.walk_drain, 0.05, "basic legs walk drain")


func test_r_015_16_attack_view() -> void:
	var stats: StatsComponent = _make_stats()
	var one_arm: AttackStatsData = stats.get_attack()
	assert_eq(one_arm.damage, 5, "one arm damage")
	assert_eq(one_arm.attacks_per_second, 1.0, "one arm rate")
	assert_eq(one_arm.battery_cost, 1.0, "one arm cost")
	stats.recompute(_modifiers_of(BASIC_ARMS_PATH))
	assert_eq(stats.get_attack().damage, 10, "basic arms damage")
	assert_eq(one_arm.damage, 5, "views are new objects, never shared")
