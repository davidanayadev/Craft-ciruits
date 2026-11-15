extends GutTest
## LootBox (spec 004): interacting with a closed box rolls its loot table once
## with its own seed and announces the stacks and who opened it (R-004-23);
## an opened box shows it, stops being interactable and never gives loot again
## (R-004-24); its prompt is PROMPT_OPEN in Spanish and English (R-004-25).
## Nobody listens to loot_generated yet: spec 005 connects the inventory.

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


func test_r_004_24_opened_state_and_disabled() -> void:
	var box: LootBox = _new_box(SEED_A)
	var closed_mesh: MeshInstance3D = box.get_node("%ClosedMesh") as MeshInstance3D
	var opened_mesh: MeshInstance3D = box.get_node("%OpenedMesh") as MeshInstance3D
	assert_true(closed_mesh.visible, "closed look while closed")
	assert_false(opened_mesh.visible, "opened look hidden while closed")
	assert_true(_interactable(box).enabled, "a closed box is interactable")
	_open(box)
	assert_true(box.is_opened(), "the box is opened")
	assert_false(closed_mesh.visible, "closed look hidden once opened")
	assert_true(opened_mesh.visible, "opened look shown once opened")
	assert_false(_interactable(box).enabled, "an opened box is no longer interactable")


func test_r_004_24_second_interact_no_loot() -> void:
	var box: LootBox = _new_box(SEED_A)
	_open(box)
	_open(box)
	# Even if something enabled the interactable again, the box stays opened.
	_interactable(box).enabled = true
	_open(box)
	assert_signal_emit_count(box, "loot_generated", 1, "loot is generated only once")


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
