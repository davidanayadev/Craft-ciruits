extends GutTest
## ChassisLevelSystem (spec 014): the pure rules that turn a total XP into a
## chassis level. Covers R-014-01 (level count comes from the table), R-014-03
## (highest level whose accumulated threshold is reached), R-014-04 (XP above the
## last threshold is the last level), R-014-05 (invalid input reports an error)
## and R-014-20 (XP missing for the next level).
## Expected values on the balance table mirror BALANCE.md §6.1; update both together.

const CHASSIS_LEVELS_PATH := "res://resources/progression/chassis_levels.tres"


func _new_levels(xp_required: Array[int], inventory_slots: Array[int]) -> ChassisLevelData:
	var levels: ChassisLevelData = ChassisLevelData.new()
	levels.xp_required = xp_required
	levels.inventory_slots = inventory_slots
	return levels


func _balance_levels() -> ChassisLevelData:
	var levels: ChassisLevelData = load(CHASSIS_LEVELS_PATH) as ChassisLevelData
	assert_not_null(levels, "chassis_levels.tres exists and is a ChassisLevelData")
	return levels


func test_r_014_01_level_count_comes_from_table() -> void:
	var levels: ChassisLevelData = _new_levels([0, 10, 30], [5, 6, 7])
	assert_eq(ChassisLevelSystem.level_for_xp(1000000, levels), 3, "a 3-level table tops out at level 3")
	assert_eq(ChassisLevelSystem.level_for_xp(0, levels), 1, "0 XP is level 1")


func test_r_014_03_levels_of_balance_table() -> void:
	var levels: ChassisLevelData = _balance_levels()
	if levels == null:
		return
	var expected_levels: Dictionary = {0: 1, 49: 1, 50: 2, 499: 4, 500: 5, 999: 6, 1000: 7, 2000: 10}
	for xp: int in expected_levels:
		var expected: int = expected_levels[xp]
		assert_eq(ChassisLevelSystem.level_for_xp(xp, levels), expected, "level at %d XP" % xp)
	var expected_slots: Dictionary = {499: 5, 500: 6, 1000: 8, 2000: 8}
	for xp: int in expected_slots:
		var expected_count: int = expected_slots[xp]
		var level: int = ChassisLevelSystem.level_for_xp(xp, levels)
		assert_eq(levels.get_inventory_slots(level), expected_count, "slots at %d XP" % xp)


func test_r_014_03_threshold_is_accumulated_xp() -> void:
	var levels: ChassisLevelData = _new_levels([0, 10, 30], [5, 6, 7])
	assert_eq(ChassisLevelSystem.level_for_xp(9, levels), 1, "below the second threshold")
	assert_eq(ChassisLevelSystem.level_for_xp(10, levels), 2, "exactly the second threshold")
	assert_eq(ChassisLevelSystem.level_for_xp(29, levels), 2, "thresholds are totals, not per-level increments")
	assert_eq(ChassisLevelSystem.level_for_xp(30, levels), 3, "exactly the third threshold")


func test_r_014_04_xp_above_last_threshold_is_last_level() -> void:
	var levels: ChassisLevelData = _balance_levels()
	if levels == null:
		return
	assert_eq(ChassisLevelSystem.level_for_xp(999999, levels), levels.get_level_count(), "far above the last threshold")
	var last_xp: int = levels.get_xp_required(levels.get_level_count())
	assert_eq(ChassisLevelSystem.level_for_xp(last_xp + 1, levels), levels.get_level_count(), "just above the last threshold")


func test_r_014_05_negative_xp_reports_error() -> void:
	var levels: ChassisLevelData = _new_levels([0, 10], [5, 6])
	assert_eq(ChassisLevelSystem.level_for_xp(-1, levels), ChassisLevelData.FIRST_LEVEL, "negative XP falls back to level 1")
	assert_push_error("ChassisLevelSystem")


func test_r_014_05_invalid_table_reports_error() -> void:
	assert_eq(ChassisLevelSystem.level_for_xp(100, null), ChassisLevelData.FIRST_LEVEL, "null table")
	assert_push_error("ChassisLevelSystem")
	assert_eq(ChassisLevelSystem.level_for_xp(100, _new_levels([], [])), ChassisLevelData.FIRST_LEVEL, "empty table")
	assert_push_error("ChassisLevelSystem")
	assert_eq(ChassisLevelSystem.level_for_xp(100, _new_levels([10, 20], [5, 6])), ChassisLevelData.FIRST_LEVEL, "first threshold is not 0")
	assert_push_error("ChassisLevelSystem")


func test_r_014_20_xp_to_next_level() -> void:
	var levels: ChassisLevelData = _balance_levels()
	if levels == null:
		return
	assert_eq(ChassisLevelSystem.xp_to_next_level(0, levels), 50, "from 0 XP to level 2")
	assert_eq(ChassisLevelSystem.xp_to_next_level(49, levels), 1, "one XP short")
	assert_eq(ChassisLevelSystem.xp_to_next_level(50, levels), 100, "just reached level 2, 150 total for level 3")
	assert_eq(ChassisLevelSystem.xp_to_next_level(2000, levels), 0, "nothing missing at the last level")
	assert_eq(ChassisLevelSystem.xp_to_next_level(999999, levels), 0, "above the last threshold")


func test_r_014_20_xp_to_next_level_invalid_input_reports_error() -> void:
	var levels: ChassisLevelData = _new_levels([0, 10], [5, 6])
	assert_eq(ChassisLevelSystem.xp_to_next_level(-1, levels), 0, "negative XP")
	assert_push_error("ChassisLevelSystem")
	assert_eq(ChassisLevelSystem.xp_to_next_level(5, null), 0, "null table")
	assert_push_error("ChassisLevelSystem")
	assert_eq(ChassisLevelSystem.xp_to_next_level(5, _new_levels([10, 20], [5, 6])), 0, "invalid table")
	assert_push_error("ChassisLevelSystem")
