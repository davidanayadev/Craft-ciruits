extends GutTest
## BuildFlow (spec 009): the bench opens the bench screen (spec 011, which
## replaced the build screen) for the local player (R-009-64), a build request opens placement without charging (R-009-65),
## and the "Edit base" button exists only in the base and toggles edit mode
## (R-009-59), never on top of another screen.

const UI_MANAGER_SCENE := preload("res://scenes/ui/ui_manager.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const BASE_SCENE := preload("res://scenes/base/base.tscn")
const GREEN_ZONE_SCENE := preload("res://scenes/farm_zone/farm_zone_green.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const SCREENS_PATH := "res://resources/ui/screens.tres"
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const RECIPE_PATH := "res://resources/recipes/charging_station.tres"

var _manager: UIManager
var _hud: Hud
var _robot: Robot
var _structures: BaseStructures
var _loader: ZoneLoader
var _flow: BuildFlow
var _base: BaseZone


func before_each() -> void:
	_manager = UI_MANAGER_SCENE.instantiate() as UIManager
	_manager.catalog = load(SCREENS_PATH) as UIScreenCatalog
	add_child_autofree(_manager)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child_autofree(_hud)
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_structures = BaseStructures.new()
	_structures.grid_config = load(BASE_GRID_PATH) as BuildGridData
	add_child_autofree(_structures)
	# Only its zone_loaded signal is used: the zones are loaded by hand.
	_loader = ZoneLoader.new()
	add_child_autofree(_loader)
	_flow = BuildFlow.new()
	_flow.ui_manager = _manager
	_flow.base_structures = _structures
	add_child_autofree(_flow)
	_flow.bind(_robot, _hud, _loader)
	_base = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(_base)
	_structures.bind_base(_base)
	_loader.zone_loaded.emit(_base)


func _edit_button() -> Button:
	return _hud.get_node("%EditBaseButton") as Button


func _use_bench(user: Node3D) -> void:
	(_base.get_node("%RepairBench").get_node("Interactable") as InteractableComponent).interact(user)


func test_r_009_64_bench_opens_build_screen() -> void:
	_use_bench(_robot)
	assert_true(_manager.is_open(BenchScreen.SCREEN_ID), "the bench screen opens")


func test_r_009_64_other_player_opens_nothing() -> void:
	var other: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(other)
	other.set_physics_process(false)
	_use_bench(other)
	assert_false(_manager.is_modal_open(), "no screen for another player on this client")


func test_r_009_65_build_requested_opens_placement() -> void:
	var recipe: RecipeData = load(RECIPE_PATH) as RecipeData
	_robot.inventory.add(&"scrap", 4)
	_robot.request_build(recipe)
	assert_true(_manager.is_open(PlacementScreen.SCREEN_ID), "placement opens")
	assert_eq(_robot.inventory.count(&"scrap"), 4, "nothing charged yet")


func test_r_009_65_build_from_screen_replaces_it() -> void:
	_robot.inventory.add(&"scrap", 4)
	_use_bench(_robot)
	var screen: Node = null
	for child: Node in _manager.get_children():
		if child is BenchScreen:
			screen = child
	assert_not_null(screen, "the bench screen is open")
	if screen == null:
		return
	var entry: Node = screen.get_node("%BuildSection").get_node("charging_station")
	(entry.get_node("ActionButton") as Button).pressed.emit()
	assert_false(_manager.is_open(BenchScreen.SCREEN_ID), "the bench screen closed")
	assert_true(_manager.is_open(PlacementScreen.SCREEN_ID), "placement is the only screen")


func test_r_009_59_edit_button_only_in_base() -> void:
	assert_true(_edit_button().visible, "shown in the base")
	var farm: FarmZone = GREEN_ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(farm)
	_loader.zone_loaded.emit(farm)
	assert_false(_edit_button().visible, "hidden in a farm zone")
	_loader.zone_loaded.emit(_base)
	assert_true(_edit_button().visible, "back in the base")


func test_r_009_59_edit_button_toggles() -> void:
	_edit_button().pressed.emit()
	assert_true(_manager.is_open(PlacementScreen.SCREEN_ID), "edit mode opens")
	_edit_button().pressed.emit()
	assert_false(_manager.is_modal_open(), "pressed again it closes")


func test_r_009_59_edit_button_not_over_another_screen() -> void:
	_use_bench(_robot)
	_edit_button().pressed.emit()
	assert_false(_manager.is_open(PlacementScreen.SCREEN_ID), "no placement over the bench screen")
	assert_true(_manager.is_open(BenchScreen.SCREEN_ID), "the bench screen stays")


## Spec 012 (R-012-07): the generator and the chest are built like the
## station: from the bench, placed in placement mode, paid on confirming,
## announced with structure_built (which the save listens to, R-010-42).
func test_r_012_07_build_generator_and_chest() -> void:
	for path: String in ["res://resources/recipes/wind_generator.tres", "res://resources/recipes/storage_chest.tres"]:
		var recipe: RecipeData = load(path) as RecipeData
		var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
		for item_id: StringName in cost:
			assert_true(_robot.inventory.add(item_id, cost[item_id]).ok, "test setup: %s" % item_id)
		_use_bench(_robot)
		var bench: Node = null
		for child: Node in _manager.get_children():
			if child is BenchScreen and not child.is_queued_for_deletion():
				bench = child
		assert_not_null(bench, "the bench screen is open")
		if bench == null:
			return
		var entry: Node = bench.get_node("%BuildSection").get_node(String(recipe.id))
		(entry.get_node("ActionButton") as Button).pressed.emit()
		assert_true(_manager.is_open(PlacementScreen.SCREEN_ID), "%s: placement opens" % recipe.id)
		assert_eq(_robot.inventory.count(&"scrap"), cost[&"scrap"], "%s: nothing charged yet" % recipe.id)
		var placement: PlacementScreen = null
		for child: Node in _manager.get_children():
			if child is PlacementScreen and not child.is_queued_for_deletion():
				placement = child
		var cell: Vector2i = Vector2i(1, 2) if recipe.id == &"wind_generator" else Vector2i(0, 5)
		placement.select_cell(cell)
		watch_signals(EventBus)
		assert_true(placement.confirm().ok, "%s: placed" % recipe.id)
		assert_eq(_robot.inventory.count(&"scrap"), 0, "%s: paid on confirming" % recipe.id)
		assert_signal_emitted(EventBus, "structure_built", "%s: announced" % recipe.id)
		assert_ne(_structures.structure_at(cell), "", "%s: on its cell" % recipe.id)
		_manager.close_all()
