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
	assert_eq(result.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS, "the key BuildScreen shows")
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
