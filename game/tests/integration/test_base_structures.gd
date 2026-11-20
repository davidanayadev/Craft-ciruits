extends GutTest
## BaseStructures (spec 009): the placed structures are world state outside
## any player (R-009-30) with a uid and a (zone_id, cell) position (R-009-29);
## place and move take the requesting player and return an ActionResult
## (R-009-32); placing charges the recipe and emits structure_built once
## (R-009-35), and a refused placement charges nothing (R-009-36, R-009-39);
## only with the base loaded (R-009-41); no limit but space (R-009-42); "fits
## anywhere" (R-009-38); stations off while placing (R-009-50); the cells of a
## robot are invalid (R-009-58); the bench and the exit point are never
## structures (R-009-20, R-009-60).
## Spec 010: saved as BuildGrid.to_data() (R-010-31), loading skips unknown
## structures (R-010-11) and announces nothing, moving emits structure_moved.

const BASE_SCENE := preload("res://scenes/base/base.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const RECIPE_PATH := "res://resources/recipes/charging_station.tres"
const NO_CELL := Vector2i(-1, -1)
## Far from the spawn point, the exit point and the bench.
const FREE_CELL := Vector2i(1, 2)
const OTHER_CELL := Vector2i(9, 4)

var _structures: BaseStructures
var _base: BaseZone
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
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_robot.global_position = _base.get_spawn_position()
	_structures.bind_base(_base)


func _give_scrap(quantity: int) -> void:
	assert_true(_robot.inventory.add(&"scrap", quantity).ok, "the robot holds %d scrap" % quantity)


func _cost() -> int:
	return CraftingSystem.cost_of(_recipe)[&"scrap"]


func _place(cell: Vector2i) -> ActionResult:
	return _structures.place(_robot, _recipe, cell)


func _instances() -> Array[Node]:
	return _base.get_structures_root().get_children()


func test_r_009_32_place_returns_result_and_takes_player() -> void:
	_give_scrap(_cost())
	var result: ActionResult = _place(FREE_CELL)
	assert_true(result.ok, "placed")
	assert_eq(_robot.inventory.count(&"scrap"), 0, "the requesting player paid")
	var uid: String = _structures.structure_at(FREE_CELL)
	assert_ne(uid, "", "the cell holds the structure")
	var moved: ActionResult = _structures.move(_robot, uid, OTHER_CELL)
	assert_true(moved.ok, "moved")


func test_r_009_32_null_player_rejected() -> void:
	_give_scrap(_cost())
	var result: ActionResult = _structures.place(null, _recipe, FREE_CELL)
	assert_false(result.ok, "no player, no placement")
	assert_eq(_structures.structure_at(FREE_CELL), "", "nothing placed")
	assert_push_error("player")


func test_r_009_29_uid_and_zone_cell() -> void:
	_give_scrap(_cost() * 2)
	assert_true(_place(FREE_CELL).ok)
	assert_true(_place(OTHER_CELL).ok)
	var data: Array[Dictionary] = _structures.to_data()
	assert_eq(data.size(), 2, "two structures")
	var uids: Array[String] = []
	for entry: Dictionary in data:
		var uid: String = entry["uid"]
		assert_eq(uid.length(), 32, "a generated uid (architecture §10.3)")
		uids.append(uid)
		var zone_id: Array = entry["zone_id"]
		var zone_x: int = zone_id[0]
		var zone_y: int = zone_id[1]
		assert_eq(Vector2i(zone_x, zone_y), _base.data.zone_id, "the base zone")
	assert_ne(uids[0], uids[1], "each structure has its own uid")
	assert_eq(_structures.get_cell(uids[0]), FREE_CELL, "the cell it was placed on")
	assert_same(_structures.get_structure(uids[0]), _recipe.result_structure, "its StructureData")


func test_r_009_35_place_charges_and_emits_once() -> void:
	_give_scrap(_cost() + 3)
	watch_signals(EventBus)
	assert_true(_place(FREE_CELL).ok)
	assert_eq(_robot.inventory.count(&"scrap"), 3, "the cost of BALANCE §5.3 was charged")
	assert_signal_emit_count(EventBus, "structure_built", 1, "once")
	assert_signal_emitted_with_parameters(
		EventBus, "structure_built", [_structures.structure_at(FREE_CELL)]
	)
	var instances: Array[Node] = _instances()
	assert_eq(instances.size(), 1, "the station stands in the base")
	if instances.size() == 1:
		var station: Node3D = instances[0] as Node3D
		assert_true(station is ChargingStation, "a charging station")
		assert_eq(
			station.global_position,
			_structures.cell_to_world(_recipe.result_structure, FREE_CELL),
			"on its cell"
		)


func test_r_009_36_invalid_cell_charges_nothing() -> void:
	_give_scrap(_cost())
	watch_signals(EventBus)
	for cell: Vector2i in [Vector2i(-1, 0), Vector2i(40, 0), _grid.reserved_cells[0]]:
		var result: ActionResult = _place(cell)
		assert_false(result.ok, "%s refused" % cell)
		assert_eq(result.error_key, BaseStructures.ERR_INVALID_PLACEMENT, "%s: invalid placement" % cell)
	assert_eq(_robot.inventory.count(&"scrap"), _cost(), "nothing charged")
	assert_signal_not_emitted(EventBus, "structure_built", "nothing built")
	assert_eq(_instances().size(), 0, "nothing stands")


func test_r_009_39_cannot_pay_changes_nothing() -> void:
	_give_scrap(_cost() - 1)
	watch_signals(EventBus)
	var result: ActionResult = _place(FREE_CELL)
	assert_false(result.ok, "not enough scrap")
	assert_eq(result.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS, "the key BenchScreen shows")
	assert_eq(_robot.inventory.count(&"scrap"), _cost() - 1, "nothing charged")
	assert_eq(_structures.structure_at(FREE_CELL), "", "nothing placed")
	assert_signal_not_emitted(EventBus, "structure_built")


func test_r_009_41_place_refused_without_base() -> void:
	_give_scrap(_cost())
	_structures.unbind_base()
	assert_false(_structures.is_bound(), "no base loaded")
	var result: ActionResult = _place(FREE_CELL)
	assert_false(result.ok, "placement only in the base")
	assert_eq(_robot.inventory.count(&"scrap"), _cost(), "nothing charged")


func test_r_009_42_place_until_full() -> void:
	var free_cells: int = _grid.area_size_cells.x * _grid.area_size_cells.y - _grid.reserved_cells.size()
	_give_scrap(_cost() * free_cells)
	var placed: int = 0
	for y: int in _grid.area_size_cells.y:
		for x: int in _grid.area_size_cells.x:
			if _place(Vector2i(x, y)).ok:
				placed += 1
	assert_eq(placed, free_cells, "a station on every free cell: no limit but space")
	assert_false(_structures.fits_anywhere(_recipe.result_structure), "and then the base is full")


func test_r_009_38_fits_anywhere() -> void:
	assert_true(_structures.fits_anywhere(_recipe.result_structure), "an empty base has room")


func test_r_009_30_survive_unbind_and_rebind() -> void:
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	var uid: String = _structures.structure_at(FREE_CELL)
	_structures.unbind_base()
	_base.free()
	assert_eq(_structures.get_cell(uid), FREE_CELL, "the state outlives the base")
	_base = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(_base)
	_structures.bind_base(_base)
	assert_eq(_instances().size(), 1, "the station is back")
	if _instances().size() == 1:
		assert_eq(
			(_instances()[0] as Node3D).global_position,
			_structures.cell_to_world(_recipe.result_structure, FREE_CELL),
			"on its cell"
		)
	assert_eq(_structures.structure_at(FREE_CELL), uid, "same uid")


func test_r_009_31_load_data_round_trip() -> void:
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	var data: Array = JSON.parse_string(JSON.stringify(_structures.to_data())) as Array
	var restored: BaseStructures = BaseStructures.new()
	restored.grid_config = _grid
	add_child_autofree(restored)
	assert_true(restored.load_data(data).ok, "loads from JSON")
	assert_eq(restored.to_data(), _structures.to_data(), "the same structures on the same cells")


func test_r_009_50_stations_disabled_while_placing() -> void:
	_give_scrap(_cost() * 2)
	assert_true(_place(FREE_CELL).ok)
	_structures.set_interactions_enabled(false)
	assert_true(_place(OTHER_CELL).ok)
	for instance: Node in _instances():
		var interactable: InteractableComponent = instance.get_node("%Interactable") as InteractableComponent
		assert_false(interactable.enabled, "%s is off while placing" % instance.name)
	_structures.set_interactions_enabled(true)
	for instance: Node in _instances():
		var interactable: InteractableComponent = instance.get_node("%Interactable") as InteractableComponent
		assert_true(interactable.enabled, "%s is back on" % instance.name)


func test_r_009_58_robot_cell_invalid() -> void:
	var cell: Vector2i = Vector2i(4, 4)
	var structure: StructureData = _recipe.result_structure
	_robot.global_position = _structures.cell_to_world(structure, cell)
	assert_false(_structures.can_place(structure, cell), "a robot stands there")
	_give_scrap(_cost())
	assert_false(_place(cell).ok, "and place refuses it")
	_robot.global_position = _structures.cell_to_world(structure, OTHER_CELL)
	assert_true(_structures.can_place(structure, cell), "free once the robot moves away")
	assert_gt(_robot.get_footprint_radius(), 0.0, "the robot covers floor")


func test_r_009_20_bench_not_pickable() -> void:
	var bench: Node3D = _base.get_node("%RepairBench") as Node3D
	var cell: Vector2i = _structures.cell_at(bench.global_position)
	assert_eq(_structures.structure_at(cell), "", "the bench is not a placed structure")
	assert_eq(_structures.to_data().size(), 0, "and it is not in the state")


func test_r_009_60_exit_point_not_pickable() -> void:
	var exit: Node3D = _base.get_node("%ExitPoint") as Node3D
	assert_eq(_structures.structure_at(_structures.cell_at(exit.global_position)), "", "not a structure")


func test_r_009_33_nearest_free_cell_to_robot() -> void:
	var structure: StructureData = _recipe.result_structure
	var near: Vector3 = _structures.cell_to_world(structure, Vector2i(6, 6))
	_robot.global_position = _structures.cell_to_world(structure, OTHER_CELL)
	var cell: Vector2i = _structures.nearest_free_cell(structure, near)
	assert_eq(cell, Vector2i(6, 6), "the cell under the point when it is free")
	_robot.global_position = near
	var beside: Vector2i = _structures.nearest_free_cell(structure, near)
	assert_ne(beside, Vector2i(6, 6), "not under a robot")
	assert_ne(beside, NO_CELL, "but next to it")


## Spec 010: save and load (R-010-09, R-010-11, R-010-31).
func _new_loaded_structures() -> BaseStructures:
	var other: BaseStructures = BaseStructures.new()
	other.grid_config = _grid
	add_child_autofree(other)
	return other


func test_r_010_09_save_key() -> void:
	assert_eq(BaseStructures.SAVE_KEY, &"structures", "constant")
	assert_eq(_structures.get_save_key(), &"structures", "method")


func test_r_010_31_saved_as_spec_009() -> void:
	assert_eq(_structures.to_save_data(), {"placed": []}, "nothing placed")
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	var expected: Dictionary = {"placed": _structures.to_data()}
	assert_eq(_structures.to_save_data(), expected, "the BuildGrid data under placed")


func test_r_010_09_round_trip_structures() -> void:
	_give_scrap(_cost() * 2)
	assert_true(_place(FREE_CELL).ok)
	assert_true(_place(OTHER_CELL).ok)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_structures.to_save_data())) as Dictionary
	var restored: BaseStructures = _new_loaded_structures()
	restored.from_save_data(saved)
	assert_eq(restored.to_save_data(), _structures.to_save_data(), "the same structures on the same cells")


