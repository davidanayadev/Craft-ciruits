extends GutTest
## R-003-13: the maximum battery and every drain rate live in .tres resources.
## Since spec 015 they are stats: the robot's base stats and the modifiers of
## the basic Core and legs (R-015-02); the low threshold stays in robot_battery.tres.
## The expected values mirror BALANCE.md §1.1 and §4.2; update both together.

const ROBOT_BATTERY_PATH := "res://resources/battery/robot_battery.tres"
const BASE_STATS_PATH := "res://resources/robot/robot_base_stats.tres"
const BASIC_CORE_PATH := "res://resources/pieces/basic_core.tres"
const BASIC_LEGS_PATH := "res://resources/pieces/basic_legs.tres"


## Stats with the pieces of paths equipped.
func _stats_with(paths: Array[String]) -> StatsComponent:
	var stats: StatsComponent = StatsComponent.new()
	stats.base_stats = load(BASE_STATS_PATH) as RobotBaseStatsData
	add_child_autofree(stats)
	var modifiers: Array[StatModifier] = []
	for path: String in paths:
		var piece: PieceData = load(path) as PieceData
		modifiers.append_array(piece.modifiers)
	stats.recompute(modifiers)
	return stats


func test_r_003_13_robot_battery_matches_balance() -> void:
	var config: BatteryConfigData = load(ROBOT_BATTERY_PATH) as BatteryConfigData
	assert_not_null(config, "robot_battery.tres exists and is a BatteryConfigData")
	if config == null:
		return
	assert_eq(config.low_threshold_ratio, 0.2, "low battery threshold (BALANCE §1.1)")
	var stats: StatsComponent = _stats_with([BASIC_CORE_PATH])
	assert_eq(stats.get_stat(StatIds.MAX_BATTERY), 100.0, "maximum battery of the basic Core (BALANCE §1.1, §4.2)")
	assert_eq(stats.get_stat(StatIds.PASSIVE_DRAIN), 0.1, "passive drain per second (BALANCE §1.1)")
	assert_eq(stats.get_stat(StatIds.RUN_DRAIN), 0.15, "running drain per second (BALANCE §1.1)")


func test_r_003_13_basic_legs_walk_drain_matches_balance() -> void:
	var stats: StatsComponent = _stats_with([BASIC_LEGS_PATH])
	assert_eq(stats.get_stat(StatIds.WALK_DRAIN), 0.05, "walking drain of basic legs (BALANCE §4.2)")
