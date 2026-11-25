extends GutTest
## InventoryComponent (spec 005): add, add_stacks, remove, remove_from_slots,
## take_from, has, count, get_slots, set_slot_count, find_in. Covers R-005-05,
## R-005-06, R-005-08, R-005-09, R-005-10, R-005-11, R-005-12, R-005-13,
## R-005-14 and R-005-15. Each test builds its catalog by hand and assigns it
## to the component before add_child_autofree(), so DataRegistry is never used.
## Spec 010: save and load (R-010-08, 09, 10, 11, 23, 24).

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
	inventory.name = "Inventory"
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



# --- Spec 010: save and load (R-010-08..11, R-010-23, R-010-24, D15) -----------


func _saved(id: String, quantity: Variant, extra: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {"item_id": id, "quantity": quantity}
	entry.merge(extra)
	return entry


func _load_slots(inventory: InventoryComponent, slots: Array) -> void:
	inventory.from_save_data({"slots": slots})


func test_r_010_08_save_key() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	assert_eq(InventoryComponent.SAVE_KEY, &"inventory", "const")
	assert_eq(inventory.get_save_key(), &"inventory", "getter")


func test_r_010_08_save_data_has_one_entry_per_slot() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 4)
	var data: Dictionary = inventory.to_save_data()
	var slots: Array = data["slots"] as Array
	assert_eq(slots.size(), 3, "one entry per slot, empty ones included")
	var entry: Dictionary = slots[0]
	assert_eq(entry, {"item_id": "scrap", "quantity": 4, "durability": -1, "uid": ""}, "stack entry")
	assert_true(slots[1] == null, "empty slot is null")
	assert_true(slots[2] == null, "empty slot is null")


func test_r_010_08_save_data_is_json_safe() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"iron", 2)
	var data: Dictionary = inventory.to_save_data()
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	var back: Dictionary = parsed as Dictionary
	var slots: Array = back["slots"] as Array
	assert_eq(slots.size(), 2, "survives JSON")
	var first: Dictionary = slots[0] as Dictionary
	var item_id: String = first["item_id"]
	assert_eq(item_id, "iron", "id is a String")


func test_r_010_09_load_fills_slots_and_emits_once() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	watch_signals(inventory)
	_load_slots(inventory, [_saved("scrap", 3.0), null, _saved("iron", 5)])
	var expected: Array[int] = [3, 0, 5]
	assert_eq(_quantities(inventory), expected, "loaded quantities, float accepted")
	var third: ItemStack = inventory.get_slots()[2]
	assert_eq(third.item.id, &"iron", "item resolved from the catalog")
	assert_signal_emit_count(inventory, "inventory_changed", 1)
	assert_signal_not_emitted(inventory, "overflowed")


func test_r_010_09_load_does_not_resize() -> void:
	var inventory: InventoryComponent = _new_inventory(5)
	_load_slots(inventory, [_saved("scrap", 1)])
	assert_eq(inventory.get_slot_count(), 5, "the chassis owns the slot count")


func test_r_010_09_load_replaces_previous_contents() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"cables", 6)
	_fill(inventory, &"iron", 2)
	_load_slots(inventory, [null, _saved("scrap", 2), null])
	var expected: Array[int] = [0, 2, 0]
	assert_eq(_quantities(inventory), expected, "old contents cleared")


func test_r_010_09_load_emits_once_even_when_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 1)
	watch_signals(inventory)
	_load_slots(inventory, [null, null])
	assert_signal_emit_count(inventory, "inventory_changed", 1)
	assert_true(inventory.is_empty(), "now empty")


func test_r_010_23_load_keeps_durability_and_uid() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_load_slots(inventory, [_saved("scrap", 1, {"durability": 40, "uid": "abc123"}), null])
	var stack: ItemStack = inventory.get_slots()[0]
	assert_eq(stack.durability, 40, "durability")
	assert_eq(stack.uid, "abc123", "uid")


func test_r_010_23_missing_optionals_default() -> void:
	var inventory: InventoryComponent = _new_inventory(1)
	_load_slots(inventory, [_saved("scrap", 2)])
	var stack: ItemStack = inventory.get_slots()[0]
	assert_eq(stack.durability, -1, "durability defaults to -1")
	assert_eq(stack.uid, "", "uid defaults to empty")
	assert_push_error_count(0)


