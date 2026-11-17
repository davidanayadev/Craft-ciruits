extends GutTest
## PlacementScreen (spec 009), opened through a real UIManager on a loaded
## base: the preview starts on the free cell nearest the robot, snapped to the
## grid (R-009-33), green or red (R-009-34); confirming places and charges
## (R-009-35), an invalid cell changes nothing (R-009-36), cancelling charges
## nothing (R-009-37); texts are keys and Enter confirms (R-009-40); edit mode
## picks a structure and moves it at no cost (R-009-43, R-009-60), cancelling
## a move keeps it (R-009-44); stations are back on when it closes (R-009-50);
## a tap moves the preview (R-009-55); buttons, Escape and back (R-009-56).
## Headless cannot click Controls (ADR 0002): buttons are pressed by signal.

const UI_MANAGER_SCENE := preload("res://scenes/ui/ui_manager.tscn")
const BASE_SCENE := preload("res://scenes/base/base.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const SCREENS_PATH := "res://resources/ui/screens.tres"
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const RECIPE_PATH := "res://resources/recipes/charging_station.tres"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const INPUT_FRAMES := 2
const ROBOT_CELL := Vector2i(4, 4)
const TARGET_CELL := Vector2i(9, 2)
const PLACED_CELL := Vector2i(2, 5)
const NO_CELL := Vector2i(-1, -1)

var _manager: UIManager
var _base: BaseZone
var _structures: BaseStructures
var _robot: Robot
var _recipe: RecipeData
var _grid: BuildGridData


func before_each() -> void:
	_grid = load(BASE_GRID_PATH) as BuildGridData
	_recipe = load(RECIPE_PATH) as RecipeData
	_structures = BaseStructures.new()
	_structures.grid_config = _grid
	add_child_autofree(_structures)
	_base = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(_base)
	_structures.bind_base(_base)
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_robot.global_position = _world_of(ROBOT_CELL)
	_manager = UI_MANAGER_SCENE.instantiate() as UIManager
	_manager.catalog = load(SCREENS_PATH) as UIScreenCatalog
	add_child_autofree(_manager)


func after_each() -> void:
	_send_action(&"pause", false)
	_send_action(&"confirm", false)


func _world_of(cell: Vector2i) -> Vector3:
	return _structures.cell_to_world(_recipe.result_structure, cell)


func _send_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _cost() -> int:
	return CraftingSystem.cost_of(_recipe)[&"scrap"]


func _open_place() -> PlacementScreen:
	_manager.open(
		PlacementScreen.SCREEN_ID,
		{
			PlacementScreen.CONTEXT_PLAYER: _robot,
			PlacementScreen.CONTEXT_BASE: _structures,
			PlacementScreen.CONTEXT_RECIPE: _recipe,
		}
	)
	return _screen()


func _open_edit() -> PlacementScreen:
	_manager.open(
		PlacementScreen.SCREEN_ID,
		{PlacementScreen.CONTEXT_PLAYER: _robot, PlacementScreen.CONTEXT_BASE: _structures}
	)
	return _screen()


func _screen() -> PlacementScreen:
	for child: Node in _manager.get_children():
		var screen: PlacementScreen = child as PlacementScreen
		if screen != null and not screen.is_queued_for_deletion():
			return screen
	return null


func _place_one() -> String:
	_robot.inventory.add(&"scrap", _cost())
	assert_true(_structures.place(_robot, _recipe, PLACED_CELL).ok, "test setup: a station is placed")
	return _structures.structure_at(PLACED_CELL)


func _preview_material() -> Material:
	var preview: Node3D = _base.get_preview()
	if preview == null:
		return null
	var meshes: Array[Node] = preview.find_children("*", "MeshInstance3D", true, false)
	return (meshes[0] as MeshInstance3D).material_override


func test_r_009_33_starts_near_robot() -> void:
	var screen: PlacementScreen = _open_place()
	assert_eq(screen.get_mode(), PlacementScreen.Mode.PLACE, "a recipe opens PLACE")
	var cell: Vector2i = screen.get_cell()
	assert_ne(cell, ROBOT_CELL, "not under the robot")
	assert_lte((cell - ROBOT_CELL).length_squared(), 2, "next to it")
	assert_true(screen.is_cell_valid(), "on a valid cell")
	assert_true(_base.is_grid_visible(), "the grid is shown")


func test_r_009_33_preview_snapped_to_cell() -> void:
	var screen: PlacementScreen = _open_place()
	screen.select_cell(TARGET_CELL)
	var preview: Node3D = _base.get_preview()
	assert_not_null(preview, "a preview is shown")
	if preview != null:
		assert_eq(preview.global_position, _world_of(TARGET_CELL), "on the centre of the cell")


func test_r_009_34_valid_green_invalid_red() -> void:
	var screen: PlacementScreen = _open_place()
	screen.select_cell(TARGET_CELL)
	assert_same(_preview_material(), BaseZone.PREVIEW_VALID, "green on a free cell")
	screen.select_cell(_grid.reserved_cells[0])
	assert_false(screen.is_cell_valid(), "a reserved cell is invalid")
	assert_same(_preview_material(), BaseZone.PREVIEW_INVALID, "red on a reserved cell")
	screen.select_cell(ROBOT_CELL)
	assert_same(_preview_material(), BaseZone.PREVIEW_INVALID, "red on the robot (R-009-58)")


func test_r_009_35_confirm_places_and_closes() -> void:
	_robot.inventory.add(&"scrap", _cost())
	var screen: PlacementScreen = _open_place()
	screen.select_cell(TARGET_CELL)
	watch_signals(EventBus)
	var result: ActionResult = screen.confirm()
	assert_true(result.ok, "placed")
	assert_ne(_structures.structure_at(TARGET_CELL), "", "on the chosen cell")
	assert_eq(_robot.inventory.count(&"scrap"), 0, "the cost was charged")
	assert_signal_emit_count(EventBus, "structure_built", 1, "once")
	assert_false(_manager.is_open(PlacementScreen.SCREEN_ID), "the screen closed")


func test_r_009_36_invalid_confirm_stays() -> void:
	_robot.inventory.add(&"scrap", _cost())
	var screen: PlacementScreen = _open_place()
	screen.select_cell(_grid.reserved_cells[0])
	var result: ActionResult = screen.confirm()
	assert_false(result.ok, "nothing placed")
	assert_eq(_robot.inventory.count(&"scrap"), _cost(), "nothing charged")
	assert_true(_manager.is_open(PlacementScreen.SCREEN_ID), "still in placement mode")
	assert_eq(screen.get_mode(), PlacementScreen.Mode.PLACE, "same mode")
	var notice: Label = screen.get_node("%Notice") as Label
	assert_true(notice.visible, "the reason is shown")
	assert_eq(notice.text, String(BaseStructures.ERR_INVALID_PLACEMENT), "as a key")


func test_r_009_37_cancel_charges_nothing() -> void:
	_robot.inventory.add(&"scrap", _cost())
	var screen: PlacementScreen = _open_place()
	screen.select_cell(TARGET_CELL)
	(screen.get_node("%CancelButton") as Button).pressed.emit()
	assert_false(_manager.is_open(PlacementScreen.SCREEN_ID), "closed")
	assert_eq(_robot.inventory.count(&"scrap"), _cost(), "nothing charged")
	assert_eq(_structures.to_data().size(), 0, "nothing placed")
	assert_null(_base.get_preview(), "no preview left")
	assert_false(_base.is_grid_visible(), "no grid left")


func test_r_009_40_texts_are_keys() -> void:
	var screen: PlacementScreen = _open_place()
	var texts: Dictionary[String, StringName] = {
		"%ConfirmButton": &"PLACEMENT_CONFIRM",
		"%CancelButton": &"PLACEMENT_CANCEL",
		"%Hint": &"PLACEMENT_HINT_PLACE",
	}
	for path: String in texts:
		var control: Control = screen.get_node(path) as Control
		var text: String = control.get(&"text")
		assert_eq(text, String(texts[path]), "%s is a key" % path)
		assert_ne(control.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "%s is translated" % path)
	var keys: Array[StringName] = [
		&"PLACEMENT_CONFIRM",
		&"PLACEMENT_CANCEL",
		&"PLACEMENT_HINT_PLACE",
		&"PLACEMENT_HINT_EDIT",
		&"ERR_INVALID_PLACEMENT",
	]
	for locale: String in SUPPORTED_LOCALES:
		for key: StringName in keys:
			var found: String = ""
			for translation: Translation in TranslationServer.find_translations(locale, true):
				found = translation.get_message(key)
				if not found.is_empty():
					break
			assert_ne(found, "", "%s has a text in %s" % [key, locale])


func test_r_009_40_confirm_action_confirms() -> void:
	_robot.inventory.add(&"scrap", _cost())
	var screen: PlacementScreen = _open_place()
	screen.select_cell(TARGET_CELL)
	_send_action(&"confirm", true)
	await wait_process_frames(INPUT_FRAMES)
	assert_ne(_structures.structure_at(TARGET_CELL), "", "Enter placed it")
	assert_false(_manager.is_open(PlacementScreen.SCREEN_ID), "and closed the screen")


func test_r_009_60_tap_structure_picks_it() -> void:
	var uid: String = _place_one()
	var screen: PlacementScreen = _open_edit()
	assert_eq(screen.get_mode(), PlacementScreen.Mode.EDIT_PICK, "no recipe opens edit mode")
	assert_true((screen.get_node("%ConfirmButton") as Button).disabled, "nothing to confirm yet")
	screen.select_cell(PLACED_CELL)
	assert_eq(screen.get_mode(), PlacementScreen.Mode.MOVE, "picked")
	assert_eq(screen.get_cell(), PLACED_CELL, "the preview starts on its own cell")
	assert_eq(_structures.structure_at(PLACED_CELL), uid, "it has not moved yet")


func test_r_009_60_tap_empty_cell_picks_nothing() -> void:
	_place_one()
	var screen: PlacementScreen = _open_edit()
	screen.select_cell(TARGET_CELL)
	assert_eq(screen.get_mode(), PlacementScreen.Mode.EDIT_PICK, "nothing there to pick")
	var bench: Node3D = _base.get_node("%RepairBench") as Node3D
	var bench_cell: Vector2i = _structures.cell_at(bench.global_position)
	screen.select_cell(bench_cell)
	assert_eq(screen.get_mode(), PlacementScreen.Mode.EDIT_PICK, "the bench cannot be picked")


func test_r_009_43_move_at_no_cost() -> void:
	var uid: String = _place_one()
	_robot.inventory.add(&"scrap", 2)
	var screen: PlacementScreen = _open_edit()
	screen.select_cell(PLACED_CELL)
	screen.select_cell(TARGET_CELL)
	assert_true(screen.confirm().ok, "moved")
	assert_eq(_structures.get_cell(uid), TARGET_CELL, "on the new cell")
	assert_eq(_structures.structure_at(PLACED_CELL), "", "the old cell is free")
	assert_eq(_robot.inventory.count(&"scrap"), 2, "at no cost")
	assert_eq(screen.get_mode(), PlacementScreen.Mode.EDIT_PICK, "back to edit mode")
	assert_true(_manager.is_open(PlacementScreen.SCREEN_ID), "still editing")


func test_r_009_44_cancel_move_keeps_cells_and_uid() -> void:
	var uid: String = _place_one()
	var before: Array[Dictionary] = _structures.to_data()
	var screen: PlacementScreen = _open_edit()
	screen.select_cell(PLACED_CELL)
	screen.select_cell(TARGET_CELL)
	screen.cancel()
	assert_eq(screen.get_mode(), PlacementScreen.Mode.EDIT_PICK, "back to edit mode")
	assert_eq(_structures.to_data(), before, "same uid on the same cell")
	assert_eq(_structures.structure_at(PLACED_CELL), uid, "unchanged")
	assert_null(_base.get_preview(), "no preview in edit mode")


func test_r_009_50_reenabled_on_close() -> void:
	_place_one()
	var station: Node = _base.get_structures_root().get_child(0)
	var interactable: InteractableComponent = station.get_node("%Interactable") as InteractableComponent
	_open_edit()
	assert_false(interactable.enabled, "off while editing")
	_manager.close_all()
	assert_true(interactable.enabled, "back on when the screen closes")


func test_r_009_55_tap_moves_preview() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	add_child_autofree(camera)
	camera.global_position = Vector3(10.0, 14.0, 10.0)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var screen: PlacementScreen = _open_place()
	var target: Vector3 = _world_of(TARGET_CELL)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(target)
	screen._gui_input(click)
	assert_eq(screen.get_cell(), TARGET_CELL, "the tapped cell")
	click.position = camera.unproject_position(_base.to_global(Vector3(9.5, 0.0, 9.5)))
	screen._gui_input(click)
	assert_eq(screen.get_cell(), TARGET_CELL, "outside the area the preview stays")


func test_r_009_56_confirm_and_cancel_buttons() -> void:
	_robot.inventory.add(&"scrap", _cost())
	var screen: PlacementScreen = _open_place()
	screen.select_cell(TARGET_CELL)
	(screen.get_node("%ConfirmButton") as Button).pressed.emit()
	assert_ne(_structures.structure_at(TARGET_CELL), "", "Confirm places")
	var edit: PlacementScreen = _open_edit()
	(edit.get_node("%CancelButton") as Button).pressed.emit()
	assert_false(_manager.is_open(PlacementScreen.SCREEN_ID), "Cancel leaves edit mode")


func test_r_009_56_pause_cancels() -> void:
	_robot.inventory.add(&"scrap", _cost())
	_open_place()
	_send_action(&"pause", true)
	await wait_process_frames(INPUT_FRAMES)
	assert_false(_manager.is_open(PlacementScreen.SCREEN_ID), "Escape cancels placement")
	assert_eq(_robot.inventory.count(&"scrap"), _cost(), "nothing charged")


func test_r_009_56_pause_in_move_back_to_edit() -> void:
	var uid: String = _place_one()
	var screen: PlacementScreen = _open_edit()
	screen.select_cell(PLACED_CELL)
	screen.select_cell(TARGET_CELL)
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(_manager.is_open(PlacementScreen.SCREEN_ID), "back cancels the move only")
	assert_eq(screen.get_mode(), PlacementScreen.Mode.EDIT_PICK, "back in edit mode")
	assert_eq(_structures.get_cell(uid), PLACED_CELL, "the structure stayed")
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(_manager.is_open(PlacementScreen.SCREEN_ID), "back again leaves edit mode")
