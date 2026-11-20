extends GutTest
## LootBox (spec 004): interacting with a closed box rolls its loot table once
## with its own seed and announces the stacks and who opened it (R-004-23);
## its prompt is PROMPT_OPEN in Spanish and English (R-004-25).
## Spec 005: the roll stays in the box's own InventoryComponent (R-005-17),
## every interaction with a box that holds items emits opened (R-005-16), what
## is not taken stays (R-005-20) and the box is disabled when it becomes
## empty, not when it is opened (R-005-21 replaces R-004-24).
## Spec 012: an opened box is a container with the capacity of a chest, read
## from the same resource (R-012-06); every interaction opens it, also empty,
## and it is never disabled (R-012-37 replaces R-005-16, R-005-18, R-005-21).

## Spec 010: an opened box saves its contents and is restored without rolling
## (R-010-27).
const LOOT_BOX_SCENE := preload("res://scenes/entities/loot_box.tscn")
const BASIC_BOX_PATH := "res://resources/loot/basic_box.tres"
const PROMPT_KEY := &"PROMPT_OPEN"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const SEED_A := 1111
const SEED_B := 2222

var _opener: Node3D


func before_each() -> void:
	_opener = Node3D.new()
	add_child_autofree(_opener)


func _new_box(loot_seed: int) -> LootBox:
	var box: LootBox = LOOT_BOX_SCENE.instantiate() as LootBox
	add_child_autofree(box)
	box.setup(loot_seed)
	watch_signals(box)
	return box


func _interactable(box: LootBox) -> InteractableComponent:
	return box.get_node("%Interactable") as InteractableComponent


func _open(box: LootBox) -> void:
	_interactable(box).interact(_opener)


## A table that always rolls the same: fixed quantities of real catalog items.
func _fixed_table(quantities: Dictionary[StringName, int]) -> LootTableData:
	var table: LootTableData = LootTableData.new()
	for id: StringName in quantities:
		var entry: LootEntryData = LootEntryData.new()
		entry.item = DataRegistry.get_item(id)
		entry.min_quantity = quantities[id]
		entry.max_quantity = quantities[id]
		table.entries.append(entry)
	return table


func _new_box_with_table(table: LootTableData) -> LootBox:
	var box: LootBox = LOOT_BOX_SCENE.instantiate() as LootBox
	box.loot_table = table
	add_child_autofree(box)
	box.setup(SEED_A)
	watch_signals(box)
	return box


## An inventory that takes from boxes, like the robot's.
func _new_taker(slot_count: int) -> InventoryComponent:
	var taker: InventoryComponent = InventoryComponent.new()
	add_child_autofree(taker)
	taker.set_slot_count(slot_count)
	return taker


func _take_all(taker: InventoryComponent, box: LootBox) -> InventoryAddResult:
	var every_slot: Array[int] = []
	every_slot.assign(range(box.get_contents().get_slot_count()))
	return taker.take_from(box.get_contents(), every_slot)


## Contents of the box as "item id → quantity".
func _contents(box: LootBox) -> Dictionary[StringName, int]:
	var contents: Dictionary[StringName, int] = {}
	for stack: ItemStack in box.get_contents().get_slots():
		if stack != null:
			contents[stack.item.id] = contents.get(stack.item.id, 0) + stack.quantity
	return contents


## Loot of the last opening as "item id → quantity".
func _loot(box: LootBox) -> Dictionary[StringName, int]:
	var loot: Dictionary[StringName, int] = {}
	var parameters: Array = get_signal_parameters(box, "loot_generated")
	var stacks: Array[ItemStack] = parameters[0]
	for stack: ItemStack in stacks:
		loot[stack.item.id] = stack.quantity
	return loot


func _expected_loot(loot_seed: int) -> Dictionary[StringName, int]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = loot_seed
	var loot: Dictionary[StringName, int] = {}
	var table: LootTableData = load(BASIC_BOX_PATH) as LootTableData
	for stack: ItemStack in LootSystem.roll(table, rng):
		loot[stack.item.id] = stack.quantity
	return loot


