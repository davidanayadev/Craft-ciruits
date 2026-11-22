extends GutTest
## StructureUseFlow (spec 012): a chest used by the local player opens the
## container screen on its contents and the player's inventory (R-012-27),
## with the chest header of spec 013 (R-013-12), and
## closing it after a change announces chest_closed so the World saves
## (R-012-44, plan D15); a generator used by the local player asks
## BaseStructures to collect, and an empty one shows the time left (R-012-20).
## Another player's uses open nothing on this client. Times come from a
## FakeTimeService (plan D21).

const UI_MANAGER_SCENE := preload("res://scenes/ui/ui_manager.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const BASE_SCENE := preload("res://scenes/base/base.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const SCREENS_PATH := "res://resources/ui/screens.tres"
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const GENERATOR_RECIPE_PATH := "res://resources/recipes/wind_generator.tres"
const CHEST_RECIPE_PATH := "res://resources/recipes/storage_chest.tres"
const GENERATOR_CELL := Vector2i(1, 2)
const CHEST_CELL := Vector2i(0, 5)
const START := 1_700_000_000

var _manager: UIManager
var _hud: Hud
var _robot: Robot
var _structures: BaseStructures
var _flow: StructureUseFlow
var _base: BaseZone
var _clock: FakeTimeService


func before_each() -> void:
	_manager = UI_MANAGER_SCENE.instantiate() as UIManager
	_manager.catalog = load(SCREENS_PATH) as UIScreenCatalog
	add_child_autofree(_manager)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child_autofree(_hud)
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_hud.bind(_robot)
	_clock = FakeTimeService.new()
	_clock.now = START
	_structures = BaseStructures.new()
	_structures.grid_config = load(BASE_GRID_PATH) as BuildGridData
	add_child_autofree(_structures)
	_structures.time_service = _clock
	_base = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(_base)
	_robot.global_position = _base.get_spawn_position()
	_structures.bind_base(_base)
	_flow = StructureUseFlow.new()
	_flow.ui_manager = _manager
	_flow.base_structures = _structures
	add_child_autofree(_flow)
	_flow.bind(_robot, _hud)


func _build(path: String, cell: Vector2i) -> String:
	var recipe: RecipeData = load(path) as RecipeData
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	for item_id: StringName in cost:
		assert_true(_robot.inventory.add(item_id, cost[item_id]).ok, "test setup: %s" % item_id)
	assert_true(_structures.place(_robot, recipe, cell).ok, "test setup: %s placed" % recipe.id)
	return _structures.structure_at(cell)


func _container_screen() -> ContainerScreen:
	for child: Node in _manager.get_children():
		var screen: ContainerScreen = child as ContainerScreen
		if screen != null and not screen.is_queued_for_deletion():
			return screen
	return null


func _message() -> Label:
	return _hud.get_node("%MessageLabel") as Label


func test_r_012_27_chest_opens_container_screen() -> void:
	var uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELL)
	_structures.structure_used.emit(uid, _robot)
	var screen: ContainerScreen = _container_screen()
	assert_not_null(screen, "the container screen is open")
	if screen == null:
		return
	var title: Label = screen.get_node("%Title") as Label
	assert_eq(title.text, String(ContainerScreen.CHEST_TITLE_KEY), "titled as a chest")
	var contents: InventoryComponent = _structures.get_chest_contents(uid)
	var header: Label = screen.get_node("%ContainerHeader") as Label
	assert_eq(header.text, tr(&"CONTAINER_HEADER_CHEST") % [0, contents.get_slot_count()], "a chest header (R-013-12)")
	var grid: InventoryGrid = screen.get_node("%ContainerGrid") as InventoryGrid
	assert_eq(grid.get_child_count(), contents.get_slot_count(), "the chest's slots")
	assert_true(_robot.inventory.add(&"scrap", 2).ok)
	(screen.get_node("%PlayerGrid") as InventoryGrid).slot_pressed.emit(0)
	(screen.get_node("%MoveButton") as Button).pressed.emit()
	assert_eq(_structures.get_chest_contents(uid).count(&"scrap"), 2, "the screen works on the chest's own contents")


