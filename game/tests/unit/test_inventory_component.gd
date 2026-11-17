extends GutTest
## InventoryComponent (spec 005): add, add_stacks, remove, remove_from_slots,
## take_from, has, count, get_slots, set_slot_count, find_in. Covers R-005-05,
## R-005-06, R-005-08, R-005-09, R-005-10, R-005-11, R-005-12, R-005-13,
## R-005-14 and R-005-15. Each test builds its catalog by hand and assigns it
## to the component before add_child_autofree(), so DataRegistry is never used.

const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const ERROR_KEYS: Array[StringName] = [
	&"ERR_INVALID_REQUEST",
	&"ERR_NOT_ENOUGH_ITEMS",
	&"MSG_INVENTORY_FULL",
]
const AUTOLOAD_PREFIX := "autoload/"

var _catalog: DataCatalog


func before_each() -> void:
	_catalog = DataCatalog.new()
	_catalog.items.append(_item(&"scrap", 10))
	_catalog.items.append(_item(&"iron", 5))
	_catalog.items.append(_item(&"cables", 10))


func _item(id: StringName, stack_max: int) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = id
	item.stack_max = stack_max
	return item


func _new_inventory(slot_count: int) -> InventoryComponent:
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.catalog = _catalog
	add_child_autofree(inventory)
	var result: ActionResult = inventory.set_slot_count(slot_count)
	assert_true(result.ok, "set_slot_count(%d) in the test setup" % slot_count)
	return inventory


func _stack(id: StringName, quantity: int) -> ItemStack:
	return ItemStack.new(_catalog.get_item(id), quantity)


func _quantities(inventory: InventoryComponent) -> Array[int]:
	var result: Array[int] = []
	for stack: ItemStack in inventory.get_slots():
		result.append(0 if stack == null else stack.quantity)
	return result


func _total(stacks: Array[ItemStack]) -> int:
	var total: int = 0
	for stack: ItemStack in stacks:
		if stack != null:
			total += stack.quantity
	return total


func _fill(inventory: InventoryComponent, id: StringName, quantity: int) -> void:
	var result: InventoryAddResult = inventory.add(id, quantity)
	assert_true(result.ok, "test setup: %d x %s fits" % [quantity, id])


# --- R-005-05 add reports leftovers -----------------------------------------


func test_r_005_05_partial_add_reports_leftovers() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	watch_signals(inventory)
	var result: InventoryAddResult = inventory.add(&"scrap", 25)
	assert_false(result.ok, "not everything fits")
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(_total(result.leftovers), 5, "5 did not fit")
	assert_eq(_quantities(inventory), [10, 10] as Array[int], "what fits was added")
	assert_signal_emit_count(inventory, "inventory_changed", 1)
	assert_signal_emit_count(inventory, "overflowed", 1)
	var params: Array = get_signal_parameters(inventory, "overflowed", 0)
	var leftovers: Array[ItemStack] = params[0] as Array[ItemStack]
	assert_eq(_total(leftovers), 5, "overflowed carries the leftover")


func test_r_005_05_add_that_fits_is_ok() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	watch_signals(inventory)
	var result: InventoryAddResult = inventory.add(&"scrap", 12)
	assert_true(result.ok)
	assert_eq(result.error_key, &"", "no error key when ok")
	assert_eq(result.leftovers.size(), 0, "no leftovers when ok")
	assert_eq(_quantities(inventory), [10, 2] as Array[int])
	assert_signal_not_emitted(inventory, "overflowed")


func test_r_005_05_add_without_any_room() -> void:
	var inventory: InventoryComponent = _new_inventory(1)
	_fill(inventory, &"scrap", 10)
	watch_signals(inventory)
	var result: InventoryAddResult = inventory.add(&"scrap", 3)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(_total(result.leftovers), 3, "everything is left over")
	assert_eq(_quantities(inventory), [10] as Array[int], "no change")
	assert_signal_emit_count(inventory, "overflowed", 1)