func test_r_010_09_load_announces_nothing() -> void:
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	var saved: Dictionary = _structures.to_save_data()
	var restored: BaseStructures = _new_loaded_structures()
	watch_signals(EventBus)
	restored.from_save_data(saved)
	assert_signal_not_emitted(EventBus, "structure_built", "loading builds nothing")
	assert_signal_not_emitted(EventBus, "structure_moved", "nor moves anything")


func test_r_010_11_unknown_structure_skipped() -> void:
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	var saved: Dictionary = _structures.to_save_data()
	var placed: Array = saved["placed"]
	var good: Dictionary = placed[0]
	var ghost: Dictionary = good.duplicate()
	ghost["uid"] = "ghost-uid"
	ghost["structure_id"] = "no_such_structure"
	ghost["cell"] = [OTHER_CELL.x, OTHER_CELL.y]
	var restored: BaseStructures = _new_loaded_structures()
	restored.from_save_data({"placed": [ghost, good]})
	assert_push_error_count(1)
	var uid: String = good["uid"]
	assert_eq(restored.structure_at(FREE_CELL), uid, "the known structure loads")
	assert_eq(restored.structure_at(OTHER_CELL), "", "the unknown one does not")
	assert_eq(restored.to_data().size(), 1, "one structure")


func test_r_010_31_move_emits_structure_moved() -> void:
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	var uid: String = _structures.structure_at(FREE_CELL)
	watch_signals(EventBus)
	assert_true(_structures.move(_robot, uid, OTHER_CELL).ok, "the move works")
	assert_signal_emit_count(EventBus, "structure_moved", 1)
	assert_signal_emitted_with_parameters(EventBus, "structure_moved", [uid])
	assert_signal_not_emitted(EventBus, "structure_built", "a move builds nothing")


