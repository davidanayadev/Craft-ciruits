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


# --- Splitting a stack (spec 008, R-008-40) -----------------------------------


func test_r_008_40_split_whole() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [4, 7, 0])
	var taken: ItemStack = InventoryRules.split(slots, 1, 7)
	assert_not_null(taken, "a stack comes out")
	if taken == null:
		return
	assert_same(taken.item, item, "same item")
	assert_eq(taken.quantity, 7, "the whole quantity")
	assert_null(slots[1], "the slot becomes empty")
	assert_eq(slots.size(), 3, "the slot count does not change")
	assert_eq(_quantities(slots), [4, 0, 0] as Array[int], "other slots untouched")


func test_r_008_40_split_part() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = _slots(item, [4, 9, 0])
	var taken: ItemStack = InventoryRules.split(slots, 1, 3)
	assert_not_null(taken, "a stack comes out")
	if taken == null:
		return
	assert_same(taken.item, item, "same item")
	assert_eq(taken.quantity, 3, "the quantity asked")
	assert_not_null(slots[1], "the slot keeps the rest")
	assert_eq(slots[1].quantity, 6, "9 - 3 stay")
	assert_same(slots[1].item, item, "same item in the slot")
	assert_not_same(slots[1], taken, "the stack that came out is a separate object")
	assert_eq(_quantities(slots), [4, 6, 0] as Array[int], "other slots untouched")
	assert_eq(taken.quantity + slots[1].quantity, 9, "nothing created or lost")


func test_r_008_40_invalid_quantities_change_nothing() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var cases: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, -1),
		Vector2i(0, 6),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(3, 1),
		Vector2i(4, 1),
	]
	for request: Vector2i in cases:
		var slots: Array[ItemStack] = _slots(item, [5, 0, 5])
		var taken: ItemStack = InventoryRules.split(slots, request.x, request.y)
		assert_null(taken, "slot %d, quantity %d returns null" % [request.x, request.y])
		assert_eq(_quantities(slots), [5, 0, 5] as Array[int], "slot %d, quantity %d: no change" % [request.x, request.y])
	assert_push_error_count(0)


func test_r_008_40_can_split_matches_split() -> void:
	var item: ItemData = _item(&"scrap", 10)
	var valid: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 5), Vector2i(2, 3)]
	var invalid: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, -1),
		Vector2i(0, 6),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(3, 1),
	]
	var slots: Array[ItemStack] = _slots(item, [5, 0, 3])
	for request: Vector2i in valid:
		assert_true(InventoryRules.can_split(slots, request.x, request.y), "slot %d, quantity %d" % [request.x, request.y])
	for request: Vector2i in invalid:
		assert_false(InventoryRules.can_split(slots, request.x, request.y), "slot %d, quantity %d" % [request.x, request.y])
	assert_eq(_quantities(slots), [5, 0, 3] as Array[int], "can_split changes nothing")
	assert_push_error_count(0)


# --- Removing several items at once (spec 009, R-009-62) ----------------------


func test_r_009_62_rules_can_remove_many() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var cables: ItemData = _item(&"cables", 10)
	var slots: Array[ItemStack] = [ItemStack.new(scrap, 6), ItemStack.new(cables, 3), ItemStack.new(scrap, 4)]
	var exact: Dictionary[StringName, int] = {&"scrap": 10, &"cables": 3}
	var surplus: Dictionary[StringName, int] = {&"scrap": 2}
	var short_one: Dictionary[StringName, int] = {&"scrap": 11}
	var short_second: Dictionary[StringName, int] = {&"scrap": 1, &"cables": 4}
	var missing_kind: Dictionary[StringName, int] = {&"iron": 1}
	assert_true(InventoryRules.can_remove_many(slots, exact), "exactly what is held, over several stacks")
	assert_true(InventoryRules.can_remove_many(slots, surplus), "less than held")
	assert_false(InventoryRules.can_remove_many(slots, short_one), "one item short")
	assert_false(InventoryRules.can_remove_many(slots, short_second), "the second kind is short")
	assert_false(InventoryRules.can_remove_many(slots, missing_kind), "an item that is not held")
	assert_eq(_quantities(slots), [6, 3, 4] as Array[int], "can_remove_many changes nothing")


