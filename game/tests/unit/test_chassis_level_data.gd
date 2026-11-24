extends GutTest
## ChassisLevelData (R-005-02): the chassis table of BALANCE §6.1 lives in one
## .tres, the only source of the inventory slot count. Spec 014: 10 levels
## (R-014-01), first threshold 0 and slots that never decrease (R-014-02).
## The expected values mirror BALANCE.md §6.1; update both together.

const CHASSIS_LEVELS_PATH := "res://resources/progression/chassis_levels.tres"
const EXPECTED_XP: Array[int] = [0, 50, 150, 300, 500, 750, 1000, 1300, 1650, 2000]
const EXPECTED_SLOTS: Array[int] = [5, 5, 5, 5, 6, 7, 8, 8, 8, 8]


func _new_levels(xp_required: Array[int], inventory_slots: Array[int]) -> ChassisLevelData:
	var levels: ChassisLevelData = ChassisLevelData.new()
	levels.xp_required = xp_required
	levels.inventory_slots = inventory_slots
	return levels


func test_r_005_02_levels_match_balance() -> void:
	var levels: ChassisLevelData = load(CHASSIS_LEVELS_PATH) as ChassisLevelData
	assert_not_null(levels, "chassis_levels.tres exists and is a ChassisLevelData")
	if levels == null:
		return
	assert_eq(levels.xp_required, EXPECTED_XP, "total XP per level (BALANCE §6.1)")
	assert_eq(levels.inventory_slots, EXPECTED_SLOTS, "inventory slots per level (BALANCE §6.1)")
	assert_eq(levels.get_level_count(), EXPECTED_SLOTS.size(), "one entry per level")
	assert_eq(levels.validate().size(), 0, "the table is valid: %s" % levels.validate())
	for index: int in EXPECTED_SLOTS.size():
		var level: int = ChassisLevelData.FIRST_LEVEL + index
		assert_eq(levels.get_inventory_slots(level), EXPECTED_SLOTS[index], "slots at level %d" % level)
		assert_eq(levels.get_xp_required(level), EXPECTED_XP[index], "XP to reach level %d" % level)


func test_r_005_02_validate_rejects_bad_tables() -> void:
	assert_eq(_new_levels([0, 10], [5, 7]).validate().size(), 0, "a valid table has no problems")
	assert_gt(_new_levels([], []).validate().size(), 0, "no levels")
	assert_gt(_new_levels([0, 10], [5]).validate().size(), 0, "arrays of different size")
	assert_gt(_new_levels([0, 0], [5, 7]).validate().size(), 0, "XP that does not increase")
	assert_gt(_new_levels([0, 10], [7, 5]).validate().size(), 0, "slots that decrease")


func test_r_005_02_level_out_of_range_reports_error() -> void:
	var levels: ChassisLevelData = _new_levels([0, 10], [5, 7])
	assert_eq(levels.get_inventory_slots(0), 0, "below the first level")
	assert_push_error("level 0")
	assert_eq(levels.get_inventory_slots(3), 0, "above the last level")
	assert_push_error("level 3")
	assert_eq(levels.get_xp_required(0), 0, "XP below the first level")
	assert_push_error("level 0")
	assert_eq(levels.get_xp_required(3), 0, "XP above the last level")
	assert_push_error("level 3")


func test_r_014_02_first_threshold_must_be_zero() -> void:
	var problems: PackedStringArray = _new_levels([10, 20], [5, 6]).validate()
	assert_gt(problems.size(), 0, "a first threshold above 0 leaves XP without a level")
	assert_gt(_new_levels([-5, 20], [5, 6]).validate().size(), 0, "a negative first threshold")
	assert_eq(_new_levels([0], [5]).validate().size(), 0, "one level at 0 XP is valid")


func test_r_014_02_equal_slots_are_valid() -> void:
	var problems: PackedStringArray = _new_levels([0, 10, 20], [5, 5, 6]).validate()
	assert_eq(problems.size(), 0, "slots may repeat between levels: %s" % problems)