func test_r_010_09_round_trip_inventory() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	var saved: Dictionary = {
		"slots":
		[
			{"item_id": "scrap", "quantity": 7, "durability": 40, "uid": "abcdef0123456789"},
			null,
			{"item_id": "iron", "quantity": 5, "durability": -1, "uid": ""},
		]
	}
	inventory.from_save_data(saved)
	assert_eq(inventory.to_save_data(), saved, "what was loaded is what is saved")


func test_r_010_09_round_trip_through_json_floats() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 9)
	var parsed: Variant = JSON.parse_string(JSON.stringify(inventory.to_save_data()))
	var data: Dictionary = parsed as Dictionary
	var other: InventoryComponent = _new_inventory(2)
	other.from_save_data(data)
	var expected: Array[int] = [9, 0]
	assert_eq(_quantities(other), expected, "JSON numbers are floats and still load")


func test_r_010_10_load_never_overflows() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	watch_signals(inventory)
	_load_slots(inventory, [_saved("scrap", 10), _saved("scrap", 10)])
	var expected: Array[int] = [10, 10]
	assert_eq(_quantities(inventory), expected, "slots are kept as saved, no restacking")
	assert_signal_not_emitted(inventory, "overflowed")


func test_r_010_11_unknown_item_leaves_slot_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_load_slots(inventory, [_saved("scrap", 2), _saved("ghost", 1), _saved("iron", 1)])
	assert_push_error("Inventory")
	var expected: Array[int] = [2, 0, 1]
	assert_eq(_quantities(inventory), expected, "the rest loads")


func test_r_010_11_quantity_zero_leaves_slot_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_load_slots(inventory, [_saved("scrap", 0), _saved("iron", 1)])
	assert_push_error("Inventory")
	var expected: Array[int] = [0, 1]
	assert_eq(_quantities(inventory), expected, "the rest loads")


func test_r_010_11_quantity_above_stack_max_leaves_slot_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	var too_many: int = _catalog.get_item(&"iron").stack_max + 1
	_load_slots(inventory, [_saved("iron", too_many), _saved("scrap", 1)])
	assert_push_error("Inventory")
	var expected: Array[int] = [0, 1]
	assert_eq(_quantities(inventory), expected, "the rest loads")


func test_r_010_11_fractional_quantity_leaves_slot_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_load_slots(inventory, [_saved("scrap", 1.5), _saved("scrap", 1)])
	assert_push_error("Inventory")
	var expected: Array[int] = [0, 1]
	assert_eq(_quantities(inventory), expected, "the rest loads")


func test_r_010_11_non_dictionary_entry_leaves_slot_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_load_slots(inventory, ["scrap", _saved("scrap", 1)])
	assert_push_error("Inventory")
	var expected: Array[int] = [0, 1]
	assert_eq(_quantities(inventory), expected, "the rest loads")


func test_r_010_11_entries_past_the_slot_count_are_dropped() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_load_slots(inventory, [_saved("scrap", 1), _saved("iron", 1), _saved("cables", 1)])
	assert_push_error("Inventory")
	assert_eq(inventory.get_slot_count(), 2, "not resized")
	var expected: Array[int] = [1, 1]
	assert_eq(_quantities(inventory), expected, "the extra entry is dropped")


func test_r_010_11_bad_durability_leaves_slot_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(3)
	_load_slots(
		inventory,
		[
			_saved("scrap", 1, {"durability": 2.5}),
			_saved("scrap", 1, {"durability": "40"}),
			_saved("iron", 1, {"durability": 40.0}),
		]
	)
	assert_push_error_count(2)
	var expected: Array[int] = [0, 0, 1]
	assert_eq(_quantities(inventory), expected, "a whole float is accepted")
	var third: ItemStack = inventory.get_slots()[2]
	assert_eq(third.durability, 40, "as an int")


func test_r_010_11_bad_uid_leaves_slot_empty() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_load_slots(inventory, [_saved("scrap", 1, {"uid": 12}), _saved("iron", 1, {"uid": "x"})])
	assert_push_error("Inventory")
	var expected: Array[int] = [0, 1]
	assert_eq(_quantities(inventory), expected, "the rest loads")