func test_r_009_62_rules_remove_many() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var cables: ItemData = _item(&"cables", 10)
	var slots: Array[ItemStack] = [ItemStack.new(scrap, 6), ItemStack.new(cables, 3), ItemStack.new(scrap, 4)]
	var amounts: Dictionary[StringName, int] = {&"scrap": 7, &"cables": 3}
	InventoryRules.remove_many(slots, amounts)
	assert_eq(InventoryRules.count(slots, &"scrap"), 3, "7 of 10 scrap left the inventory")
	assert_eq(InventoryRules.count(slots, &"cables"), 0)
	assert_null(slots[1], "an emptied slot becomes null")
	assert_eq(slots.size(), 3, "the slot count does not change")
	assert_eq(_quantities(slots), [3, 0, 0] as Array[int], "like remove(): last slot first")


# --- Pieces (spec 011) --------------------------------------------------------

func _piece(id: StringName, durability_max: int = 100) -> PieceData:
	var piece: PieceData = PieceData.new()
	piece.id = id
	piece.stack_max = 1
	piece.durability_max = durability_max
	return piece


func _piece_stack(piece: PieceData, durability: int, stack_uid: String) -> ItemStack:
	var stack: ItemStack = ItemStack.new(piece, 1)
	stack.durability = durability
	stack.uid = stack_uid
	return stack


func test_r_011_08_pieces_never_merge() -> void:
	var arms: PieceData = _piece(&"basic_arms")
	var slots: Array[ItemStack] = [_piece_stack(arms, 100, "a"), null, null]
	assert_eq(InventoryRules.add_stack(slots, _piece_stack(arms, 60, "b")), 0, "the second one fits")
	assert_eq(_quantities(slots), [1, 1, 0] as Array[int], "two pieces, two slots")
	assert_eq(slots[0].uid, "a", "the first piece is untouched")
	assert_eq(slots[1].uid, "b", "the second piece has its own slot")
	var full: Array[ItemStack] = [_piece_stack(arms, 100, "a")]
	assert_eq(InventoryRules.add_stack(full, _piece_stack(arms, 100, "b")), 1, "no merge into the piece")
	assert_eq(full[0].uid, "a", "the held piece did not change")


func test_r_011_09_add_stack_keeps_durability_and_uid() -> void:
	var arms: PieceData = _piece(&"basic_arms")
	var slots: Array[ItemStack] = [null, null]
	var offered: ItemStack = _piece_stack(arms, 42, "abc")
	assert_eq(InventoryRules.add_stack(slots, offered), 0, "it fits")
	assert_eq(slots[0].durability, 42, "durability kept")
	assert_eq(slots[0].uid, "abc", "uid kept")
	assert_ne(slots[0], offered, "the slot holds its own stack, not the one offered")
	# A plain material keeps adding as before.
	var scrap: ItemData = _item(&"scrap", 10)
	var materials: Array[ItemStack] = _slots(scrap, [8, 0])
	assert_eq(InventoryRules.add_stack(materials, ItemStack.new(scrap, 5)), 0)
	assert_eq(_quantities(materials), [10, 3] as Array[int], "partial stacks first, then empty slots")
	assert_eq(materials[1].durability, -1, "a material has no durability")
	assert_eq(materials[1].uid, "", "a material has no uid")


func test_r_011_09_split_keeps_durability_and_uid() -> void:
	var arms: PieceData = _piece(&"basic_arms")
	var slots: Array[ItemStack] = [_piece_stack(arms, 37, "xyz")]
	var taken: ItemStack = InventoryRules.split(slots, 0, 1)
	assert_not_null(taken, "the piece leaves")
	if taken == null:
		return
	assert_eq(taken.durability, 37, "durability kept")
	assert_eq(taken.uid, "xyz", "uid kept")
	assert_null(slots[0], "the slot is empty")


