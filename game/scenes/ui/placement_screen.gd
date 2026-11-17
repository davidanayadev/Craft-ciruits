class_name PlacementScreen
extends UIScreen
## Placement and edit mode of the base (spec 009), one UIManager screen with
## three modes: PLACE a new structure, EDIT_PICK (edit mode, nothing picked)
## and MOVE a picked structure. Being a UIManager screen blocks the robot
## without pausing the game (R-009-57) and a death closes it (R-009-53).
## A tap or click on the floor moves the preview to that cell (R-009-55), or
## picks the structure on it in EDIT_PICK (R-009-60); "Confirm" / Enter and
## "Cancel" / Escape / back do what their names say in each mode (R-009-56).
## It only asks BaseStructures, which decides and changes the state.

const SCREEN_ID := &"placement"
## The Robot that places or moves.
const CONTEXT_PLAYER := &"player"
## The BaseStructures of the world; its base must be loaded.
const CONTEXT_BASE := &"base"
## The RecipeData to place: present → PLACE; absent → EDIT_PICK.
const CONTEXT_RECIPE := &"recipe"
const HINT_PLACE := &"PLACEMENT_HINT_PLACE"
const HINT_EDIT := &"PLACEMENT_HINT_EDIT"

enum Mode { PLACE, EDIT_PICK, MOVE }

var _player: Robot = null
var _structures: BaseStructures = null
var _recipe: RecipeData = null
var _mode: Mode = Mode.EDIT_PICK
var _structure: StructureData = null
var _cell: Vector2i = BuildGrid.NO_CELL
var _moving_uid: String = ""

@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _hint: Label = %Hint
@onready var _notice: Label = %Notice


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(cancel)


## Missing player or an unloaded base → push_error and the screen asks to close.
func setup(context: Dictionary) -> void:
	_player = context.get(CONTEXT_PLAYER) as Robot
	_structures = context.get(CONTEXT_BASE) as BaseStructures
	_recipe = context.get(CONTEXT_RECIPE) as RecipeData
	if _player == null or _structures == null or not _structures.is_bound():
		push_error("PlacementScreen: the context needs a player and a loaded base.")
		close_requested.emit.call_deferred()
		return
	_structures.set_interactions_enabled(false)
	_structures.get_base().set_grid_visible(true)
	if _recipe != null and _recipe.result_structure != null:
		_structure = _recipe.result_structure
		_cell = _structures.nearest_free_cell(_structure, _player.global_position)
		_set_mode(Mode.PLACE)
	else:
		_set_mode(Mode.EDIT_PICK)


func get_mode() -> Mode:
	return _mode


func get_cell() -> Vector2i:
	return _cell


func is_cell_valid() -> bool:
	return _structure != null and _structures.can_place(_structure, _cell, _moving_uid)


## Pointer input ends here. Outside the area nothing changes.
func select_cell(cell: Vector2i) -> void:
	if not _structures.is_in_area(cell):
		return
	if _mode == Mode.EDIT_PICK:
		_pick(cell)
		return
	_cell = cell
	_update_preview()


## Invalid cell → nothing changes and the mode stays (R-009-36). A placed
## structure closes the screen; a moved one goes back to EDIT_PICK. In
## EDIT_PICK nothing is picked, so there is nothing to confirm.
func confirm() -> ActionResult:
	var result: ActionResult = ActionResult.failure(BaseStructures.ERR_INVALID_PLACEMENT)
	if _mode == Mode.EDIT_PICK:
		return result
	match _mode:
		Mode.PLACE:
			result = _structures.place(_player, _recipe, _cell)
			if result.ok:
				close_requested.emit()
		Mode.MOVE:
			result = _structures.move(_player, _moving_uid, _cell)
			if result.ok:
				_set_mode(Mode.EDIT_PICK)
	_show_notice(&"" if result.ok else result.error_key)
	return result


## In MOVE the structure stays where it was (R-009-44) and edit mode goes
## on; otherwise the screen closes, having charged nothing (R-009-37).
func cancel() -> void:
	if _mode == Mode.MOVE:
		_set_mode(Mode.EDIT_PICK)
		return
	close_requested.emit()


func handle_back() -> bool:
	if _mode == Mode.MOVE:
		cancel()
		return true
	return false


## Whatever closed it: no preview, no grid, stations back on (R-009-50).
func on_closed() -> void:
	if _structures == null:
		return
	_structures.set_interactions_enabled(true)
	var base: BaseZone = _structures.get_base()
	if base != null:
		base.hide_preview()
		base.set_grid_visible(false)


func _gui_input(event: InputEvent) -> void:
	# Touches arrive as emulated mouse buttons (plan 009 §5.1 point 6).
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var cell: Vector2i = _cell_under(click.position)
	if cell != BuildGrid.NO_CELL:
		select_cell(cell)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"confirm"):
		confirm()
		get_viewport().set_input_as_handled()


## The cell of the base floor under a screen point; NO_CELL when the ray
## misses the floor.
func _cell_under(screen_point: Vector2) -> Vector2i:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var base: BaseZone = _structures.get_base()
	if camera == null or base == null:
		return BuildGrid.NO_CELL
	var floor_plane: Plane = Plane(Vector3.UP, base.get_floor_height())
	var hit: Variant = floor_plane.intersects_ray(
		camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point)
	)
	if hit == null:
		return BuildGrid.NO_CELL
	var point: Vector3 = hit
	return _structures.cell_at(point)


func _pick(cell: Vector2i) -> void:
	var uid: String = _structures.structure_at(cell)
	if uid.is_empty():
		return
	_moving_uid = uid
	_structure = _structures.get_structure(uid)
	_cell = _structures.get_cell(uid)
	_set_mode(Mode.MOVE)


func _set_mode(mode: Mode) -> void:
	_mode = mode
	if mode == Mode.EDIT_PICK:
		_structure = null
		_moving_uid = ""
		_cell = BuildGrid.NO_CELL
	_hint.text = String(HINT_EDIT if mode != Mode.PLACE else HINT_PLACE)
	_confirm_button.disabled = mode == Mode.EDIT_PICK
	_show_notice(&"")
	_update_preview()


func _update_preview() -> void:
	var base: BaseZone = _structures.get_base()
	if base == null:
		return
	if _structure == null or _cell == BuildGrid.NO_CELL:
		base.hide_preview()
		return
	var world: Vector3 = _structures.cell_to_world(_structure, _cell)
	base.show_preview(_structure, base.to_local(world), is_cell_valid())


func _show_notice(key: StringName) -> void:
	_notice.text = String(key)
	_notice.visible = not key.is_empty()


func _on_confirm_pressed() -> void:
	confirm()