func test_r_010_11_missing_slots_is_rejected() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 3)
	watch_signals(inventory)
	inventory.from_save_data({})
	assert_push_error("Inventory")
	var expected: Array[int] = [3, 0]
	assert_eq(_quantities(inventory), expected, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_010_11_slots_not_an_array_is_rejected() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 3)
	watch_signals(inventory)
	inventory.from_save_data({"slots": "none"})
	assert_push_error("Inventory")
	var expected: Array[int] = [3, 0]
	assert_eq(_quantities(inventory), expected, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- Pieces, crafting and repair (spec 011) --------------------------------------
# R-011-03, 07, 08, 09, 11, 13, 14, 15, 19 and 20. Everything is built by hand.

const PIECE_MAX: int = 100
const PIECE_ID: StringName = &"arm"
const OTHER_PIECE_ID: StringName = &"core"


func _piece_item(id: StringName) -> PieceData:
	var piece: PieceData = PieceData.new()
	piece.id = id
	piece.stack_max = 1
	piece.durability_max = PIECE_MAX
	return piece


## Adds the two hand-made pieces to the test catalog.
func _with_pieces() -> void:
	_catalog.items.append(_piece_item(PIECE_ID))
	_catalog.items.append(_piece_item(OTHER_PIECE_ID))


func _piece_stack(durability: int, uid: String, id: StringName = PIECE_ID) -> ItemStack:
	var stack: ItemStack = ItemStack.new(_catalog.get_item(id), 1)
	stack.durability = durability
	stack.uid = uid
	return stack


func _give_piece(inventory: InventoryComponent, durability: int, uid: String, id: StringName = PIECE_ID) -> void:
	var stacks: Array[ItemStack] = [_piece_stack(durability, uid, id)]
	var result: InventoryAddResult = inventory.add_stacks(stacks)
	assert_true(result.ok, "test setup: piece %s fits" % uid)


func _ingredient(id: StringName, quantity: int) -> RecipeIngredientData:
	var ingredient: RecipeIngredientData = RecipeIngredientData.new()
	ingredient.item = _catalog.get_item(id)
	ingredient.quantity = quantity
	return ingredient


## A recipe for result_id costing the given item id -> quantity.
func _recipe(result_id: StringName, cost: Dictionary[StringName, int]) -> RecipeData:
	var recipe: RecipeData = RecipeData.new()
	recipe.id = &"test_recipe"
	recipe.result_item = _catalog.get_item(result_id)
	for item_id: StringName in cost:
		recipe.ingredients.append(_ingredient(item_id, cost[item_id]))
	return recipe


## Up to 50% left: 2 iron. Up to 100%: 1 scrap.
func _repair_costs() -> RepairCostData:
	var low: RepairTierData = RepairTierData.new()
	low.up_to_percent = 50
	low.ingredients.append(_ingredient(&"iron", 2))
	var high: RepairTierData = RepairTierData.new()
	high.up_to_percent = 100
	high.ingredients.append(_ingredient(&"scrap", 1))
	var costs: RepairCostData = RepairCostData.new()
	costs.tiers.append(low)
	costs.tiers.append(high)
	return costs


func _craft(inventory: InventoryComponent, recipe: RecipeData) -> ActionResult:
	return inventory.craft(recipe)


func _repair(inventory: InventoryComponent, uid: String, costs: RepairCostData) -> ActionResult:
	return inventory.repair(uid, costs)


## The first stack holding the piece uid, or null.
func _find_uid(inventory: InventoryComponent, uid: String) -> ItemStack:
	for stack: ItemStack in inventory.get_slots():
		if stack != null and stack.uid == uid:
			return stack
	return null


func test_r_011_03_craft_rejects_structure_recipe() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 5)
	watch_signals(inventory)
	var structure_recipe: RecipeData = RecipeData.new()
	structure_recipe.id = &"test_structure"
	structure_recipe.result_structure = StructureData.new()
	structure_recipe.ingredients.append(_ingredient(&"scrap", 1))
	var no_result: RecipeData = RecipeData.new()
	no_result.id = &"test_empty"
	var foreign: RecipeData = RecipeData.new()
	foreign.id = &"test_foreign"
	foreign.result_item = _item(&"ghost", 1)
	foreign.ingredients.append(_ingredient(&"scrap", 1))
	var recipes: Array[RecipeData] = [structure_recipe, no_result, foreign, null]
	var errors: int = 0
	for recipe: RecipeData in recipes:
		var result: ActionResult = _craft(inventory, recipe)
		errors += 1
		assert_push_error_count(errors)
		assert_false(result.ok)
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	var expected: Array[int] = [5, 0, 0]
	assert_eq(_quantities(inventory), expected, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_011_07_add_piece_by_id_rejected() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(2)
	watch_signals(inventory)
	var result: InventoryAddResult = inventory.add(PIECE_ID, 1)
	assert_push_error_count(1)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_true(inventory.is_empty(), "no piece without a uid was created")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_011_07_invalid_piece_stack_rejected() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(3)
	watch_signals(inventory)
	var two: ItemStack = _piece_stack(40, "u2")
	two.quantity = 2
	var bad: Array[ItemStack] = [
		_piece_stack(0, "u1"),
		_piece_stack(PIECE_MAX + 1, "u1"),
		_piece_stack(40, ""),
		two,
	]
	var errors: int = 0
	for stack: ItemStack in bad:
		var offered: Array[ItemStack] = [_stack(&"scrap", 3), stack]
		var result: InventoryAddResult = inventory.add_stacks(offered)
		errors += 1
		assert_push_error_count(errors)
		assert_false(result.ok)
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_true(inventory.is_empty(), "the valid scrap was not added either")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_011_08_two_crafted_arms_two_slots() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 4)
	var cost: Dictionary[StringName, int] = {&"scrap": 1}
	var recipe: RecipeData = _recipe(PIECE_ID, cost)
	assert_true(_craft(inventory, recipe).ok)
	assert_true(_craft(inventory, recipe).ok)
	assert_eq(inventory.count(PIECE_ID), 2, "two arms")
	var expected: Array[int] = [2, 1, 1]
	assert_eq(_quantities(inventory), expected, "each arm has its own slot")
	var slots: Array[ItemStack] = inventory.get_slots()
	assert_ne(slots[1].uid, "", "first arm has a uid")
	assert_ne(slots[2].uid, "", "second arm has a uid")
	assert_ne(slots[1].uid, slots[2].uid, "the uids differ")
	assert_eq(slots[1].durability, PIECE_MAX, "new pieces start at their maximum")
	assert_eq(slots[2].durability, PIECE_MAX)