func test_r_011_11_is_valid_stack() -> void:
	var arms: PieceData = _piece(&"basic_arms", 100)
	assert_true(InventoryRules.is_valid_stack(_piece_stack(arms, 100, "a")), "intact piece")
	assert_true(InventoryRules.is_valid_stack(_piece_stack(arms, 1, "a")), "piece at 1")
	assert_false(InventoryRules.is_valid_stack(_piece_stack(arms, 0, "a")), "piece at 0")
	assert_false(InventoryRules.is_valid_stack(_piece_stack(arms, 101, "a")), "above its maximum")
	assert_false(InventoryRules.is_valid_stack(_piece_stack(arms, -1, "a")), "no durability")
	assert_false(InventoryRules.is_valid_stack(_piece_stack(arms, 50, "")), "empty uid")
	var two: ItemStack = _piece_stack(arms, 50, "a")
	two.quantity = 2
	assert_false(InventoryRules.is_valid_stack(two), "more than one piece")
	# Materials keep the rules of spec 005: no durability or uid needed.
	var scrap: ItemData = _item(&"scrap", 10)
	assert_true(InventoryRules.is_valid_stack(ItemStack.new(scrap, 3)), "a material stack")
	assert_true(InventoryRules.is_valid_stack(ItemStack.new(scrap, 25)), "a material above stack_max")
	assert_false(InventoryRules.is_valid_stack(null), "no stack")


func test_r_011_19_index_of_uid() -> void:
	var arms: PieceData = _piece(&"basic_arms")
	var scrap: ItemData = _item(&"scrap", 10)
	var slots: Array[ItemStack] = [ItemStack.new(scrap, 3), null, _piece_stack(arms, 50, "p")]
	assert_eq(InventoryRules.index_of_uid(slots, "p"), 2, "the piece's slot")
	assert_eq(InventoryRules.index_of_uid(slots, "q"), -1, "an unknown uid")
	assert_eq(InventoryRules.index_of_uid(slots, ""), -1, "an empty uid never matches a material")


# --- Moving stacks between slots (spec 012) -----------------------------------


func _ids(slots: Array[ItemStack]) -> Array[StringName]:
	var result: Array[StringName] = []
	for stack: ItemStack in slots:
		result.append(&"" if stack == null else stack.item.id)
	return result


func test_r_012_29_to_empty_slot() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var from: Array[ItemStack] = _slots(scrap, [7, 0])
	var to: Array[ItemStack] = _slots(scrap, [0, 0])
	var result: ActionResult = InventoryRules.move_to_slot(from, 0, to, 1, 3)
	assert_true(result.ok, "placed")
	assert_eq(_quantities(from), [4, 0] as Array[int], "the origin keeps the rest")
	assert_eq(_quantities(to), [0, 3] as Array[int], "the chosen slot gets the quantity")
	var whole: ActionResult = InventoryRules.move_to_slot(from, 0, to, 0, 4)
	assert_true(whole.ok, "the whole stack is placed")
	assert_null(from[0], "the emptied origin is null")
	assert_eq(_quantities(to), [4, 3] as Array[int])


func test_r_012_29_same_item_adds_up_to_max() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var from: Array[ItemStack] = _slots(scrap, [6])
	var to: Array[ItemStack] = _slots(scrap, [7])
	var result: ActionResult = InventoryRules.move_to_slot(from, 0, to, 0, 6)
	assert_true(result.ok, "part fits")
	assert_eq(_quantities(to), [10] as Array[int], "up to stack_max")
	assert_eq(_quantities(from), [3] as Array[int], "the rest stays in the origin")


func test_r_012_29_same_item_no_room_refused() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var from: Array[ItemStack] = _slots(scrap, [6])
	var to: Array[ItemStack] = _slots(scrap, [10])
	var result: ActionResult = InventoryRules.move_to_slot(from, 0, to, 0, 6)
	assert_false(result.ok, "a full stack of the same item takes nothing")
	assert_eq(result.error_key, InventoryRules.ERR_SLOT_FULL)
	assert_eq(_quantities(from), [6] as Array[int], "no change in the origin")
	assert_eq(_quantities(to), [10] as Array[int], "no change in the target")
	assert_push_error_count(0)


func test_r_012_29_other_item_whole_stack_swaps() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var from: Array[ItemStack] = _slots(scrap, [6, 0])
	var to: Array[ItemStack] = [ItemStack.new(iron, 2)]
	var result: ActionResult = InventoryRules.move_to_slot(from, 0, to, 0, 6)
	assert_true(result.ok, "swapped")
	assert_eq(_ids(from), [&"iron", &""] as Array[StringName], "the origin gets the other stack")
	assert_eq(_quantities(from), [2, 0] as Array[int])
	assert_eq(_ids(to), [&"scrap"] as Array[StringName], "the target gets the chosen stack")
	assert_eq(_quantities(to), [6] as Array[int])


