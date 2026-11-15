extends GutTest
## InventoryRules (spec 005): pure stacking rules over an Array[ItemStack] where
## null is an empty slot. Covers R-005-01, R-005-03, R-005-04, R-005-05,
## R-005-06, R-005-07 and ItemStack.copy(). No scene tree and no autoloads:
## items are made by hand in each test.

const RULES_PATH := "res://scripts/systems/inventory_rules.gd"
const FORBIDDEN_IN_RULES: PackedStringArray = ["DataRegistry", "GameManager", "get_node", "get_tree"]


func _item(id: StringName, stack_max: int) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = id
	item.stack_max = stack_max
	return item


## Slots from quantities: 0 means an empty (null) slot.
func _slots(item: ItemData, quantities: Array[int]) -> Array[ItemStack]:
	var slots: Array[ItemStack] = []
	for quantity: int in quantities:
		if quantity == 0:
			slots.append(null)
		else:
			slots.append(ItemStack.new(item, quantity))
	return slots


func _quantities(slots: Array[ItemStack]) -> Array[int]:
	var result: Array[int] = []
	for stack: ItemStack in slots:
		result.append(0 if stack == null else stack.quantity)
	return result


func test_r_005_01_rules_are_pure() -> void:
	var rules: InventoryRules = InventoryRules.new()
	assert_is(rules, RefCounted, "InventoryRules is a RefCounted, not a Node")
	# Through Object: on an InventoryRules variable the compiler rejects "is Node".
	var as_object: Object = rules
	assert_false(as_object is Node, "InventoryRules is not a Node")
	var script: GDScript = load(RULES_PATH) as GDScript
	assert_not_null(script, "the script loads")
	if script == null:
		return
	var source: String = script.source_code
	for word: String in FORBIDDEN_IN_RULES:
		assert_false(source.contains(word), "the rules never mention '%s'" % word)


func test_r_005_03_never_above_stack_max() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [0, 0, 0])
	var left: int = InventoryRules.add(slots, item, 25)
	assert_eq(left, 0, "25 fit in three slots of 10")
	for stack: ItemStack in slots:
		if stack != null:
			assert_lte(stack.quantity, item.stack_max, "no slot above stack_max")
	assert_eq(_quantities(slots), [10, 10, 5] as Array[int])


func test_r_005_03_one_item_kind_per_slot() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var slots: Array[ItemStack] = _slots(scrap, [4, 0, 0])
	assert_eq(InventoryRules.add(slots, iron, 3), 0, "iron goes to an empty slot")
	assert_eq(slots[0].item.id, &"scrap", "slot 0 is still scrap only")
	assert_eq(slots[0].quantity, 4, "iron did not top up the scrap stack")
	assert_eq(slots[1].item.id, &"iron", "iron took the first empty slot")
	assert_eq(slots[1].quantity, 3)
	assert_null(slots[2], "the last slot stays empty")


func test_r_005_04_fills_partial_stacks_first() -> void:
	var item: ItemData = _item(&"scrap", 10)
	# An empty slot comes before the partial one: partial stacks win anyway.
	var slots: Array[ItemStack] = _slots(item, [0, 7, 0])
	assert_eq(InventoryRules.add(slots, item, 5), 0)
	assert_eq(_quantities(slots), [2, 10, 0] as Array[int], "3 top up slot 1, 2 open slot 0")


func test_r_005_04_then_empty_slots_in_order() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [0, 0, 0])
	assert_eq(InventoryRules.add(slots, item, 12), 0)
	assert_eq(_quantities(slots), [10, 2, 0] as Array[int], "slot order: 0 then 1")


func test_r_005_04_several_stacks_of_one_item() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [6, 0, 3, 0])
	assert_eq(InventoryRules.add(slots, item, 9), 0)
	# Partial stacks in slot order: slot 0 gets 4, slot 2 gets 5; nothing left for empties.
	assert_eq(_quantities(slots), [10, 0, 8, 0] as Array[int])


func test_r_005_05_add_returns_leftover() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [9, 10])
	var left: int = InventoryRules.add(slots, item, 5)
	assert_eq(left, 4, "only 1 fits")
	assert_eq(_quantities(slots), [10, 10] as Array[int], "what fits was added")