func test_r_011_09_take_from_keeps_piece() -> void:
	_with_pieces()
	var source: InventoryComponent = _new_inventory(2)
	_give_piece(source, 40, "u1")
	var destination: InventoryComponent = _new_inventory(2)
	var indices: Array[int] = [0]
	assert_true(destination.take_from(source, indices).ok)
	var moved: ItemStack = _find_uid(destination, "u1")
	assert_not_null(moved, "the piece arrived with its uid")
	if moved != null:
		assert_eq(moved.durability, 40, "durability kept")
	assert_true(source.is_empty(), "the source gave it")


func test_r_011_09_take_amount_from_keeps_piece() -> void:
	_with_pieces()
	var source: InventoryComponent = _new_inventory(2)
	_give_piece(source, 40, "u1")
	var destination: InventoryComponent = _new_inventory(2)
	assert_true(destination.take_amount_from(source, 0, 1).ok)
	var moved: ItemStack = _find_uid(destination, "u1")
	assert_not_null(moved, "the piece arrived with its uid")
	if moved != null:
		assert_eq(moved.durability, 40, "durability kept")
	assert_true(source.is_empty(), "the source gave it")


func test_r_011_09_add_stacks_keeps_piece() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(2)
	_give_piece(inventory, 40, "u1")
	var stored: ItemStack = _find_uid(inventory, "u1")
	assert_not_null(stored, "stored with its uid")
	if stored != null:
		assert_eq(stored.durability, 40, "durability kept")
		assert_eq(stored.item.id, PIECE_ID)


