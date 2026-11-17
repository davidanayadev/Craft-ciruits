extends GutTest
## BuildScreen (spec 009): lists the structure recipes of the workbench with
## name and cost (R-009-64), texts from translation keys in ES and EN
## (R-009-64), "Build" disabled with a notice when the player cannot pay
## (R-009-39) or the base is full (R-009-38), and picking a recipe closes the
## screen and asks to build without charging anything (R-009-65).
## Headless cannot click Controls (ADR 0002): buttons are pressed by signal.

const SCREEN_SCENE := preload("res://scenes/ui/build_screen.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const RECIPE_ID := &"charging_station"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const KEYS: Array[StringName] = [
	&"BUILD_TITLE",
	&"BUILD_BUTTON",
	&"BUILD_COST_ENTRY",
	&"STRUCTURE_CHARGING_STATION",
	&"ERR_NOT_ENOUGH_MATERIALS",
	&"MSG_BASE_FULL",
]

var _screen: BuildScreen
var _robot: Robot
var _structures: BaseStructures


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_structures = _new_structures(load(BASE_GRID_PATH) as BuildGridData)
	_screen = SCREEN_SCENE.instantiate() as BuildScreen
	add_child_autofree(_screen)


func _new_structures(grid: BuildGridData) -> BaseStructures:
	var structures: BaseStructures = BaseStructures.new()
	structures.grid_config = grid
	add_child_autofree(structures)
	return structures


func _setup() -> void:
	_screen.setup({BuildScreen.CONTEXT_PLAYER: _robot, BuildScreen.CONTEXT_BASE: _structures})


func _recipe() -> RecipeData:
	return DataRegistry.get_recipe(RECIPE_ID)


func _entry() -> Node:
	return _screen.get_node("%Entries").get_node_or_null(String(RECIPE_ID))


func _button() -> Button:
	return _entry().get_node("BuildButton") as Button


func _notice() -> Label:
	return _entry().get_node("Notice") as Label


func _give_cost() -> void:
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(_recipe())
	for item_id: StringName in cost:
		_robot.inventory.add(item_id, cost[item_id])


func test_r_009_64_lists_recipes_with_name_and_cost() -> void:
	_setup()
	var entries: Array[Node] = _screen.get_node("%Entries").get_children()
	assert_eq(entries.size(), 1, "one structure recipe at the bench")
	assert_not_null(_entry(), "the charging station is listed")
	if _entry() == null:
		return
	var name_label: Label = _entry().get_node("Name") as Label
	assert_eq(name_label.text, "STRUCTURE_CHARGING_STATION", "its name, as a key")
	var cost_label: Label = _entry().get_node("Cost") as Label
	var scrap_name: String = TranslationServer.translate(&"ITEM_SCRAP")
	var expected: String = TranslationServer.translate(&"BUILD_COST_ENTRY") % [scrap_name, 4]
	assert_eq(cost_label.text, expected, "its cost (BALANCE §5.3)")


func test_r_009_64_texts_are_keys() -> void:
	_setup()
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, "BUILD_TITLE", "the title is a key")
	assert_eq(_button().text, "BUILD_BUTTON", "the button is a key")
	for locale: String in SUPPORTED_LOCALES:
		for key: StringName in KEYS:
			var text: String = ""
			for translation: Translation in TranslationServer.find_translations(locale, true):
				text = translation.get_message(key)
				if not text.is_empty():
					break
			assert_ne(text, "", "%s has a text in %s" % [key, locale])


func test_r_009_39_missing_materials_disables() -> void:
	_setup()
	assert_true(_button().disabled, "nothing to pay with: disabled")
	assert_true(_notice().visible, "with a notice")
	assert_eq(_notice().text, String(CraftingSystem.ERR_NOT_ENOUGH_MATERIALS), "the missing-materials key")
	watch_signals(_robot)
	_button().pressed.emit()
	assert_signal_not_emitted(_robot, "build_requested", "a disabled entry asks for nothing")


func test_r_009_38_full_base_disables_with_notice() -> void:
	var full: BuildGridData = BuildGridData.new()
	full.cell_size_m = 1.0
	full.area_size_cells = Vector2i(1, 1)
	full.reserved_cells = [Vector2i(0, 0)] as Array[Vector2i]
	_structures = _new_structures(full)
	_give_cost()
	_setup()
	assert_true(_button().disabled, "no room: disabled")
	assert_eq(_notice().text, String(BuildScreen.MSG_BASE_FULL), "the base-full notice")
	assert_eq(_robot.inventory.count(&"scrap"), 4, "nothing was spent")


func test_r_009_65_pick_requests_placement_without_cost() -> void:
	_give_cost()
	_setup()
	assert_false(_button().disabled, "enough scrap and room: enabled")
	assert_false(_notice().visible, "no notice")
	watch_signals(_robot)
	watch_signals(_screen)
	_button().pressed.emit()
	assert_signal_emit_count(_screen, "close_requested", 1, "the screen closes")
	assert_signal_emit_count(_robot, "build_requested", 1, "and asks to build")
	assert_signal_emitted_with_parameters(_robot, "build_requested", [_robot, _recipe()])
	assert_eq(_robot.inventory.count(&"scrap"), 4, "nothing is charged yet")