func test_r_004_22_box_uses_basic_box_table() -> void:
	var box: LootBox = _new_box(SEED_A)
	assert_not_null(box.loot_table, "the box has a loot table")
	if box.loot_table != null:
		assert_eq(box.loot_table.resource_path, BASIC_BOX_PATH, "the basic box table")


func test_r_004_23_open_emits_once_with_opener() -> void:
	var box: LootBox = _new_box(SEED_A)
	assert_false(box.is_opened(), "a new box is closed")
	_open(box)
	assert_signal_emit_count(box, "loot_generated", 1)
	var parameters: Array = get_signal_parameters(box, "loot_generated")
	var opener: Node3D = parameters[1]
	assert_same(opener, _opener, "the signal says who opened the box")
	var loot: Dictionary[StringName, int] = _loot(box)
	var scrap: int = loot.get(&"scrap", 0)
	assert_between(scrap, 2, 5, "scrap inside its range (BALANCE §2.1)")
	assert_eq(loot, _expected_loot(SEED_A), "the loot is the roll of the box's own seed")


func test_r_004_23_zero_quantities_left_out() -> void:
	for loot_seed: int in 20:
		var box: LootBox = _new_box(loot_seed)
		_open(box)
		for quantity: int in _loot(box).values():
			assert_gt(quantity, 0, "seed %d: no stack of 0" % loot_seed)


func test_r_004_23_contents_independent_of_open_order() -> void:
	var first_a: LootBox = _new_box(SEED_A)
	var first_b: LootBox = _new_box(SEED_B)
	_open(first_a)
	_open(first_b)
	var second_a: LootBox = _new_box(SEED_A)
	var second_b: LootBox = _new_box(SEED_B)
	_open(second_b)
	_open(second_a)
	assert_eq(_loot(first_a), _loot(second_a), "box A gives the same whatever the order")
	assert_eq(_loot(first_b), _loot(second_b), "box B too")


func test_r_004_23_not_set_up_reports_error() -> void:
	var box: LootBox = LOOT_BOX_SCENE.instantiate() as LootBox
	box.name = "Unseeded"
	add_child_autofree(box)
	watch_signals(box)
	_open(box)
	assert_push_error("Unseeded")
	assert_signal_not_emitted(box, "loot_generated")
	assert_false(box.is_opened(), "a box without seed stays closed")


func test_r_005_16_interaction_emits_opened_with_opener() -> void:
	var box: LootBox = _new_box(SEED_A)
	_open(box)
	assert_signal_emit_count(box, "opened", 1, "the first interaction opens the box")
	var parameters: Array = get_signal_parameters(box, "opened")
	var opener: Node3D = parameters[0]
	assert_same(opener, _opener, "opened says who interacted")
	_open(box)
	assert_signal_emit_count(box, "opened", 2, "every interaction with loot inside opens it again")


func test_r_005_17_rolls_once_into_contents() -> void:
	var box: LootBox = _new_box(SEED_A)
	assert_true(box.get_contents().is_empty(), "nothing inside before the first interaction")
	_open(box)
	assert_eq(_contents(box), _expected_loot(SEED_A), "the contents are the roll of the box's seed")
	assert_eq(
		box.get_contents().get_slot_count(), _capacity(), "the capacity of a chest (R-012-37)"
	)
	_open(box)
	_open(box)
	assert_signal_emit_count(box, "loot_generated", 1, "loot is generated only once")
	assert_eq(_contents(box), _expected_loot(SEED_A), "later interactions show the same contents")


func test_r_005_17_announced_stacks_cannot_change_contents() -> void:
	var box: LootBox = _new_box(SEED_A)
	_open(box)
	var parameters: Array = get_signal_parameters(box, "loot_generated")
	var stacks: Array[ItemStack] = parameters[0]
	stacks[0].quantity += 50
	assert_eq(_contents(box), _expected_loot(SEED_A), "the box keeps its own copies")