func test_r_011_09_leftover_keeps_piece() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(1)
	_fill(inventory, &"scrap", 1)
	watch_signals(inventory)
	var offered: Array[ItemStack] = [_piece_stack(40, "u1")]
	var result: InventoryAddResult = inventory.add_stacks(offered)
	assert_false(result.ok, "no room")
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(result.leftovers.size(), 1)
	if result.leftovers.size() == 1:
		assert_eq(result.leftovers[0].uid, "u1", "the leftover keeps its uid")
		assert_eq(result.leftovers[0].durability, 40, "and its durability")
	var params: Array = get_signal_parameters(inventory, "overflowed", 0)
	var emitted: Array[ItemStack] = params[0] as Array[ItemStack]
	assert_eq(emitted.size(), 1)
	if emitted.size() == 1:
		assert_eq(emitted[0].uid, "u1", "overflowed carries the uid")
		assert_eq(emitted[0].durability, 40, "and the durability")


func test_r_011_11_material_over_stack_max_still_split() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(3)
	var offered: Array[ItemStack] = [_stack(&"scrap", 25)]
	assert_true(inventory.add_stacks(offered).ok)
	var expected: Array[int] = [10, 10, 5]
	assert_eq(_quantities(inventory), expected, "spec 005 split kept for materials")


func test_r_011_11_bad_saved_piece_dropped() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(5)
	_load_slots(
		inventory,
		[
			_saved("arm", 1, {"durability": 0, "uid": "a"}),
			_saved("arm", 1, {"durability": PIECE_MAX + 1, "uid": "b"}),
			_saved("arm", 1, {"durability": 40, "uid": ""}),
			_saved("arm", 1, {"durability": 40, "uid": "ok"}),
			_saved("scrap", 2),
		]
	)
	assert_push_error_count(3)
	var expected: Array[int] = [0, 0, 0, 1, 2]
	assert_eq(_quantities(inventory), expected, "only the valid piece and the material load")
	var kept: ItemStack = _find_uid(inventory, "ok")
	assert_not_null(kept)
	if kept != null:
		assert_eq(kept.durability, 40)


func test_r_011_13_craft_pays_and_adds_once() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 5)
	_fill(inventory, &"iron", 1)
	var cost: Dictionary[StringName, int] = {&"scrap": 3, &"iron": 1}
	var recipe: RecipeData = _recipe(PIECE_ID, cost)
	watch_signals(inventory)
	var result: ActionResult = _craft(inventory, recipe)
	assert_true(result.ok)
	assert_eq(result.error_key, &"")
	assert_eq(inventory.count(&"scrap"), 2, "scrap paid")
	assert_eq(inventory.count(&"iron"), 0, "iron paid")
	assert_eq(inventory.count(PIECE_ID), 1, "the piece was added in the same call")
	assert_signal_emit_count(inventory, "inventory_changed", 1)
	var piece: ItemStack = null
	for stack: ItemStack in inventory.get_slots():
		if stack != null and stack.item.id == PIECE_ID:
			piece = stack
	assert_not_null(piece)
	if piece != null:
		assert_eq(piece.durability, PIECE_MAX)
		assert_ne(piece.uid, "")


func test_r_011_14_craft_refused_changes_nothing() -> void:
	_with_pieces()
	var cost: Dictionary[StringName, int] = {&"scrap": 3}
	var recipe: RecipeData = _recipe(PIECE_ID, cost)
	# Not enough materials.
	var poor: InventoryComponent = _new_inventory(2)
	_fill(poor, &"scrap", 2)
	watch_signals(poor)
	var short: ActionResult = _craft(poor, recipe)
	assert_false(short.ok)
	assert_eq(short.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS)
	var expected_poor: Array[int] = [2, 0]
	assert_eq(_quantities(poor), expected_poor, "no change")
	assert_signal_not_emitted(poor, "inventory_changed")
	# Enough materials, but paying leaves no slot free for the result.
	var full: InventoryComponent = _new_inventory(1)
	_fill(full, &"scrap", 5)
	watch_signals(full)
	var crowded: ActionResult = _craft(full, recipe)
	assert_false(crowded.ok)
	assert_eq(crowded.error_key, CraftingSystem.ERR_NO_ROOM_FOR_RESULT)
	var expected_full: Array[int] = [5]
	assert_eq(_quantities(full), expected_full, "no change")
	assert_signal_not_emitted(full, "inventory_changed")


