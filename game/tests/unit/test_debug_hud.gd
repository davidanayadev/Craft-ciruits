extends GutTest
## DebugHud XP (spec 007, R-007-22): the debug overlay shows the XP of the
## player it is bound to and follows xp_changed. The amounts are test inputs.
## Spec 009: "Fill base" fills every free cell through BaseStructures.place,
## paying like a player (tool for R-009-22).
## Spec 010: it shows the world seed and a "New world" button (R-010-65), and
## "Fill base" saves once after placing, not once per structure (plan D17).

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


func after_each() -> void:
	SaveTestSupport.reset()


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


func test_r_010_65_shows_seed_and_new_world() -> void:
	var seed_label: Label = _debug_hud.get_node("%SeedLabel") as Label
	var new_world: Button = _debug_hud.get_node("%NewWorldButton") as Button
	assert_not_null(seed_label, "%SeedLabel exists")
	assert_not_null(new_world, "%NewWorldButton exists")
	if seed_label == null or new_world == null:
		return
	var big_seed: int = -8213372036854775807
	_debug_hud.show_world_seed(big_seed)
	assert_string_contains(seed_label.text, str(big_seed), "the seed is shown whole")
	watch_signals(_debug_hud)
	new_world.pressed.emit()
	assert_signal_emit_count(_debug_hud, "new_world_requested", 1, "pressing it is one request")


func test_r_010_17_fill_base_saves_once() -> void:
	var store: MemorySaveStore = SaveTestSupport.start_world()
	var saved_reasons: Array[StringName] = []
	var record: Callable = func(reason: StringName) -> void: saved_reasons.append(reason)
	EventBus.game_saved.connect(record)
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
	var writes_before: int = store.write_count
	_debug_hud.fill_base()
	assert_gt(structures.to_data().size(), 1, "several structures were placed")
	assert_eq(store.write_count, writes_before, "nothing is written while it places or inside the call")
	await wait_process_frames(2)
	EventBus.game_saved.disconnect(record)
	assert_eq(store.write_count, writes_before + 1, "one save after it, not one per structure")
	assert_eq(saved_reasons, [SaveManager.REASON_STRUCTURE_BUILT], "with the reason of a build")


func test_r_010_17_fill_base_releases_the_hold() -> void:
	var store: MemorySaveStore = SaveTestSupport.start_world()
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
	_debug_hud.fill_base()
	await wait_process_frames(2)
	var writes_after_fill: int = store.write_count
	SaveManager.request_save(SaveManager.REASON_CLOSE)
	await wait_process_frames(2)
	assert_eq(store.write_count, writes_after_fill + 1, "saves work again after Fill base")