func test_r_005_20_partly_taken_box_stays_enabled() -> void:
	var box: LootBox = _new_box_with_table(_fixed_table({&"scrap": 3, &"iron": 1}))
	var closed_mesh: MeshInstance3D = box.get_node("%ClosedMesh") as MeshInstance3D
	var opened_mesh: MeshInstance3D = box.get_node("%OpenedMesh") as MeshInstance3D
	assert_true(closed_mesh.visible, "closed look while closed")
	assert_false(opened_mesh.visible, "opened look hidden while closed")
	assert_true(_interactable(box).enabled, "a closed box is interactable")
	_open(box)
	assert_true(box.is_opened(), "the box is opened")
	assert_false(closed_mesh.visible, "closed look hidden once opened")
	assert_true(opened_mesh.visible, "opened look shown once opened")
	assert_true(_interactable(box).enabled, "an opened box with loot is still interactable")
	# One slot: the scrap enters and the iron does not fit.
	var result: InventoryAddResult = _take_all(_new_taker(1), box)
	assert_false(result.ok, "not everything fits")
	var rest: Dictionary[StringName, int] = {&"iron": 1}
	assert_eq(_contents(box), rest, "the box keeps the rest")
	assert_true(_interactable(box).enabled, "a box with items left stays interactable")
	assert_true(opened_mesh.visible, "with the opened look")
	_open(box)
	assert_signal_emit_count(box, "opened", 2, "it can be opened again")
	assert_signal_emit_count(box, "loot_generated", 1, "without a new roll")


func test_r_004_25_prompt_open_translated_es_en() -> void:
	var box: LootBox = _new_box(SEED_A)
	assert_eq(_interactable(box).prompt_key, PROMPT_KEY, "the prompt is a translation key")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(PROMPT_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, PROMPT_KEY])


func test_r_004_01_box_is_an_obstacle() -> void:
	var box: LootBox = _new_box(SEED_A)
	var shapes: Array[Node] = box.find_children("*", "CollisionShape3D", false, false)
	assert_eq(shapes.size(), 1, "the box body has a collider")


func test_r_010_27_save_state_null_when_closed() -> void:
	var box: LootBox = _new_box(SEED_A)
	var state: Variant = box.get_save_state()
	assert_true(state == null, "a closed box has nothing to save")


func test_r_010_27_save_state_holds_contents_once_opened() -> void:
	var box: LootBox = _new_box(SEED_A)
	_open(box)
	var state: Variant = box.get_save_state()
	assert_true(state is Dictionary, "a dictionary once opened")
	if not state is Dictionary:
		return
	var saved: Dictionary = state
	var expected: Dictionary = {"contents": box.get_contents().to_save_data()}
	assert_eq(saved, expected, "exactly the contents of the box")


func test_r_010_27_restore_opened() -> void:
	var source: LootBox = _new_box(SEED_A)
	_open(source)
	var state: Variant = source.get_save_state()
	var saved: Dictionary = state as Dictionary
	var target: LootBox = _new_box(SEED_B)
	target.restore_opened(saved)
	assert_true(target.is_opened(), "opened")
	assert_eq(_contents(target), _contents(source), "the saved stacks, not a new roll")
	assert_eq(
		target.get_contents().get_slot_count(),
		source.get_contents().get_slot_count(),
		"slot count of the saved slots"
	)
	var closed_mesh: MeshInstance3D = target.get_node("%ClosedMesh") as MeshInstance3D
	var opened_mesh: MeshInstance3D = target.get_node("%OpenedMesh") as MeshInstance3D
	assert_false(closed_mesh.visible, "closed look hidden")
	assert_true(opened_mesh.visible, "opened look shown")
	assert_true(_interactable(target).enabled, "it still has loot")
	assert_signal_not_emitted(target, "loot_generated", "restoring is not a roll")
	assert_signal_not_emitted(target, "opened", "restoring is not an opening")