func test_r_010_31_failed_move_emits_nothing() -> void:
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	var uid: String = _structures.structure_at(FREE_CELL)
	watch_signals(EventBus)
	assert_false(_structures.move(_robot, uid, NO_CELL).ok, "an invalid cell is refused")
	assert_signal_not_emitted(EventBus, "structure_moved", "nothing moved")


# --- Wind generator and chests (spec 012) -------------------------------------
# R-012-09 to R-012-11, R-012-16, R-012-18, R-012-20, R-012-39, R-012-41. Every
# test uses a FakeTimeService (plan D21); none waits for real time.

const GENERATOR_RECIPE_PATH := "res://resources/recipes/wind_generator.tres"
const CHEST_RECIPE_PATH := "res://resources/recipes/storage_chest.tres"
const START := 1_700_000_000
## Five chest cells away from the generator's 2x2 at FREE_CELL and from OTHER_CELL.
const CHEST_CELLS: Array[Vector2i] = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(0, 6), Vector2i(1, 6)]
const SPARE_CELL := Vector2i(2, 6)

var _clock: FakeTimeService


func _use_fake_clock() -> void:
	_clock = FakeTimeService.new()
	_clock.now = START
	_structures.time_service = _clock


func _recipe_at(path: String) -> RecipeData:
	return load(path) as RecipeData


