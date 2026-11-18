extends GutTest
## DroppedItem (spec 008): it holds stacks with uid, zone, local position and
## drop time (R-008-10), moving stacks in and out never creates or loses items
## (R-008-11), it is interactable with the PROMPT_PICK_UP prompt in Spanish and
## English (R-008-12), interacting takes everything in slot order (R-008-13),
## it announces once that it was emptied (R-008-14), a partial pick-up keeps
## the rest and the time (R-008-15), its data is JSON only (R-008-17) and a
## reset leaves nothing of the previous use (R-008-18). Spec 011: its data
## carries the durability and uid of each stack (R-011-10).

const DROPPED_ITEM_SCENE := preload("res://scenes/entities/dropped_item.tscn")
const PROMPT_KEY := &"PROMPT_PICK_UP"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const UID := "abc123"
const ZONE := Vector2i(2, -3)
const LOCAL_POSITION := Vector3(1.5, 0.0, -4.25)
const DROPPED_AT := 1700000000
const SLOTS := 6


func _new_item(slot_count: int = SLOTS) -> DroppedItem:
	var item: DroppedItem = DROPPED_ITEM_SCENE.instantiate() as DroppedItem
	add_child_autofree(item)
	item.setup(UID, ZONE, LOCAL_POSITION, DROPPED_AT, slot_count)
	return item


func _interactable(item: DroppedItem) -> InteractableComponent:
	return item.get_node("%Interactable") as InteractableComponent


## A node with an InventoryComponent child, like the robot.
func _new_interactor(slot_count: int) -> Node3D:
	var interactor: Node3D = Node3D.new()
	add_child_autofree(interactor)
	var inventory: InventoryComponent = InventoryComponent.new()
	interactor.add_child(inventory)
	inventory.set_slot_count(slot_count)
	return interactor


func _inventory_of(interactor: Node3D) -> InventoryComponent:
	return InventoryComponent.find_in(interactor)


func _totals(inventory: InventoryComponent) -> Dictionary[StringName, int]:
	var totals: Dictionary[StringName, int] = {}
	for stack: ItemStack in inventory.get_slots():
		if stack != null:
			totals[stack.item.id] = totals.get(stack.item.id, 0) + stack.quantity
	return totals


func _slot_ids(inventory: InventoryComponent) -> Array[StringName]:
	var ids: Array[StringName] = []
	for stack: ItemStack in inventory.get_slots():
		if stack != null:
			ids.append(stack.item.id)
	return ids


func _fill_three(item: DroppedItem) -> void:
	var contents: InventoryComponent = item.get_contents()
	contents.add(&"scrap", 3)
	contents.add(&"iron", 2)
	contents.add(&"cables", 1)


func _assert_json_types(value: Variant, path: String) -> void:
	match typeof(value):
		TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			pass
		TYPE_ARRAY:
			var array: Array = value
			for i: int in array.size():
				_assert_json_types(array[i], "%s[%d]" % [path, i])
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			for key: Variant in dictionary:
				assert_eq(typeof(key), TYPE_STRING, "%s: keys are strings" % path)
				_assert_json_types(dictionary[key], "%s.%s" % [path, key])
		_:
			fail_test("%s: type %d is not JSON" % [path, typeof(value)])


func test_r_008_10_holds_stacks_uid_zone_and_time() -> void:
	var item: DroppedItem = _new_item(4)
	item.get_contents().add(&"scrap", 7)
	assert_eq(item.uid, UID, "uid")
	assert_eq(item.zone_id, ZONE, "zone")
	assert_eq(item.local_position, LOCAL_POSITION, "position local to the zone")
	assert_eq(item.dropped_at_unix, DROPPED_AT, "drop time")
	assert_eq(item.get_contents().get_slot_count(), 4, "slot count from setup")
	var expected: Dictionary[StringName, int] = {&"scrap": 7}
	assert_eq(_totals(item.get_contents()), expected, "the stacks it holds")