func test_r_010_27_restore_on_opened_box_reports_error() -> void:
	var box: LootBox = _new_box(SEED_A)
	_open(box)
	var before: Dictionary[StringName, int] = _contents(box)
	var other: LootBox = _new_box_with_table(_fixed_table({&"iron": 1}))
	_open(other)
	var state: Variant = other.get_save_state()
	var saved: Dictionary = state as Dictionary
	box.restore_opened(saved)
	assert_push_error_count(1)
	assert_eq(_contents(box), before, "nothing changed")


# --- The box as a container (spec 012) ----------------------------------------

const CONTAINER_PATH := "res://resources/config/container.tres"
const CHEST_PATH := "res://resources/structures/storage_chest.tres"


func _capacity() -> int:
	return (load(CONTAINER_PATH) as ContainerConfigData).slot_count


func test_r_012_06_box_reads_the_chest_container() -> void:
	var box: LootBox = _new_box(SEED_A)
	var chest: StorageChestData = load(CHEST_PATH) as StorageChestData
	assert_not_null(box.container_config, "the box has a container capacity")
	assert_same(box.container_config, chest.container, "the same resource as the chest")


func test_r_012_37_capacity_of_a_chest() -> void:
	var box: LootBox = _new_box_with_table(_fixed_table({&"scrap": 3}))
	_open(box)
	assert_eq(box.get_contents().get_slot_count(), _capacity(), "room for what the player leaves")
	assert_eq(_contents(box), {&"scrap": 3} as Dictionary[StringName, int], "with its roll")
	assert_true(box.get_contents().add(&"iron", 2).ok, "something can be left in it")


func test_r_012_37_every_interaction_opens_also_empty() -> void:
	var box: LootBox = _new_box_with_table(_fixed_table({&"scrap": 0}))
	_open(box)
	assert_signal_emit_count(box, "loot_generated", 1, "the empty roll is announced")
	assert_signal_emit_count(box, "opened", 1, "and the box opens, empty")
	_open(box)
	assert_signal_emit_count(box, "opened", 2, "every interaction opens it")
	assert_signal_emit_count(box, "loot_generated", 1, "without a new roll")


func test_r_012_37_never_disabled() -> void:
	var box: LootBox = _new_box(SEED_A)
	_open(box)
	assert_true(_take_all(_new_taker(5), box).ok, "everything is taken")
	assert_true(box.get_contents().is_empty(), "the box is empty")
	assert_true(_interactable(box).enabled, "an emptied box stays interactable")
	_open(box)
	assert_signal_emit_count(box, "opened", 2, "and opens again")
	assert_signal_emit_count(box, "loot_generated", 1, "never rolling again")


func test_r_012_37_restored_box_has_capacity() -> void:
	var box: LootBox = _new_box(SEED_B)
	var saved_slots: Array = [{"item_id": "scrap", "quantity": 2, "durability": -1, "uid": ""}]
	box.restore_opened({"contents": {"slots": saved_slots}})
	assert_eq(box.get_contents().get_slot_count(), _capacity(), "a box saved before spec 012 gets the capacity")
	assert_eq(_contents(box), {&"scrap": 2} as Dictionary[StringName, int], "with its saved stacks")


func test_r_012_37_restored_empty_box_stays_enabled() -> void:
	for slots: Array in [[null, null], []]:
		var box: LootBox = _new_box(SEED_A)
		box.restore_opened({"contents": {"slots": slots}})
		assert_true(box.is_opened(), "opened")
		assert_true(_interactable(box).enabled, "nothing left, still enabled (%s)" % [slots])
		var opened_mesh: MeshInstance3D = box.get_node("%OpenedMesh") as MeshInstance3D
		assert_true(opened_mesh.visible, "opened look")
		_open(box)
		assert_signal_emit_count(box, "opened", 1, "and it opens the container (%s)" % [slots])