## Gives the robot the cost of recipe times times.
func _give_cost(recipe: RecipeData, times: int = 1) -> void:
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	for item_id: StringName in cost:
		assert_true(_robot.inventory.add(item_id, cost[item_id] * times).ok, "the robot holds %s" % item_id)


func _build(path: String, cell: Vector2i) -> String:
	var recipe: RecipeData = _recipe_at(path)
	_give_cost(recipe)
	var result: ActionResult = _structures.place(_robot, recipe, cell)
	assert_true(result.ok, "%s placed on %s" % [recipe.id, cell])
	return _structures.structure_at(cell)


func test_r_012_09_place_over_limit_refused() -> void:
	_use_fake_clock()
	var generator: RecipeData = _recipe_at(GENERATOR_RECIPE_PATH)
	var _first: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	assert_true(_structures.is_at_limit(generator.result_structure), "one generator is the limit")
	assert_eq(_structures.count_of(&"wind_generator"), 1)
	_give_cost(generator)
	watch_signals(EventBus)
	var result: ActionResult = _structures.place(_robot, generator, OTHER_CELL)
	assert_false(result.ok, "a second generator is refused")
	assert_eq(result.error_key, BaseStructures.MSG_STRUCTURE_LIMIT, "with the limit reason")
	assert_eq(_structures.structure_at(OTHER_CELL), "", "no cell taken")
	assert_eq(_robot.inventory.count(&"scrap"), CraftingSystem.cost_of(generator)[&"scrap"], "nothing charged")
	assert_signal_not_emitted(EventBus, "structure_built")


func test_r_012_09_five_chests_then_refused() -> void:
	_use_fake_clock()
	var chest: RecipeData = _recipe_at(CHEST_RECIPE_PATH)
	for cell: Vector2i in CHEST_CELLS:
		var _uid: String = _build(CHEST_RECIPE_PATH, cell)
	assert_eq(_structures.count_of(&"storage_chest"), CHEST_CELLS.size())
	assert_true(_structures.is_at_limit(chest.result_structure), "five chests is the limit")
	_give_cost(chest)
	assert_eq(_structures.place(_robot, chest, SPARE_CELL).error_key, BaseStructures.MSG_STRUCTURE_LIMIT)
	var station: StructureData = _recipe.result_structure
	assert_false(_structures.is_at_limit(station), "the station has no limit")