func test_r_008_11_drop_and_pick_up_keep_totals() -> void:
	var scrap_max: int = DataRegistry.get_item(&"scrap").stack_max
	var source: InventoryComponent = InventoryComponent.new()
	add_child_autofree(source)
	source.set_slot_count(5)
	# Scrap makes a full stack and a partial one; cables a second partial stack.
	source.add(&"scrap", scrap_max + 5)
	source.add(&"iron", 3)
	source.add(&"cables", 7)
	var before: Dictionary[StringName, int] = _totals(source)
	var item: DroppedItem = _new_item(source.get_slot_count())
	var every_slot: Array[int] = []
	every_slot.assign(range(source.get_slot_count()))
	assert_true(item.get_contents().take_from(source, every_slot).ok, "everything fits the item")
	assert_true(source.is_empty(), "the source gave everything")
	assert_eq(_totals(item.get_contents()), before, "the item holds exactly what was dropped")
	var picker: Node3D = _new_interactor(5)
	_interactable(item).interact(picker)
	assert_eq(_totals(_inventory_of(picker)), before, "the picker gets exactly the same")
	assert_true(item.get_contents().is_empty(), "nothing left on the ground")


func test_r_008_12_interactable_with_pick_up_prompt() -> void:
	var item: DroppedItem = _new_item()
	var interactable: InteractableComponent = _interactable(item)
	assert_not_null(interactable, "it has an interactable")
	assert_eq(interactable.prompt_key, PROMPT_KEY, "the prompt is a translation key")
	assert_true(interactable.enabled, "enabled after setup")


func test_r_008_12_prompt_translated_es_en() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(PROMPT_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, PROMPT_KEY])


func test_r_008_13_interact_takes_all_in_slot_order() -> void:
	var item: DroppedItem = _new_item()
	_fill_three(item)
	var picker: Node3D = _new_interactor(5)
	_interactable(item).interact(picker)
	var expected_ids: Array[StringName] = [&"scrap", &"iron", &"cables"]
	assert_eq(_slot_ids(_inventory_of(picker)), expected_ids, "taken in the item's slot order")
	var expected: Dictionary[StringName, int] = {&"scrap": 3, &"iron": 2, &"cables": 1}
	assert_eq(_totals(_inventory_of(picker)), expected, "all of it")
	assert_true(item.get_contents().is_empty(), "the item is empty")


func test_r_008_13_interactor_without_inventory_reports_error() -> void:
	var item: DroppedItem = _new_item()
	_fill_three(item)
	watch_signals(item)
	var bare: Node3D = Node3D.new()
	add_child_autofree(bare)
	_interactable(item).interact(bare)
	assert_push_error("has no InventoryComponent")
	var expected: Dictionary[StringName, int] = {&"scrap": 3, &"iron": 2, &"cables": 1}
	assert_eq(_totals(item.get_contents()), expected, "nothing changes")
	assert_signal_not_emitted(item, "emptied")
	assert_true(_interactable(item).enabled, "still interactable")


func test_r_008_14_emptied_once() -> void:
	var item: DroppedItem = _new_item()
	watch_signals(item)
	item.setup(UID, ZONE, LOCAL_POSITION, DROPPED_AT, SLOTS)
	item.get_contents().add(&"scrap", 3)
	assert_signal_not_emitted(item, "emptied", "setup and filling do not emit it")
	var picker: Node3D = _new_interactor(5)
	_interactable(item).interact(picker)
	assert_signal_emit_count(item, "emptied", 1, "emitted when the last stack is picked")
	var parameters: Array = get_signal_parameters(item, "emptied")
	var emitter: DroppedItem = parameters[0]
	assert_same(emitter, item, "it passes itself")
	_interactable(item).interact(picker)
	assert_signal_emit_count(item, "emptied", 1, "a second interact emits nothing more")
	assert_false(_interactable(item).enabled, "emptied means disabled")


func test_r_008_15_partial_pick_up_keeps_rest_and_time() -> void:
	var item: DroppedItem = _new_item()
	item.get_contents().add(&"scrap", 3)
	item.get_contents().add(&"iron", 2)
	watch_signals(item)
	var picker: Node3D = _new_interactor(1)
	var inventory: InventoryComponent = _inventory_of(picker)
	watch_signals(inventory)
	_interactable(item).interact(picker)
	var taken: Dictionary[StringName, int] = {&"scrap": 3}
	assert_eq(_totals(inventory), taken, "what fits enters")
	var rest: Dictionary[StringName, int] = {&"iron": 2}
	assert_eq(_totals(item.get_contents()), rest, "the rest stays")
	assert_eq(item.dropped_at_unix, DROPPED_AT, "the drop time does not change")
	assert_signal_not_emitted(item, "emptied")
	assert_true(_interactable(item).enabled, "still interactable")
	assert_signal_emitted(inventory, "overflowed", "the player's inventory reports it")