func test_r_012_27_other_player_opens_nothing() -> void:
	var uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELL)
	var stranger: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(stranger)
	stranger.set_physics_process(false)
	_structures.structure_used.emit(uid, stranger)
	assert_false(_manager.is_modal_open(), "another player's use opens nothing here")


func test_r_012_44_chest_closed_after_change_announced() -> void:
	var uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELL)
	_structures.structure_used.emit(uid, _robot)
	assert_true(_structures.get_chest_contents(uid).add(&"iron", 1).ok, "the contents change")
	watch_signals(EventBus)
	_manager.close_top()
	assert_signal_emit_count(EventBus, "chest_closed", 1, "closing after a change is announced once")
	assert_signal_emitted_with_parameters(EventBus, "chest_closed", [uid, _robot.player_uid])


func test_r_012_44_chest_closed_unchanged_not_announced() -> void:
	var uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELL)
	_structures.structure_used.emit(uid, _robot)
	watch_signals(EventBus)
	_manager.close_all()
	assert_signal_not_emitted(EventBus, "chest_closed", "nothing changed, nothing to save")
	assert_true(_structures.get_chest_contents(uid).add(&"iron", 1).ok, "a later change, screen closed")
	assert_signal_not_emitted(EventBus, "chest_closed", "is not watched any more")


func test_r_012_44_close_all_after_change_announced() -> void:
	var uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELL)
	_structures.structure_used.emit(uid, _robot)
	assert_true(_structures.get_chest_contents(uid).add(&"iron", 1).ok)
	watch_signals(EventBus)
	_manager.close_all()
	assert_signal_emit_count(EventBus, "chest_closed", 1, "a travel or a death closing it also counts")


func test_r_012_20_generator_collects() -> void:
	var uid: String = _build(GENERATOR_RECIPE_PATH, GENERATOR_CELL)
	var config: WindGeneratorData = (load(GENERATOR_RECIPE_PATH) as RecipeData).result_structure as WindGeneratorData
	_clock.now = START + config.seconds_per_battery
	watch_signals(EventBus)
	_structures.structure_used.emit(uid, _robot)
	assert_eq(_robot.inventory.count(config.battery_item.id), 1, "the battery is in the inventory")
	assert_signal_emit_count(EventBus, "batteries_collected", 1)
	assert_false(_manager.is_modal_open(), "no screen for the generator")


func test_r_012_20_empty_generator_shows_time_left() -> void:
	var uid: String = _build(GENERATOR_RECIPE_PATH, GENERATOR_CELL)
	var config: WindGeneratorData = (load(GENERATOR_RECIPE_PATH) as RecipeData).result_structure as WindGeneratorData
	_clock.now = START + 60
	_structures.structure_used.emit(uid, _robot)
	assert_true(_message().visible, "a notice shows")
	var expected: String = tr(&"MSG_GENERATOR_EMPTY") % WindGenerator.format_time_left(config.seconds_per_battery - 60)
	assert_eq(_message().text, expected, "with the time left")


func test_r_012_20_full_inventory_shows_full_notice() -> void:
	var uid: String = _build(GENERATOR_RECIPE_PATH, GENERATOR_CELL)
	var config: WindGeneratorData = (load(GENERATOR_RECIPE_PATH) as RecipeData).result_structure as WindGeneratorData
	var cables: ItemData = DataRegistry.get_item(&"cables")
	assert_true(_robot.inventory.add(&"cables", cables.stack_max * _robot.inventory.get_slot_count()).ok)
	_clock.now = START + config.seconds_per_battery
	_structures.structure_used.emit(uid, _robot)
	assert_eq(_message().text, String(InventoryComponent.MSG_INVENTORY_FULL), "the inventory full notice (R-005-20)")
	assert_eq(_structures.seconds_to_next_battery(uid), config.seconds_per_battery, "nothing collected")