func test_r_011_19_repair_restores_keeps_uid_and_slot() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 4)
	_give_piece(inventory, 40, "u1")
	_fill(inventory, &"iron", 3)
	watch_signals(inventory)
	var result: ActionResult = _repair(inventory, "u1", _repair_costs())
	assert_true(result.ok)
	assert_eq(result.error_key, &"")
	var slots: Array[ItemStack] = inventory.get_slots()
	assert_eq(slots[1].uid, "u1", "same slot, same uid")
	assert_eq(slots[1].item.id, PIECE_ID)
	assert_eq(slots[1].durability, PIECE_MAX, "restored to its maximum")
	assert_eq(inventory.count(&"iron"), 1, "the 40% tier cost 2 iron")
	assert_eq(inventory.count(&"scrap"), 4, "scrap untouched")
	assert_signal_emit_count(inventory, "inventory_changed", 1)


func test_r_011_20_repair_refused_changes_nothing() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(4)
	_fill(inventory, &"iron", 1)
	_give_piece(inventory, PIECE_MAX, "intact")
	_give_piece(inventory, 40, "damaged", OTHER_PIECE_ID)
	var before: Array[int] = _quantities(inventory)
	watch_signals(inventory)
	var intact: ActionResult = _repair(inventory, "intact", _repair_costs())
	assert_false(intact.ok)
	assert_eq(intact.error_key, CraftingSystem.ERR_PIECE_INTACT)
	var poor: ActionResult = _repair(inventory, "damaged", _repair_costs())
	assert_false(poor.ok, "needs 2 iron and has 1")
	assert_eq(poor.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS)
	assert_eq(_quantities(inventory), before, "no change")
	var damaged: ItemStack = _find_uid(inventory, "damaged")
	assert_not_null(damaged)
	if damaged != null:
		assert_eq(damaged.durability, 40, "still damaged")
	assert_eq(inventory.count(&"iron"), 1, "nothing was paid")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_011_20_unknown_uid_reports_error() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"iron", 2)
	_give_piece(inventory, 40, "u1")
	watch_signals(inventory)
	var result: ActionResult = _repair(inventory, "ghost", _repair_costs())
	assert_push_error_count(1)
	assert_false(result.ok)
	assert_eq(result.error_key, CraftingSystem.ERR_PIECE_NOT_FOUND)
	assert_eq(inventory.count(&"iron"), 2, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_011_19_repair_without_costs_rejected() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(2)
	_give_piece(inventory, 40, "u1")
	watch_signals(inventory)
	var result: ActionResult = _repair(inventory, "u1", null)
	assert_push_error_count(1)
	assert_false(result.ok)
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	var piece: ItemStack = _find_uid(inventory, "u1")
	assert_not_null(piece)
	if piece != null:
		assert_eq(piece.durability, 40, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- Moving stacks between two inventories (spec 012) -------------------------
# R-012-32 (component side) and R-012-34.

var _changes: Array[String] = []


func _recorded(inventory: InventoryComponent, label: String) -> InventoryComponent:
	inventory.name = label
	inventory.inventory_changed.connect(func() -> void: _changes.append(label))
	return inventory


func test_r_012_32_move_between_two_one_signal_each() -> void:
	_changes.clear()
	var chest: InventoryComponent = _recorded(_new_inventory(2), "chest")
	var robot: InventoryComponent = _recorded(_new_inventory(2), "robot")
	_fill(chest, &"scrap", 7)
	_changes.clear()
	assert_true(chest.move_to_slot(0, robot, 1, 3).ok, "placed in the robot's slot 1")
	assert_eq(_quantities(chest), [4, 0] as Array[int], "the chest keeps the rest")
	assert_eq(_quantities(robot), [0, 3] as Array[int], "the chosen slot")
	assert_eq(_changes, ["chest", "robot"] as Array[String], "one signal each, the origin first")
	_changes.clear()
	assert_true(robot.transfer_to(chest, 1, 3).ok, "transferred back")
	assert_eq(_quantities(chest), [7, 0] as Array[int], "into the stack of the same item")
	assert_true(robot.is_empty(), "the robot gave it all")
	assert_eq(_changes, ["robot", "chest"] as Array[String], "one signal each, the origin first")
	_changes.clear()
	assert_true(chest.move_to_slot(0, chest, 1, 2).ok, "within the same inventory")
	assert_eq(_quantities(chest), [5, 2] as Array[int])
	assert_eq(_changes, ["chest"] as Array[String], "one signal for one inventory")


func test_r_012_32_move_writes_both_before_signalling() -> void:
	var chest: InventoryComponent = _new_inventory(1)
	var robot: InventoryComponent = _new_inventory(1)
	_fill(chest, &"scrap", 4)
	var seen: Array[int] = []
	chest.inventory_changed.connect(func() -> void: seen.append_array(_quantities(robot)))
	assert_true(chest.move_to_slot(0, robot, 0, 4).ok)
	assert_eq(seen, [4] as Array[int], "the target is already written when the origin signals")


func test_r_012_32_refusal_changes_nothing() -> void:
	var chest: InventoryComponent = _new_inventory(2)
	var robot: InventoryComponent = _new_inventory(1)
	_fill(chest, &"scrap", 6)
	_fill(robot, &"iron", 5)
	watch_signals(chest)
	watch_signals(robot)
	assert_eq(chest.move_to_slot(0, robot, 0, 2).error_key, InventoryRules.ERR_PARTIAL_SWAP, "partial swap")
	assert_eq(chest.transfer_to(robot, 0, 6).error_key, InventoryRules.ERR_NO_ROOM, "no room")
	assert_eq(chest.move_to_slot(0, null, 0, 1).error_key, ActionResult.ERR_INVALID_REQUEST, "no target")
	assert_eq(chest.transfer_to(null, 0, 1).error_key, ActionResult.ERR_INVALID_REQUEST, "no target")
	assert_eq(chest.transfer_to(chest, 0, 1).error_key, ActionResult.ERR_INVALID_REQUEST, "never into itself")
	assert_eq(chest.move_to_slot(5, robot, 0, 1).error_key, ActionResult.ERR_INVALID_REQUEST, "bad index")
	assert_eq(chest.move_to_slot(0, robot, 0, 7).error_key, ActionResult.ERR_INVALID_REQUEST, "too many")
	assert_eq(_quantities(chest), [6, 0] as Array[int], "the chest did not change")
	assert_eq(_quantities(robot), [5] as Array[int], "the robot did not change")
	assert_signal_emit_count(chest, "inventory_changed", 0)
	assert_signal_emit_count(robot, "inventory_changed", 0)
	assert_signal_emit_count(robot, "overflowed", 0)
	assert_push_error_count(5)


func test_r_012_32_item_unknown_to_the_target_rejected() -> void:
	var chest: InventoryComponent = _new_inventory(1)
	_fill(chest, &"scrap", 3)
	var other_catalog: DataCatalog = DataCatalog.new()
	other_catalog.items.append(_item(&"iron", 5))
	var stranger: InventoryComponent = InventoryComponent.new()
	stranger.catalog = other_catalog
	add_child_autofree(stranger)
	assert_true(stranger.set_slot_count(1).ok)
	assert_eq(chest.move_to_slot(0, stranger, 0, 3).error_key, ActionResult.ERR_INVALID_REQUEST)
	assert_eq(chest.transfer_to(stranger, 0, 3).error_key, ActionResult.ERR_INVALID_REQUEST)
	assert_eq(_quantities(chest), [3] as Array[int], "no change")
	assert_true(stranger.is_empty(), "nothing entered")
	assert_push_error_count(2)


func test_r_012_34_transfer_keeps_piece() -> void:
	_with_pieces()
	var chest: InventoryComponent = _new_inventory(2)
	var robot: InventoryComponent = _new_inventory(2)
	_give_piece(chest, 40, "u1")
	_give_piece(robot, 70, "u2")
	assert_true(chest.move_to_slot(0, robot, 0, 1).ok, "a piece onto a piece swaps")
	var swapped: ItemStack = _find_uid(chest, "u2")
	assert_not_null(swapped, "the other piece came to the chest")
	if swapped != null:
		assert_eq(swapped.durability, 70, "durability kept")
	assert_true(robot.transfer_to(chest, 0, 1).ok, "transferred to the free slot")
	var moved: ItemStack = _find_uid(chest, "u1")
	assert_not_null(moved, "the piece arrived with its uid")
	if moved != null:
		assert_eq(moved.durability, 40, "durability kept")
	assert_true(robot.is_empty(), "the robot gave it")


# --- Spec 015: exchange_slot (R-015-09, plan D7) --------------------------------


func test_r_015_09_exchange_slot() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(3)
	_fill(inventory, &"scrap", 4)
	watch_signals(inventory)
	var piece: ItemStack = _piece_stack(40, "u1")
	var result: ActionResult = inventory.exchange_slot(1, piece)
	assert_true(result.ok, "a valid piece goes into an empty slot")
	assert_signal_emit_count(inventory, "inventory_changed", 1, "one signal for one change")
	var slots: Array[ItemStack] = inventory.get_slots()
	assert_eq(slots[1].uid, "u1", "uid kept")
	assert_eq(slots[1].durability, 40, "durability kept")
	var replaced: ItemStack = _piece_stack(70, "u2", OTHER_PIECE_ID)
	result = inventory.exchange_slot(0, replaced)
	assert_true(result.ok, "it replaces what was there")
	assert_signal_emit_count(inventory, "inventory_changed", 2, "second change, second signal")
	slots = inventory.get_slots()
	assert_eq(slots[0].uid, "u2", "the scrap was replaced")
	assert_eq(inventory.count(&"scrap"), 0, "the replaced stack is gone")


func test_r_015_09_exchange_slot_null_incoming() -> void:
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 4)
	watch_signals(inventory)
	var result: ActionResult = inventory.exchange_slot(0, null)
	assert_true(result.ok, "null empties the slot")
	assert_true(inventory.is_empty(), "the slot is empty")
	assert_signal_emit_count(inventory, "inventory_changed", 1, "one change")
	result = inventory.exchange_slot(1, null)
	assert_true(result.ok, "null into an empty slot is a success")
	assert_signal_emit_count(inventory, "inventory_changed", 1, "nothing changed: no new signal")


func test_r_015_09_exchange_slot_bad_index() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 4)
	watch_signals(inventory)
	var before: Array[int] = _quantities(inventory)
	var errors: int = 0
	for index: int in [-1, 2, 99]:
		var result: ActionResult = inventory.exchange_slot(index, _piece_stack(40, "u1"))
		errors += 1
		assert_push_error_count(errors)
		assert_false(result.ok, "index %d refused" % index)
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(_quantities(inventory), before, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_015_09_exchange_slot_invalid_stack() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(2)
	_fill(inventory, &"scrap", 4)
	watch_signals(inventory)
	var before: Array[int] = _quantities(inventory)
	var two: ItemStack = _piece_stack(40, "u2")
	two.quantity = 2
	var unknown: ItemStack = ItemStack.new(_item(&"ghost", 1), 1)
	var bad: Array[ItemStack] = [
		_piece_stack(0, "u1"),
		_piece_stack(PIECE_MAX + 1, "u1"),
		_piece_stack(40, ""),
		two,
		unknown,
	]
	var errors: int = 0
	for stack: ItemStack in bad:
		var result: ActionResult = inventory.exchange_slot(1, stack)
		errors += 1
		assert_push_error_count(errors)
		assert_false(result.ok)
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST)
	assert_eq(_quantities(inventory), before, "no change")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_015_09_exchange_slot_stores_a_copy_with_catalog_item() -> void:
	_with_pieces()
	var inventory: InventoryComponent = _new_inventory(2)
	var foreign: PieceData = _piece_item(PIECE_ID)
	var incoming: ItemStack = ItemStack.new(foreign, 1)
	incoming.durability = 40
	incoming.uid = "u1"
	assert_true(inventory.exchange_slot(0, incoming).ok)
	incoming.durability = 5
	var stored: ItemStack = inventory.get_slots()[0]
	assert_eq(stored.durability, 40, "the caller's stack is not shared")
	assert_same(stored.item, _catalog.get_item(PIECE_ID), "the catalog's item, not the caller's")
