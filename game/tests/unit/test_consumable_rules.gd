extends GutTest
## ConsumableRules (spec 012): pure rules for using a consumable. Covers R-012-23
## (which slot is used), R-012-24 (refusals: battery full, no portable battery,
## index out of range) and D4 (first consumable slot, NO_SLOT). No scene tree
## and no autoloads: items are made by hand in each test.

const RULES_PATH := "res://scripts/systems/consumable_rules.gd"
const FORBIDDEN_IN_RULES: PackedStringArray = ["DataRegistry", "GameManager", "get_node", "get_tree"]
const MAXIMUM := 100.0
const POINTS := 20.0


func _consumable() -> ConsumableData:
	var item: ConsumableData = ConsumableData.new()
	item.id = &"test_battery"
	item.stack_max = 5
	item.battery_points = POINTS
	return item


func _material() -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = &"test_scrap"
	item.stack_max = 10
	return item


func test_r_012_24_rules_are_pure() -> void:
	var rules: ConsumableRules = ConsumableRules.new()
	assert_is(rules, RefCounted, "ConsumableRules is a RefCounted, not a Node")
	var as_object: Object = rules
	assert_false(as_object is Node, "ConsumableRules is not a Node")
	var script: GDScript = load(RULES_PATH) as GDScript
	assert_not_null(script, "the script loads")
	if script == null:
		return
	var source: String = script.source_code
	for word: String in FORBIDDEN_IN_RULES:
		assert_false(source.contains(word), "the rules never mention '%s'" % word)


func test_r_012_23_check_use_ok() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_material(), 3), ItemStack.new(_consumable(), 2)]
	var result: ActionResult = ConsumableRules.check_use(slots, 1, MAXIMUM - 1.0, MAXIMUM)
	assert_true(result.ok, "a consumable with room in the battery can be used")
	assert_eq(result.error_key, &"", "no error key")


func test_r_012_23_check_use_ok_when_empty_battery() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_consumable(), 1)]
	assert_true(ConsumableRules.check_use(slots, 0, 0.0, MAXIMUM).ok, "an empty battery can be charged")


func test_r_012_24_check_use_battery_full() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_consumable(), 2)]
	var result: ActionResult = ConsumableRules.check_use(slots, 0, MAXIMUM, MAXIMUM)
	assert_false(result.ok, "a full battery refuses")
	assert_eq(result.error_key, ConsumableRules.ERR_BATTERY_FULL)
	var above: ActionResult = ConsumableRules.check_use(slots, 0, MAXIMUM + 5.0, MAXIMUM)
	assert_eq(above.error_key, ConsumableRules.ERR_BATTERY_FULL, "above the maximum counts as full")


func test_r_012_24_check_use_material_slot() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_material(), 3)]
	var result: ActionResult = ConsumableRules.check_use(slots, 0, 10.0, MAXIMUM)
	assert_false(result.ok, "a material is not a consumable")
	assert_eq(result.error_key, ConsumableRules.ERR_NO_PORTABLE_BATTERY)


func test_r_012_24_check_use_empty_slot() -> void:
	var slots: Array[ItemStack] = [null, ItemStack.new(_consumable(), 1)]
	var result: ActionResult = ConsumableRules.check_use(slots, 0, 10.0, MAXIMUM)
	assert_eq(result.error_key, ConsumableRules.ERR_NO_PORTABLE_BATTERY, "an empty slot holds no battery")


func test_r_012_24_check_use_no_slot() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_consumable(), 1)]
	var result: ActionResult = ConsumableRules.check_use(slots, ConsumableRules.NO_SLOT, 10.0, MAXIMUM)
	assert_false(result.ok, "NO_SLOT is not a consumable slot")
	assert_eq(result.error_key, ConsumableRules.ERR_NO_PORTABLE_BATTERY)


func test_r_012_24_no_battery_wins_over_full() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_material(), 1)]
	var result: ActionResult = ConsumableRules.check_use(slots, 0, MAXIMUM, MAXIMUM)
	assert_eq(result.error_key, ConsumableRules.ERR_NO_PORTABLE_BATTERY, "no battery is checked first")


func test_r_012_24_check_use_index_out_of_range() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_consumable(), 1)]
	var result: ActionResult = ConsumableRules.check_use(slots, 1, 10.0, MAXIMUM)
	assert_push_error("ConsumableRules")
	assert_false(result.ok, "an index past the end is refused")
	assert_eq(result.error_key, ActionResult.ERR_INVALID_REQUEST)
	var negative: ActionResult = ConsumableRules.check_use(slots, -2, 10.0, MAXIMUM)
	assert_push_error("ConsumableRules")
	assert_eq(negative.error_key, ActionResult.ERR_INVALID_REQUEST, "so is a negative index other than NO_SLOT")


func test_r_012_24_check_use_changes_nothing() -> void:
	var slots: Array[ItemStack] = [ItemStack.new(_consumable(), 2)]
	ConsumableRules.check_use(slots, 0, MAXIMUM, MAXIMUM)
	assert_eq(slots[0].quantity, 2, "the check never touches the slots")


func test_r_012_25_first_consumable_slot_in_order() -> void:
	var slots: Array[ItemStack] = [
		null, ItemStack.new(_material(), 3), ItemStack.new(_consumable(), 1), ItemStack.new(_consumable(), 4)
	]
	assert_eq(ConsumableRules.first_consumable_slot(slots), 2, "the first one in slot order")


func test_r_012_25_first_consumable_slot_none() -> void:
	var slots: Array[ItemStack] = [null, ItemStack.new(_material(), 3)]
	assert_eq(ConsumableRules.first_consumable_slot(slots), ConsumableRules.NO_SLOT, "no consumable")
	var empty: Array[ItemStack] = []
	assert_eq(ConsumableRules.first_consumable_slot(empty), ConsumableRules.NO_SLOT, "no slots")