func test_r_008_17_data_is_json_only() -> void:
	var item: DroppedItem = _new_item()
	_fill_three(item)
	var data: Dictionary = item.to_data()
	var keys: Array = data.keys()
	keys.sort()
	var expected_keys: Array = ["dropped_at", "position", "stacks", "uid", "zone_id"]
	assert_eq(keys, expected_keys, "the keys of the spec")
	var uid: String = data["uid"]
	assert_eq(uid, UID, "uid")
	var zone: Array = data["zone_id"]
	assert_eq(zone.size(), 2, "zone_id is [x, y]")
	var position: Array = data["position"]
	assert_eq(position.size(), 3, "position is [x, y, z]")
	var stacks: Array = data["stacks"]
	assert_eq(stacks.size(), 3, "one entry per stack")
	for entry: Dictionary in stacks:
		var item_id: Variant = entry["item_id"]
		assert_eq(typeof(item_id), TYPE_STRING, "item_id is a String")
		assert_true(entry.has("quantity"), "stacks carry a quantity")
	_assert_json_types(data, "data")
	var text: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "the text parses")
	# JSON reads every number back as a float, so the round trip is compared
	# value by value and not as text.
	var parsed_data: Dictionary = parsed
	var parsed_uid: String = parsed_data["uid"]
	var parsed_time: float = parsed_data["dropped_at"]
	var original_time: int = data["dropped_at"]
	assert_eq(parsed_uid, uid, "the round trip keeps the uid")
	assert_eq(int(parsed_time), original_time, "and the drop time")
	var parsed_stacks: Array = parsed_data["stacks"]
	assert_eq(parsed_stacks.size(), stacks.size(), "and every stack")
	var first: Dictionary = parsed_stacks[0]
	var first_id: String = first["item_id"]
	var first_quantity: float = first["quantity"]
	var original_first: Dictionary = stacks[0]
	var original_quantity: int = original_first["quantity"]
	assert_eq(first_id, "scrap", "first stack in slot order")
	assert_eq(int(first_quantity), original_quantity, "with its quantity")


func test_r_008_18_reset_leaves_nothing() -> void:
	var item: DroppedItem = _new_item()
	_fill_three(item)
	item.reset()
	assert_true(item.get_contents().is_empty(), "no stacks")
	assert_eq(item.get_contents().get_slot_count(), 0, "no slots")
	assert_eq(item.uid, "", "no uid")
	assert_eq(item.zone_id, Vector2i.ZERO, "zone cleared")
	assert_eq(item.local_position, Vector3.ZERO, "position cleared")
	assert_eq(item.dropped_at_unix, 0, "time cleared")
	assert_false(_interactable(item).enabled, "not interactable")
	item.setup("other", Vector2i(1, 1), Vector3.ONE, 5, 2)
	assert_eq(item.get_contents().get_slot_count(), 2, "a new use with another slot count")
	assert_true(item.get_contents().is_empty(), "starts empty")
	assert_true(_interactable(item).enabled, "interactable again")


# --- Pieces (spec 011) --------------------------------------------------------

func test_r_011_10_to_data_has_durability_and_uid() -> void:
	var item: DroppedItem = _new_item()
	var piece: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(&"basic_arms"))
	piece.durability = 40
	var offered: Array[ItemStack] = [ItemStack.new(DataRegistry.get_item(&"scrap"), 3), piece]
	assert_true(item.get_contents().add_stacks(offered).ok, "both stacks enter")
	var data: Dictionary = item.to_data()
	var stacks: Array = data["stacks"]
	assert_eq(stacks.size(), 2, "one entry per stack")
	if stacks.size() != 2:
		return
	var material: Dictionary = stacks[0]
	var material_durability: int = material["durability"]
	var material_uid: String = material["uid"]
	assert_eq(material_durability, -1, "a material has no durability")
	assert_eq(material_uid, "", "a material has no uid")
	var saved_piece: Dictionary = stacks[1]
	var piece_durability: int = saved_piece["durability"]
	var piece_uid: String = saved_piece["uid"]
	assert_eq(piece_durability, 40, "the piece's durability")
	assert_eq(piece_uid, piece.uid, "the piece's uid")
	_assert_json_types(data, "data")