func test_r_005_05_add_stacks_leftover_per_stack() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	var offered: Array[ItemStack] = [_stack(&"scrap", 8), _stack(&"iron", 4), _stack(&"iron", 4)]
	# 2 slots: scrap takes slot 0, the first iron stack takes slot 1 (4 of 5),
	# the second tops it up with 1 and leaves 3.
	var result: InventoryAddResult = inventory.add_stacks(offered)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(_total(result.leftovers), 3, "only 3 iron did not fit")
	assert_eq(_quantities(inventory), [8, 5] as Array[int])


# --- R-005-06 has / count ----------------------------------------------------


func test_r_005_06_has() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 15)
	assert_eq(inventory.count(&"scrap"), 15, "count sums the slots")
	assert_true(inventory.has(&"scrap", 15), "has exactly what it holds")
	assert_true(inventory.has(&"scrap", 1))
	assert_false(inventory.has(&"scrap", 16), "has not more than it holds")
	assert_false(inventory.has(&"iron", 1), "an item it does not hold")
	assert_eq(inventory.count(&"iron"), 0)


func test_r_005_06_count_unknown_id_reports_error() -> void:
	var inventory: InventoryComponent = _new_inventory(1)
	assert_eq(inventory.count(&"ghost"), 0)
	assert_push_error("ghost")


# --- R-005-08 remove ---------------------------------------------------------


