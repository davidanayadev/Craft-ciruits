extends GutTest
## StorageChest (spec 012): the placed chest is presentation only. Interacting
## announces `used` with the user (BaseStructures relays it, plan §1 point 4);
## its contents live in StructureStates, never in the instance (plan D5).

const CHEST_SCENE := preload("res://scenes/base/storage_chest.tscn")
const CHEST_PATH := "res://resources/structures/storage_chest.tres"
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _chest: StorageChest


func before_each() -> void:
	_chest = CHEST_SCENE.instantiate() as StorageChest
	add_child_autofree(_chest)


func _interactable() -> InteractableComponent:
	return _chest.get_node("%Interactable") as InteractableComponent


func test_r_012_01_scene_of_the_chest_data() -> void:
	assert_not_null(_chest, "storage_chest.tscn is a StorageChest")
	var structure: StructureData = load(CHEST_PATH) as StructureData
	assert_same(structure.scene, CHEST_SCENE, "the StructureData places this scene")
	var shapes: Array[Node] = _chest.find_children("*", "CollisionShape3D", false, false)
	assert_gt(shapes.size(), 0, "it has a body")


func test_r_012_27_prompt_open() -> void:
	assert_eq(_interactable().prompt_key, &"PROMPT_OPEN", "prompt key")
	for locale: String in SUPPORTED_LOCALES:
		var found: bool = false
		for translation: Translation in TranslationServer.find_translations(locale, true):
			found = found or not translation.get_message(&"PROMPT_OPEN").is_empty()
		assert_true(found, "PROMPT_OPEN translated in %s" % locale)


func test_r_012_27_interaction_announces_used() -> void:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.set_physics_process(false)
	watch_signals(_chest)
	_interactable().interact(robot)
	assert_signal_emit_count(_chest, "used", 1)
	assert_signal_emitted_with_parameters(_chest, "used", [robot])


func test_r_012_26_instance_holds_no_contents() -> void:
	assert_eq(_chest.find_children("*", "InventoryComponent", true, false).size(), 0, "contents live in StructureStates")