func test_r_005_05_add_returns_leftover_in_empty_inventory_without_slots() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = []
	assert_eq(InventoryRules.add(slots, item, 3), 3, "no slots: everything is left over")


func test_r_005_05_space_for() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 5)
	var slots: Array[ItemStack] = _slots(scrap, [7, 0, 10, 0])
	assert_eq(InventoryRules.space_for(slots, scrap), 3 + 10 + 10, "partial room plus empty slots x stack_max")
	assert_eq(InventoryRules.space_for(slots, iron), 5 + 5, "iron only has the empty slots")
	var full: Array[ItemStack] = _slots(scrap, [10, 10])
	assert_eq(InventoryRules.space_for(full, scrap), 0, "full inventory has no room")


func test_r_005_05_space_for_does_not_change_slots() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [7, 0])
	InventoryRules.space_for(slots, item)
	assert_eq(_quantities(slots), [7, 0] as Array[int])


func test_r_005_05_add_non_positive_quantity_rejected() -> void:
	var item: ItemData = _item(&"scrap", 10)
	for quantity: int in [0, -3]:
		var slots: Array[ItemStack] = _slots(item, [2, 0])
		var left: int = InventoryRules.add(slots, item, quantity)
		assert_push_error("scrap")
		assert_eq(left, quantity, "returns the quantity it was given")
		assert_eq(_quantities(slots), [2, 0] as Array[int], "no change")


func test_r_005_05_add_invalid_stack_max_rejected() -> void:
	var item: ItemData = _item(&"broken", 0)
	var slots: Array[ItemStack] = [null, null]
	var left: int = InventoryRules.add(slots, item, 4)
	assert_push_error("broken")
	assert_eq(left, 4, "returns the quantity it was given")
	assert_eq(_quantities(slots), [0, 0] as Array[int], "no change")


func test_r_005_06_count_sums_all_slots() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var slots: Array[ItemStack] = [ItemStack.new(scrap, 10), null, ItemStack.new(iron, 4), ItemStack.new(scrap, 3)]
	assert_eq(InventoryRules.count(slots, &"scrap"), 13)
	assert_eq(InventoryRules.count(slots, &"iron"), 4)
	assert_eq(InventoryRules.count(slots, &"cables"), 0, "an item that is not there counts 0")
	var empty: Array[ItemStack] = []
	assert_eq(InventoryRules.count(empty, &"scrap"), 0)


func test_r_005_07_remove_from_last_slot() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [10, 4, 6])
	InventoryRules.remove(slots, &"scrap", 8)
	assert_eq(_quantities(slots), [10, 2, 0] as Array[int], "6 from slot 2, then 2 from slot 1")
	assert_eq(InventoryRules.count(slots, &"scrap"), 12, "exactly 8 left the inventory")


func test_r_005_07_emptied_slots_become_null() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [5, 5])
	InventoryRules.remove(slots, &"scrap", 10)
	assert_eq(slots.size(), 2, "the slot count does not change")
	assert_null(slots[0], "slot 0 is null")
	assert_null(slots[1], "slot 1 is null")


func test_r_005_07_remove_skips_other_items() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var slots: Array[ItemStack] = [ItemStack.new(scrap, 5), ItemStack.new(iron, 9), ItemStack.new(scrap, 2)]
	InventoryRules.remove(slots, &"scrap", 6)
	assert_eq(_quantities(slots), [1, 9, 0] as Array[int])
	assert_null(slots[2])


func test_r_005_07_remove_above_count_changes_nothing() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [3, 4])
	InventoryRules.remove(slots, &"scrap", 8)
	assert_push_error("scrap")
	assert_eq(_quantities(slots), [3, 4] as Array[int], "no change")


func test_item_stack_copy_is_independent() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var original: ItemStack = ItemStack.new(item, 7)
	var copy: ItemStack = original.copy()
	assert_not_same(copy, original, "a new object")
	assert_same(copy.item, item, "same item")
	assert_eq(copy.quantity, 7, "same quantity")
	copy.quantity = 1
	assert_eq(original.quantity, 7, "changing the copy leaves the original alone")
	original.quantity = 9
	assert_eq(copy.quantity, 1, "and the other way round")