func test_r_005_08_remove_more_than_held_changes_nothing() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 12)
	watch_signals(inventory)
	var result: ActionResult = inventory.remove(&"scrap", 13)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_NOT_ENOUGH_ITEMS)
	assert_eq(_quantities(inventory), [10, 2] as Array[int], "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_005_08_remove_exact_amount() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 12)
	var result: ActionResult = inventory.remove(&"scrap", 3)
	assert_true(result.ok)
	assert_eq(result.error_key, &"")
	assert_eq(_quantities(inventory), [9, 0] as Array[int], "taken from the last slot first")
	assert_true(inventory.remove(&"scrap", 9).ok, "everything held can be removed")
	assert_true(inventory.is_empty())


# --- R-005-09 invalid requests ------------------------------------------------


func test_r_005_09_non_positive_quantity_rejected() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 4)
	watch_signals(inventory)
	for quantity: int in [0, -2]:
		var added: InventoryAddResult = inventory.add(&"scrap", quantity)
		assert_push_error("scrap")
		assert_false(added.ok, "add %d rejected" % quantity)
		assert_eq(added.error_key, InventoryComponent.ERR_INVALID_REQUEST)
		var removed: ActionResult = inventory.remove(&"scrap", quantity)
		assert_push_error("scrap")
		assert_false(removed.ok, "remove %d rejected" % quantity)
		assert_eq(removed.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(_quantities(inventory), [4, 0] as Array[int], "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_005_09_unknown_item_rejected() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	watch_signals(inventory)
	var added: InventoryAddResult = inventory.add(&"ghost", 1)
	assert_push_error("ghost")
	assert_false(added.ok)
	assert_eq(added.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	var removed: ActionResult = inventory.remove(&"ghost", 1)
	assert_push_error("ghost")
	assert_false(removed.ok)
	assert_eq(removed.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_true(inventory.is_empty(), "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_005_09_one_bad_stack_rejects_all() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	watch_signals(inventory)
	var offered: Array[ItemStack] = [_stack(&"scrap", 3), ItemStack.new(_item(&"ghost", 5), 2)]
	var result: InventoryAddResult = inventory.add_stacks(offered)
	assert_push_error("ghost")
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(result.leftovers.size(), 2, "a rejected request leaves everything offered")
	assert_true(inventory.is_empty(), "the valid stack was not added either")
	assert_signal_not_emitted(inventory, "inventory_changed")
	assert_signal_not_emitted(inventory, "overflowed")


func test_r_005_09_non_positive_stack_rejects_all() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	var offered: Array[ItemStack] = [_stack(&"scrap", 3), _stack(&"iron", 0)]
	var result: InventoryAddResult = inventory.add_stacks(offered)
	assert_push_error("iron")
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_true(inventory.is_empty(), "nothing was added")


# --- R-005-10 no autoload holds inventory -------------------------------------


func test_r_005_10_no_autoload_holds_inventory() -> void:
	var checked: int = 0
	for info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = info["name"]
		if not setting.begins_with(AUTOLOAD_PREFIX):
			continue
		var autoload_name: String = setting.trim_prefix(AUTOLOAD_PREFIX)
		var node: Node = get_tree().root.get_node_or_null(autoload_name)
		assert_not_null(node, "autoload %s is in the tree" % autoload_name)
		if node == null:
			continue
		checked += 1
		assert_null(InventoryComponent.find_in(node), "%s has no InventoryComponent child" % autoload_name)
		for property: Dictionary in node.get_property_list():
			var usage: int = property["usage"]
			if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var property_name: String = property["name"]
			var value: Variant = node.get(property_name)
			assert_false(_holds_inventory(value), "%s.%s holds no inventory" % [autoload_name, property_name])
	assert_gt(checked, 0, "at least one autoload was checked")


func _holds_inventory(value: Variant) -> bool:
	if value is InventoryComponent or value is ItemStack:
		return true
	if value is Array:
		var list: Array = value
		if list.is_typed() and list.get_typed_script() == ItemStack:
			return true
		for element: Variant in list:
			if _holds_inventory(element):
				return true
	if value is Dictionary:
		var map: Dictionary = value
		for element: Variant in map.values():
			if _holds_inventory(element):
				return true
	return false


# --- R-005-11 copies and result types -----------------------------------------


func test_r_005_11_get_slots_returns_copies() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 4)
	var slots: Array[ItemStack] = inventory.get_slots()
	assert_eq(slots.size(), 3, "one entry per slot")
	assert_null(slots[1], "empty slots are null")
	slots[0].quantity = 99
	slots[1] = _stack(&"iron", 2)
	slots.clear()
	assert_eq(_quantities(inventory), [4, 0, 0] as Array[int], "the inventory did not change")
	assert_eq(inventory.count(&"scrap"), 4)


func test_r_005_11_add_stores_copies() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	var offered: ItemStack = _stack(&"scrap", 3)
	var stacks: Array[ItemStack] = [offered]
	assert_true(inventory.add_stacks(stacks).ok)
	offered.quantity = 50
	assert_eq(inventory.count(&"scrap"), 3, "changing the offered stack does not change the inventory")
	var stored: Array[ItemStack] = inventory.get_slots()
	assert_not_same(stored[0], offered, "the offered stack is never kept")


func test_r_005_11_add_stacks_normalizes_item_instance() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	var foreign: ItemData = _item(&"scrap", 99)
	var stacks: Array[ItemStack] = [ItemStack.new(foreign, 3)]
	assert_true(inventory.add_stacks(stacks).ok)
	var stored: Array[ItemStack] = inventory.get_slots()
	assert_same(stored[0].item, _catalog.get_item(&"scrap"), "the catalog item is stored")
	assert_eq(stored[0].item.stack_max, 10, "its stack_max, not the foreign one, rules")


func test_r_005_11_results_are_action_results() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	var source: InventoryComponent = _new_inventory(1)
	_fill(source, &"scrap", 1)
	var no_stacks: Array[ItemStack] = []
	var indices: Array[int] = [0]
	var amounts: Array[int] = [0, 0]
	assert_is(inventory.add(&"scrap", 1), InventoryAddResult)
	assert_is(inventory.add_stacks(no_stacks), InventoryAddResult)
	assert_is(inventory.take_from(source, indices), InventoryAddResult)
	assert_is(inventory.remove(&"scrap", 1), ActionResult)
	assert_is(inventory.remove_from_slots(amounts), ActionResult)
	assert_is(inventory.set_slot_count(4), ActionResult)
	assert_is(InventoryAddResult.new(), ActionResult, "InventoryAddResult is an ActionResult")


# --- R-005-12 signal once per operation -----------------------------------------


func test_r_005_12_changed_once_per_operation() -> void:
	var inventory: InventoryComponent = _new_inventory(5)
	watch_signals(inventory)
	var stacks: Array[ItemStack] = [_stack(&"scrap", 4), _stack(&"iron", 2), _stack(&"cables", 7)]
	inventory.add_stacks(stacks)
	assert_signal_emit_count(inventory, "inventory_changed", 1)
	inventory.add(&"scrap", 15)
	assert_signal_emit_count(inventory, "inventory_changed", 2)
	inventory.remove(&"scrap", 12)
	assert_signal_emit_count(inventory, "inventory_changed", 3)
	var amounts: Array[int] = [0, 0, 1, 0, 0]
	inventory.remove_from_slots(amounts)
	assert_signal_emit_count(inventory, "inventory_changed", 4)


func test_r_005_12_no_signal_without_change() -> void:
	var inventory: InventoryComponent = _new_inventory(1)
	_fill(inventory, &"scrap", 10)
	watch_signals(inventory)
	inventory.remove(&"scrap", 11)
	inventory.add(&"scrap", 2)
	inventory.add(&"iron", 2)
	inventory.add(&"scrap", 0)
	assert_push_error("scrap")
	inventory.remove(&"ghost", 1)
	assert_push_error("ghost")
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- R-005-13 slot count -----------------------------------------------------------


func test_r_005_13_growing_keeps_contents() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 13)
	watch_signals(inventory)
	var result: ActionResult = inventory.set_slot_count(4)
	assert_true(result.ok)
	assert_eq(inventory.get_slot_count(), 4)
	assert_eq(_quantities(inventory), [10, 3, 0, 0] as Array[int], "contents kept, new slots empty")
	assert_signal_emit_count(inventory, "inventory_changed", 1)


func test_r_005_13_same_count_changes_nothing() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	watch_signals(inventory)
	inventory.set_slot_count(3)
	assert_eq(inventory.get_slot_count(), 3)
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_005_13_shrinking_rejected() -> void:
	var inventory: InventoryComponent = _new_inventory(4)
	_fill(inventory, &"scrap", 25)
	watch_signals(inventory)
	var result: ActionResult = inventory.set_slot_count(2)
	assert_push_error("shrink")
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(inventory.get_slot_count(), 4, "slot count unchanged")
	assert_eq(_quantities(inventory), [10, 10, 5, 0] as Array[int], "contents unchanged")
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- R-005-14 translated error keys ----------------------------------------------------


func test_r_005_14_error_keys_translated_es_en() -> void:
	assert_eq(InventoryComponent.ERR_INVALID_REQUEST, &"ERR_INVALID_REQUEST")
	assert_eq(InventoryComponent.ERR_NOT_ENOUGH_ITEMS, &"ERR_NOT_ENOUGH_ITEMS")
	assert_eq(InventoryComponent.MSG_INVENTORY_FULL, &"MSG_INVENTORY_FULL")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for key: StringName in ERROR_KEYS:
			var text: String = translations[0].get_message(key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, key])


# --- R-005-15 moving between inventories --------------------------------------------------


func test_r_005_15_take_moves_exactly_what_fits() -> void:
	var source: InventoryComponent = _new_inventory(3)
	var source_slots: Array[ItemStack] = [_stack(&"scrap", 10), _stack(&"scrap", 8)]
	assert_true(source.add_stacks(source_slots).ok, "source setup: [10, 8]")
	var destination: InventoryComponent = _new_inventory(2)
	_fill(destination, &"scrap", 4)
	var before: int = source.count(&"scrap") + destination.count(&"scrap")
	var indices: Array[int] = [0, 1]
	var result: InventoryAddResult = destination.take_from(source, indices)
	# Room in destination: 6 in slot 0 plus a whole empty slot: 16 of the 18 move.
	assert_false(result.ok, "not everything fit")
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(_total(result.leftovers), 2)
	assert_eq(destination.count(&"scrap"), 20, "destination gained 16")
	assert_eq(source.count(&"scrap"), 2, "source lost exactly what entered")
	assert_eq(source.count(&"scrap") + destination.count(&"scrap"), before, "no item created or lost")
	assert_eq(_quantities(destination), [10, 10] as Array[int])


func test_r_005_15_take_everything_fits() -> void:
	var source: InventoryComponent = _new_inventory(3)
	_fill(source, &"scrap", 4)
	_fill(source, &"iron", 3)
	var destination: InventoryComponent = _new_inventory(3)
	var indices: Array[int] = [0, 1]
	var result: InventoryAddResult = destination.take_from(source, indices)
	assert_true(result.ok)
	assert_eq(destination.count(&"scrap"), 4)
	assert_eq(destination.count(&"iron"), 3)
	assert_true(source.is_empty(), "the source gave everything")


func test_r_005_15_take_only_the_chosen_slots() -> void:
	var source: InventoryComponent = _new_inventory(3)
	_fill(source, &"scrap", 4)
	_fill(source, &"iron", 3)
	var destination: InventoryComponent = _new_inventory(3)
	var indices: Array[int] = [1]
	assert_true(destination.take_from(source, indices).ok)
	assert_eq(destination.count(&"iron"), 3)
	assert_eq(destination.count(&"scrap"), 0)
	assert_eq(source.count(&"scrap"), 4, "slot 0 stays")
	assert_eq(source.count(&"iron"), 0, "slot 1 left")


func test_r_005_15_take_nothing_fits_changes_nothing() -> void:
	var source: InventoryComponent = _new_inventory(2)
	_fill(source, &"scrap", 7)
	var destination: InventoryComponent = _new_inventory(1)
	_fill(destination, &"iron", 5)
	watch_signals(source)
	watch_signals(destination)
	var indices: Array[int] = [0]
	var result: InventoryAddResult = destination.take_from(source, indices)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(_quantities(source), [7, 0] as Array[int], "source unchanged")
	assert_eq(_quantities(destination), [5] as Array[int], "destination unchanged")
	assert_signal_not_emitted(source, "inventory_changed")
	assert_signal_not_emitted(destination, "inventory_changed")
	assert_signal_emit_count(destination, "overflowed", 1)


func test_r_005_15_take_one_signal_per_side() -> void:
	var source: InventoryComponent = _new_inventory(3)
	_fill(source, &"scrap", 4)
	_fill(source, &"iron", 3)
	_fill(source, &"cables", 2)
	var destination: InventoryComponent = _new_inventory(3)
	watch_signals(source)
	watch_signals(destination)
	var indices: Array[int] = [0, 1, 2]
	assert_true(destination.take_from(source, indices).ok)
	assert_signal_emit_count(destination, "inventory_changed", 1)
	assert_signal_emit_count(source, "inventory_changed", 1)


func test_r_005_15_take_invalid_request() -> void:
	var source: InventoryComponent = _new_inventory(2)
	_fill(source, &"scrap", 4)
	var destination: InventoryComponent = _new_inventory(2)
	watch_signals(source)
	watch_signals(destination)
	var same: Array[int] = [0]
	var out_of_range: Array[int] = [2]
	var negative: Array[int] = [-1]
	var repeated: Array[int] = [0, 0]
	var requests: Array[Callable] = [
		source.take_from.bind(source, same),
		destination.take_from.bind(source, out_of_range),
		destination.take_from.bind(source, negative),
		destination.take_from.bind(source, repeated),
		destination.take_from.bind(null, same),
	]
	for request: Callable in requests:
		var result: InventoryAddResult = request.call()
		assert_push_error("take_from")
		assert_false(result.ok)
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(_quantities(source), [4, 0] as Array[int], "source unchanged")
	assert_true(destination.is_empty(), "destination unchanged")
	assert_signal_not_emitted(source, "inventory_changed")
	assert_signal_not_emitted(destination, "inventory_changed")
	assert_signal_not_emitted(destination, "overflowed")


func test_r_005_15_take_unknown_item_rejected() -> void:
	var foreign_catalog: DataCatalog = DataCatalog.new()
	foreign_catalog.items.append(_item(&"relic", 5))
	var source: InventoryComponent = InventoryComponent.new()
	source.catalog = foreign_catalog
	add_child_autofree(source)
	source.set_slot_count(1)
	assert_true(source.add(&"relic", 2).ok, "source setup: an item the destination does not know")
	var destination: InventoryComponent = _new_inventory(2)
	var indices: Array[int] = [0]
	var result: InventoryAddResult = destination.take_from(source, indices)
	assert_push_error("take_from")
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(_quantities(source), [2] as Array[int], "source unchanged")
	assert_true(destination.is_empty(), "destination unchanged")


func test_r_005_15_remove_from_slots() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 14)
	_fill(inventory, &"iron", 5)
	watch_signals(inventory)
	var amounts: Array[int] = [3, 4, 5]
	var result: ActionResult = inventory.remove_from_slots(amounts)
	assert_true(result.ok)
	assert_eq(_quantities(inventory), [7, 0, 0] as Array[int], "amounts[i] left slot i, emptied slots are null")
	assert_null(inventory.get_slots()[2])
	assert_signal_emit_count(inventory, "inventory_changed", 1)


func test_r_005_15_remove_from_slots_invalid() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 5)
	watch_signals(inventory)
	var wrong_size: Array[int] = [1]
	var negative: Array[int] = [-1, 0]
	var too_much: Array[int] = [6, 0]
	var on_empty_slot: Array[int] = [0, 1]
	for amounts: Array[int] in [wrong_size, negative, too_much, on_empty_slot]:
		var result: ActionResult = inventory.remove_from_slots(amounts)
		assert_push_error("remove_from_slots")
		assert_false(result.ok, "%s rejected" % [amounts])
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(_quantities(inventory), [5, 0] as Array[int], "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_005_15_remove_from_slots_all_zero_changes_nothing() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 5)
	watch_signals(inventory)
	var amounts: Array[int] = [0, 0]
	assert_true(inventory.remove_from_slots(amounts).ok)
	assert_eq(_quantities(inventory), [5, 0] as Array[int])
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- is_empty and find_in --------------------------------------------------------------------


func test_is_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	assert_true(inventory.is_empty(), "new inventory is empty")
	_fill(inventory, &"scrap", 1)
	assert_false(inventory.is_empty())
	inventory.remove(&"scrap", 1)
	assert_true(inventory.is_empty(), "empty again after removing everything")


func test_is_empty_with_no_slots() -> void:
	var inventory: InventoryComponent = _new_inventory(0)
	assert_true(inventory.is_empty())


func test_find_in_returns_first_direct_child() -> void:
	var owner_node: Node = Node.new()
	add_child_autofree(owner_node)
	var other: Node = Node.new()
	owner_node.add_child(other)
	var first: InventoryComponent = InventoryComponent.new()
	first.catalog = _catalog
	owner_node.add_child(first)
	var second: InventoryComponent = InventoryComponent.new()
	second.catalog = _catalog
	owner_node.add_child(second)
	assert_same(InventoryComponent.find_in(owner_node), first, "the first direct child")


func test_find_in_null_when_none() -> void:
	var owner_node: Node = Node.new()
	add_child_autofree(owner_node)
	assert_null(InventoryComponent.find_in(owner_node), "no children")
	var nested: Node = Node.new()
	owner_node.add_child(nested)
	var deep: InventoryComponent = InventoryComponent.new()
	deep.catalog = _catalog
	nested.add_child(deep)
	assert_null(InventoryComponent.find_in(owner_node), "only direct children count")


# --- Spec 008: R-008-11 moving part of a stack ---------------------------------


## A source with slots [10, 6, 0] of scrap (stack_max 10) and an empty destination.
func _source_with_two_scrap_stacks() -> InventoryComponent:
	var source: InventoryComponent = _new_inventory(3)
	var stacks: Array[ItemStack] = [_stack(&"scrap", 10), _stack(&"scrap", 6)]
	assert_true(source.add_stacks(stacks).ok, "source setup: [10, 6, 0]")
	return source


func test_r_008_11_take_amount_moves_exactly() -> void:
	var source: InventoryComponent = _source_with_two_scrap_stacks()
	var destination: InventoryComponent = _new_inventory(2)
	var before: int = source.count(&"scrap") + destination.count(&"scrap")
	watch_signals(source)
	watch_signals(destination)
	var result: InventoryAddResult = destination.take_amount_from(source, 0, 4)
	assert_true(result.ok, "everything fits")
	assert_eq(result.leftovers.size(), 0, "no leftovers")
	assert_eq(destination.count(&"scrap"), 4, "the destination gained exactly the quantity")
	assert_eq(_quantities(source), [6, 6, 0] as Array[int], "the slot lost exactly it and kept the rest")
	assert_eq(source.count(&"scrap") + destination.count(&"scrap"), before, "no item created or lost")
	assert_signal_emit_count(destination, "inventory_changed", 1)
	assert_signal_emit_count(source, "inventory_changed", 1)
	assert_signal_not_emitted(destination, "overflowed")


func test_r_008_11_take_amount_whole_stack_empties_slot() -> void:
	var source: InventoryComponent = _source_with_two_scrap_stacks()
	var destination: InventoryComponent = _new_inventory(2)
	var result: InventoryAddResult = destination.take_amount_from(source, 1, 6)
	assert_true(result.ok)
	assert_eq(_quantities(source), [10, 0, 0] as Array[int], "the whole stack left the slot")
	assert_null(source.get_slots()[1], "the emptied slot is null")
	assert_eq(source.get_slot_count(), 3, "the slot count does not change")
	assert_eq(destination.count(&"scrap"), 6)


func test_r_008_11_take_amount_keeps_other_items_apart() -> void:
	var source: InventoryComponent = _new_inventory(2)
	_fill(source, &"scrap", 4)
	_fill(source, &"iron", 3)
	var destination: InventoryComponent = _new_inventory(2)
	assert_true(destination.take_amount_from(source, 1, 2).ok)
	assert_eq(destination.count(&"iron"), 2, "only the chosen item moved")
	assert_eq(destination.count(&"scrap"), 0)
	assert_eq(source.count(&"iron"), 1)
	assert_eq(source.count(&"scrap"), 4, "the other slot is untouched")


func test_r_008_11_take_amount_only_part_fits() -> void:
	var source: InventoryComponent = _new_inventory(2)
	_fill(source, &"scrap", 10)
	var destination: InventoryComponent = _new_inventory(1)
	_fill(destination, &"scrap", 7)
	watch_signals(source)
	watch_signals(destination)
	var result: InventoryAddResult = destination.take_amount_from(source, 0, 5)
	# Room in destination: 3. Two stay in the source.
	assert_false(result.ok, "not everything fit")
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(_total(result.leftovers), 2, "2 did not fit")
	assert_eq(destination.count(&"scrap"), 10, "what fits entered")
	assert_eq(_quantities(source), [7, 0] as Array[int], "the source keeps what did not enter")
	assert_signal_emit_count(destination, "overflowed", 1)
	assert_signal_emit_count(destination, "inventory_changed", 1)
	assert_signal_emit_count(source, "inventory_changed", 1)


func test_r_008_11_take_amount_invalid_requests() -> void:
	var source: InventoryComponent = _source_with_two_scrap_stacks()
	var destination: InventoryComponent = _new_inventory(2)
	watch_signals(source)
	watch_signals(destination)
	var requests: Array[Callable] = [
		destination.take_amount_from.bind(null, 0, 1),
		source.take_amount_from.bind(source, 0, 1),
		destination.take_amount_from.bind(source, -1, 1),
		destination.take_amount_from.bind(source, 3, 1),
		destination.take_amount_from.bind(source, 2, 1),
		destination.take_amount_from.bind(source, 0, 0),
		destination.take_amount_from.bind(source, 0, -2),
		destination.take_amount_from.bind(source, 0, 11),
	]
	for request: Callable in requests:
		var result: InventoryAddResult = request.call()
		assert_push_error("take_amount_from")
		assert_false(result.ok)
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(_quantities(source), [10, 6, 0] as Array[int], "source unchanged")
	assert_true(destination.is_empty(), "destination unchanged")
	assert_signal_not_emitted(source, "inventory_changed")
	assert_signal_not_emitted(destination, "inventory_changed")
	assert_signal_not_emitted(destination, "overflowed")


# --- Spec 008: R-008-18 clear ---------------------------------------------------


func test_r_008_18_clear_empties_and_resizes() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 14)
	watch_signals(inventory)
	var grown: ActionResult = inventory.clear(5)
	assert_true(grown.ok)
	assert_true(inventory.is_empty(), "no stacks")
	assert_eq(inventory.get_slot_count(), 5, "exactly the slots asked")
	assert_eq(_quantities(inventory), [0, 0, 0, 0, 0] as Array[int])
	assert_signal_emit_count(inventory, "inventory_changed", 1)
	_fill(inventory, &"iron", 5)
	var shrunk: ActionResult = inventory.clear(1)
	assert_true(shrunk.ok, "shrinking is allowed for clear")
	assert_true(inventory.is_empty(), "no stacks after shrinking")
	assert_eq(inventory.get_slot_count(), 1, "exactly the slots asked, also when fewer")
	var none: ActionResult = inventory.clear(0)
	assert_true(none.ok)
	assert_eq(inventory.get_slot_count(), 0, "zero slots")
	assert_true(inventory.is_empty())