func test_r_012_29_within_the_same_slots() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var slots: Array[ItemStack] = [ItemStack.new(scrap, 8), null, ItemStack.new(iron, 1)]
	assert_true(InventoryRules.move_to_slot(slots, 0, slots, 1, 5).ok, "split into an empty slot")
	assert_eq(_quantities(slots), [3, 5, 1] as Array[int])
	assert_true(InventoryRules.move_to_slot(slots, 1, slots, 0, 5).ok, "merged back")
	assert_eq(_quantities(slots), [8, 0, 1] as Array[int])
	assert_true(InventoryRules.move_to_slot(slots, 2, slots, 0, 1).ok, "swapped in place")
	assert_eq(_ids(slots), [&"iron", &"", &"scrap"] as Array[StringName])
	assert_eq(_quantities(slots), [1, 0, 8] as Array[int])


func test_r_012_33_partial_swap_refused() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var from: Array[ItemStack] = _slots(scrap, [6])
	var to: Array[ItemStack] = [ItemStack.new(iron, 2)]
	var result: ActionResult = InventoryRules.move_to_slot(from, 0, to, 0, 5)
	assert_false(result.ok, "only whole stacks swap")
	assert_eq(result.error_key, InventoryRules.ERR_PARTIAL_SWAP)
	assert_eq(_quantities(from), [6] as Array[int], "no change in the origin")
	assert_eq(_ids(to), [&"iron"] as Array[StringName], "no change in the target")
	assert_eq(_quantities(to), [2] as Array[int])
	assert_push_error_count(0)


func test_r_012_30_transfer_same_item_then_empty() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var from: Array[ItemStack] = _slots(scrap, [9])
	var to: Array[ItemStack] = [null, ItemStack.new(scrap, 6), ItemStack.new(iron, 1)]
	var result: ActionResult = InventoryRules.transfer(from, 0, to, 9)
	assert_true(result.ok, "everything fits")
	assert_eq(_quantities(to), [5, 10, 1] as Array[int], "the same item first, then the empty slot")
	assert_eq(_ids(to), [&"scrap", &"scrap", &"iron"] as Array[StringName])
	assert_null(from[0], "the origin is emptied")


func test_r_012_30_rest_stays() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var from: Array[ItemStack] = _slots(scrap, [9])
	var to: Array[ItemStack] = _slots(scrap, [8])
	var result: ActionResult = InventoryRules.transfer(from, 0, to, 6)
	assert_true(result.ok, "part fits")
	assert_eq(_quantities(to), [10] as Array[int], "as much as fits")
	assert_eq(_quantities(from), [7] as Array[int], "what did not fit stays with the rest")


func test_r_012_30_no_room_refused() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var iron: ItemData = _item(&"iron", 10)
	var from: Array[ItemStack] = _slots(scrap, [4])
	var to: Array[ItemStack] = [ItemStack.new(scrap, 10), ItemStack.new(iron, 3)]
	var result: ActionResult = InventoryRules.transfer(from, 0, to, 4)
	assert_false(result.ok, "nothing fits")
	assert_eq(result.error_key, InventoryRules.ERR_NO_ROOM)
	assert_eq(_quantities(from), [4] as Array[int], "no change in the origin")
	assert_eq(_quantities(to), [10, 3] as Array[int], "no change in the target")
	assert_push_error_count(0)