func test_r_012_18_built_generator_starts_empty() -> void:
	_use_fake_clock()
	var uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var config: WindGeneratorData = _recipe_at(GENERATOR_RECIPE_PATH).result_structure as WindGeneratorData
	assert_eq(_structures.seconds_to_next_battery(uid), config.seconds_per_battery, "its first period starts now")
	_clock.now = START + config.seconds_per_battery
	assert_eq(_structures.seconds_to_next_battery(uid), config.seconds_per_battery, "one made, the next one starts")


func test_r_012_10_move_keeps_chest_and_generator_state() -> void:
	_use_fake_clock()
	var generator_uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var chest_uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELLS[0])
	var contents: InventoryComponent = _structures.get_chest_contents(chest_uid)
	assert_true(contents.add(&"iron", 2).ok)
	_clock.now = START + 600
	var left: int = _structures.seconds_to_next_battery(generator_uid)
	assert_true(_structures.move(_robot, generator_uid, OTHER_CELL).ok, "the generator moves")
	assert_true(_structures.move(_robot, chest_uid, SPARE_CELL).ok, "the chest moves")
	assert_same(_structures.get_chest_contents(chest_uid), contents, "the same contents")
	assert_eq(contents.count(&"iron"), 2, "with what it held")
	assert_eq(_structures.seconds_to_next_battery(generator_uid), left, "the generation goes on")


func test_r_012_11_bonus_while_generator_placed() -> void:
	_use_fake_clock()
	watch_signals(_structures)
	assert_eq(_structures.get_max_battery_bonus(), 0.0, "no generator, no bonus")
	var _chest: String = _build(CHEST_RECIPE_PATH, CHEST_CELLS[0])
	assert_signal_not_emitted(_structures, "max_battery_bonus_changed", "a chest gives no bonus")
	var _generator: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var config: WindGeneratorData = _recipe_at(GENERATOR_RECIPE_PATH).result_structure as WindGeneratorData
	assert_eq(_structures.get_max_battery_bonus(), config.max_battery_bonus, "the generator's bonus")
	assert_signal_emit_count(_structures, "max_battery_bonus_changed", 1)
	assert_signal_emitted_with_parameters(_structures, "max_battery_bonus_changed", [config.max_battery_bonus])


func test_r_012_16_counts_while_base_unloaded() -> void:
	_use_fake_clock()
	var uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var config: WindGeneratorData = _recipe_at(GENERATOR_RECIPE_PATH).result_structure as WindGeneratorData
	_structures.unbind_base()
	_base.free()
	_clock.now = START + 2 * config.seconds_per_battery
	_base = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(_base)
	_structures.bind_base(_base)
	assert_true(_structures.collect_batteries(_robot, uid).ok, "batteries made while the base was away")
	assert_eq(_robot.inventory.count(config.battery_item.id), 2, "two periods, two batteries")


func test_r_012_20_collect_request_emits_event() -> void:
	_use_fake_clock()
	var uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var config: WindGeneratorData = _recipe_at(GENERATOR_RECIPE_PATH).result_structure as WindGeneratorData
	watch_signals(EventBus)
	assert_eq(
		_structures.collect_batteries(_robot, uid).error_key,
		WindGeneratorComponent.MSG_GENERATOR_EMPTY,
		"nothing made yet"
	)
	assert_signal_not_emitted(EventBus, "batteries_collected", "nothing moved")
	_clock.now = START + config.seconds_per_battery
	assert_true(_structures.collect_batteries(_robot, uid).ok, "one battery")
	assert_signal_emit_count(EventBus, "batteries_collected", 1)
	assert_signal_emitted_with_parameters(EventBus, "batteries_collected", [uid, _robot.player_uid])


func test_r_012_20_collect_invalid_requests() -> void:
	_use_fake_clock()
	var chest_uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELLS[0])
	var generator_uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	assert_eq(_structures.collect_batteries(null, generator_uid).error_key, ActionResult.ERR_INVALID_REQUEST)
	assert_eq(_structures.collect_batteries(_robot, chest_uid).error_key, ActionResult.ERR_INVALID_REQUEST)
	assert_eq(_structures.collect_batteries(_robot, "nope").error_key, ActionResult.ERR_INVALID_REQUEST)
	assert_push_error_count(3)


