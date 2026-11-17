extends GutTest
## DebugHud XP (spec 007, R-007-22): the debug overlay shows the XP of the
## player it is bound to and follows xp_changed. The amounts are test inputs.
## Spec 009: "Fill base" fills every free cell through BaseStructures.place,
## paying like a player (tool for R-009-22).

const DEBUG_HUD_SCENE := preload("res://scenes/ui/debug_hud.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")

var _debug_hud: DebugHud
var _robot: Robot
var _xp_label: Label


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_debug_hud = DEBUG_HUD_SCENE.instantiate() as DebugHud
	add_child_autofree(_debug_hud)
	_xp_label = _debug_hud.get_node("%XpLabel") as Label


func test_r_007_22_shows_xp() -> void:
	assert_not_null(_xp_label, "%XpLabel exists")
	if _xp_label == null:
		return
	_debug_hud.bind(_robot)
	assert_eq(_xp_label.text, "XP: 0", "the XP it was bound to")
	_robot.experience.add_xp(2)
	assert_eq(_xp_label.text, "XP: 2", "it follows xp_changed")
	_robot.experience.add_xp(3)
	assert_eq(_xp_label.text, "XP: 5", "with the total, not the last gain")


func test_r_007_22_shows_current_xp_when_bound() -> void:
	_robot.experience.add_xp(7)
	_debug_hud.bind(_robot)
	assert_eq(_xp_label.text, "XP: 7", "XP earned before binding is shown")


func test_r_007_22_xp_below_fps() -> void:
	var fps_label: Label = _debug_hud.get_node("%FpsLabel") as Label
	assert_gte(_xp_label.offset_top, fps_label.offset_bottom, "the XP sits under the FPS")


func test_r_009_22_fill_base_places_on_every_free_cell() -> void:
	var grid: BuildGridData = load("res://resources/config/base_grid.tres") as BuildGridData
	var structures: BaseStructures = BaseStructures.new()
	structures.grid_config = grid
	add_child_autofree(structures)
	var base: BaseZone = (load("res://scenes/base/base.tscn") as PackedScene).instantiate() as BaseZone
	add_child_autofree(base)
	structures.bind_base(base)
	_robot.set_physics_process(false)
	_robot.global_position = base.get_spawn_position()
	_debug_hud.bind(_robot)
	_debug_hud.bind_base_structures(structures)
	(_debug_hud.get_node("%FillBaseButton") as Button).pressed.emit()
	var free_cells: int = grid.area_size_cells.x * grid.area_size_cells.y - grid.reserved_cells.size()
	assert_eq(structures.to_data().size(), free_cells, "a structure on every free cell")
	assert_false(structures.fits_anywhere(DataRegistry.get_recipe(&"charging_station").result_structure), "full")
	assert_true(_robot.inventory.is_empty(), "every cost was paid")
