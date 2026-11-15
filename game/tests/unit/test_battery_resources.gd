extends GutTest
## R-003-13: the maximum battery and every drain rate live in .tres resources.
## The expected values mirror BALANCE.md §1.1 and §4.2; update both together.

const ROBOT_BATTERY_PATH := "res://resources/battery/robot_battery.tres"
const BASIC_LEGS_PATH := "res://resources/movement/basic_legs.tres"


func test_r_003_13_robot_battery_matches_balance() -> void:
	var config: BatteryConfigData = load(ROBOT_BATTERY_PATH) as BatteryConfigData
	assert_not_null(config, "robot_battery.tres exists and is a BatteryConfigData")
	if config == null:
		return
	assert_eq(config.maximum, 100.0, "maximum battery of the basic Core (BALANCE §1.1, §4.2)")
	assert_eq(config.passive_drain, 0.1, "passive drain per second (BALANCE §1.1)")
	assert_eq(config.run_drain, 0.15, "running drain per second (BALANCE §1.1)")
	assert_eq(config.low_threshold_ratio, 0.2, "low battery threshold (BALANCE §1.1)")


func test_r_003_13_basic_legs_walk_drain_matches_balance() -> void:
	var legs: MovementStatsData = load(BASIC_LEGS_PATH) as MovementStatsData
	assert_not_null(legs, "basic_legs.tres exists and is a MovementStatsData")
	if legs == null:
		return
	assert_eq(legs.walk_drain, 0.05, "walking drain of basic legs (BALANCE §4.2)")