func test_r_012_39_save_holds_chests_and_generators() -> void:
	_use_fake_clock()
	var generator_uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var chest_uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELLS[0])
	assert_true(_structures.get_chest_contents(chest_uid).add(&"scrap", 4).ok)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_structures.to_save_data())) as Dictionary
	assert_true(saved.has("chests"), "chests saved")
	assert_true(saved.has("generators"), "generators saved")
	var restored: BaseStructures = _new_loaded_structures()
	restored.time_service = _clock
	restored.from_save_data(saved)
	assert_eq(restored.get_chest_contents(chest_uid).count(&"scrap"), 4, "the chest's contents")
	assert_eq(
		restored.seconds_to_next_battery(generator_uid),
		_structures.seconds_to_next_battery(generator_uid),
		"the generator's progress"
	)
	assert_eq(restored.to_save_data(), _structures.to_save_data(), "the same part")


func test_r_012_43_station_only_part_unchanged() -> void:
	_use_fake_clock()
	_give_scrap(_cost())
	assert_true(_place(FREE_CELL).ok)
	assert_eq(_structures.to_save_data().keys(), ["placed"], "no chest nor generator: saved as spec 010")


func test_r_012_41_load_emits_no_facts() -> void:
	_use_fake_clock()
	var _generator: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var _chest: String = _build(CHEST_RECIPE_PATH, CHEST_CELLS[0])
	var saved: Dictionary = _structures.to_save_data()
	var restored: BaseStructures = _new_loaded_structures()
	restored.time_service = _clock
	watch_signals(EventBus)
	watch_signals(restored)
	restored.from_save_data(saved)
	assert_signal_not_emitted(EventBus, "structure_built", "loading builds nothing")
	assert_signal_not_emitted(EventBus, "batteries_collected", "nor collects")
	assert_signal_not_emitted(EventBus, "chest_closed", "nor closes a chest")
	assert_signal_emit_count(restored, "max_battery_bonus_changed", 1, "only the state of the bonus")


func _generator_instance() -> WindGenerator:
	for node: Node in _instances():
		var generator: WindGenerator = node as WindGenerator
		if generator != null and not generator.is_queued_for_deletion():
			return generator
	return null


func test_r_012_10_reload_with_base_loaded_rebinds_state() -> void:
	_use_fake_clock()
	var uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	var config: WindGeneratorData = _recipe_at(GENERATOR_RECIPE_PATH).result_structure as WindGeneratorData
	_clock.now = START + 2 * config.seconds_per_battery
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_structures.to_save_data())) as Dictionary
	_structures.from_save_data(saved)
	var generator: WindGenerator = _generator_instance()
	assert_not_null(generator, "the generator stands again in the loaded base")
	if generator == null:
		return
	var label: Label3D = generator.get_node("%Label") as Label3D
	assert_string_contains(label.text, tr(&"GENERATOR_STORED") % [2, config.max_stored], false)
	assert_true(_structures.collect_batteries(_robot, uid).ok)
	assert_string_contains(
		label.text, tr(&"GENERATOR_STORED") % [0, config.max_stored], false
	)


func test_r_012_27_chest_and_generator_uses_relayed() -> void:
	_use_fake_clock()
	var chest_uid: String = _build(CHEST_RECIPE_PATH, CHEST_CELLS[0])
	var generator_uid: String = _build(GENERATOR_RECIPE_PATH, FREE_CELL)
	watch_signals(_structures)
	for node: Node in _instances():
		var interactable: InteractableComponent = node.get_node_or_null("%Interactable") as InteractableComponent
		if interactable != null and (node is StorageChest or node is WindGenerator):
			interactable.interact(_robot)
	assert_signal_emit_count(_structures, "structure_used", 2, "one use per structure")
	var uses: Array = [
		get_signal_parameters(_structures, "structure_used", 0), get_signal_parameters(_structures, "structure_used", 1)
	]
	var uids: Array[String] = []
	for use: Variant in uses:
		var parameters: Array = use
		var used_uid: String = parameters[0]
		uids.append(used_uid)
	uids.sort()
	var expected: Array[String] = [chest_uid, generator_uid]
	expected.sort()
	assert_eq(uids, expected, "each use names its structure")