func test_r_008_18_clear_with_contents_emits_once() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 14)
	_fill(inventory, &"iron", 3)
	watch_signals(inventory)
	inventory.clear(3)
	assert_signal_emit_count(inventory, "inventory_changed", 1)
	assert_true(inventory.is_empty())
	assert_eq(inventory.get_slot_count(), 3)


func test_r_008_18_clear_negative_rejected() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 14)
	watch_signals(inventory)
	var result: ActionResult = inventory.clear(-1)
	assert_push_error("clear")
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(inventory.get_slot_count(), 3, "slot count unchanged")
	assert_eq(_quantities(inventory), [10, 4, 0] as Array[int], "contents unchanged")
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- remove_many (spec 009, R-009-62) -----------------------------------------


func test_r_009_62_remove_many_removes_all() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 14)
	_fill(inventory, &"iron", 3)
	watch_signals(inventory)
	var amounts: Dictionary[StringName, int] = {&"scrap": 12, &"iron": 3}
	var result: ActionResult = inventory.remove_many(amounts)
	assert_true(result.ok)
	assert_eq(inventory.count(&"scrap"), 2)
	assert_eq(inventory.count(&"iron"), 0)
	assert_signal_emit_count(inventory, "inventory_changed", 1)


func test_r_009_62_remove_many_all_or_nothing() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 8)
	_fill(inventory, &"iron", 2)
	var before: Array[int] = _quantities(inventory)
	watch_signals(inventory)
	# scrap is enough, iron is not: nothing may leave.
	var amounts: Dictionary[StringName, int] = {&"scrap": 5, &"iron": 3}
	var result: ActionResult = inventory.remove_many(amounts)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_NOT_ENOUGH_ITEMS)
	assert_eq(_quantities(inventory), before, "no change at all")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_009_62_remove_many_invalid_request() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 8)
	var before: Array[int] = _quantities(inventory)
	watch_signals(inventory)
	var unknown: Dictionary[StringName, int] = {&"scrap": 2, &"ghost": 1}
	var result: ActionResult = inventory.remove_many(unknown)
	assert_push_error_count(1)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST, "unknown id")
	var zero: Dictionary[StringName, int] = {&"scrap": 0}
	result = inventory.remove_many(zero)
	assert_push_error_count(2)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST, "quantity 0")
	var negative: Dictionary[StringName, int] = {&"scrap": 2, &"iron": -1}
	result = inventory.remove_many(negative)
	assert_push_error_count(3)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST, "negative quantity")
	assert_eq(_quantities(inventory), before, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")