func test_r_012_32_invalid_requests_report_error_no_change() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	# [from_index, to_index, quantity]: out of range, empty origin, quantity outside 1..stack.
	var moves: Array[Vector3i] = [
		Vector3i(-1, 0, 1),
		Vector3i(2, 0, 1),
		Vector3i(0, -1, 1),
		Vector3i(0, 2, 1),
		Vector3i(1, 0, 1),
		Vector3i(0, 1, 0),
		Vector3i(0, 1, 6),
	]
	for request: Vector3i in moves:
		var from: Array[ItemStack] = _slots(scrap, [5, 0])
		var to: Array[ItemStack] = _slots(scrap, [0, 0])
		var result: ActionResult = InventoryRules.move_to_slot(from, request.x, to, request.y, request.z)
		assert_eq(result.error_key, ActionResult.ERR_INVALID_REQUEST, "move %s is invalid" % request)
		assert_eq(_quantities(from), [5, 0] as Array[int], "move %s: no change in the origin" % request)
		assert_eq(_quantities(to), [0, 0] as Array[int], "move %s: no change in the target" % request)
	var same: Array[ItemStack] = _slots(scrap, [5, 0])
	assert_eq(
		InventoryRules.move_to_slot(same, 0, same, 0, 5).error_key,
		ActionResult.ERR_INVALID_REQUEST,
		"a slot onto itself is invalid"
	)
	# [from_index, quantity] for transfer.
	var transfers: Array[Vector2i] = [Vector2i(-1, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(0, 6)]
	for request: Vector2i in transfers:
		var from: Array[ItemStack] = _slots(scrap, [5, 0])
		var to: Array[ItemStack] = _slots(scrap, [0, 0])
		var result: ActionResult = InventoryRules.transfer(from, request.x, to, request.y)
		assert_eq(result.error_key, ActionResult.ERR_INVALID_REQUEST, "transfer %s is invalid" % request)
		assert_eq(_quantities(from), [5, 0] as Array[int], "transfer %s: no change" % request)
		assert_eq(_quantities(to), [0, 0] as Array[int], "transfer %s: no change in the target" % request)
	assert_eq(
		InventoryRules.transfer(same, 0, same, 5).error_key,
		ActionResult.ERR_INVALID_REQUEST,
		"a transfer into the same slots is invalid"
	)
	assert_eq(_quantities(same), [5, 0] as Array[int], "no change")
	assert_push_error_count(moves.size() + 1 + transfers.size() + 1)


func test_r_012_34_pieces_keep_uid_and_never_merge() -> void:
	var arms: PieceData = _piece(&"basic_arms")
	assert_false(
		InventoryRules.can_merge(_piece_stack(arms, 100, "a"), _piece_stack(arms, 100, "b")), "two pieces never merge"
	)
	assert_true(InventoryRules.can_merge(ItemStack.new(arms, 1), ItemStack.new(arms, 1)), "same id, no uid")
	assert_false(InventoryRules.can_merge(null, ItemStack.new(arms, 1)), "null never merges")
	var from: Array[ItemStack] = [_piece_stack(arms, 40, "a"), null]
	var to: Array[ItemStack] = [_piece_stack(arms, 90, "b"), null]
	assert_true(InventoryRules.move_to_slot(from, 0, to, 0, 1).ok, "a piece onto a piece swaps")
	assert_eq(from[0].uid, "b", "the other piece came back")
	assert_eq(from[0].durability, 90, "with its durability")
	assert_eq(to[0].uid, "a", "the moved piece keeps its uid")
	assert_eq(to[0].durability, 40, "and its durability")
	assert_true(InventoryRules.transfer(from, 0, to, 1).ok, "a piece transfers to an empty slot")
	assert_null(from[0], "the origin is emptied")
	assert_eq(to[1].uid, "b", "the transferred piece keeps its uid")
	assert_eq(to[1].durability, 90, "and its durability")
	assert_eq(InventoryRules.transfer(to, 0, from, 1).ok, true, "and back to an empty slot")
	assert_eq(from[0].uid, "a", "uid kept back")
	var full: Array[ItemStack] = [_piece_stack(arms, 100, "c")]
	var result: ActionResult = InventoryRules.transfer(from, 0, full, 1)
	assert_eq(result.error_key, InventoryRules.ERR_NO_ROOM, "a piece never stacks on another")


func test_r_013_12_count_used_slots() -> void:
	var scrap: ItemData = _item(&"scrap", 10)
	var empty: Array[ItemStack] = []
	assert_eq(InventoryRules.count_used_slots(empty), 0, "no slots, none used")
	assert_eq(InventoryRules.count_used_slots(_slots(scrap, [0, 0, 0])), 0, "every slot empty")
	assert_eq(InventoryRules.count_used_slots(_slots(scrap, [3, 0, 10, 1])), 3, "slots holding a stack")
