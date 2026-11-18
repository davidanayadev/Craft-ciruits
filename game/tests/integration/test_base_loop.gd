extends GutTest
## The whole loop of spec 009 in the main scene (R-009-54, ACTION_PLAN Fase 1
## and Fase 2): start in the base, travel to the green zone, collect scrap,
## come back, build and place a charging station at the bench, recharge at it,
## move it, travel again and find it on its cell on returning.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TRAVEL_TIMEOUT_S := 10.0
const FIRST_CELL := Vector2i(9, 2)
const MOVED_CELL := Vector2i(2, 5)

var _main: Node
var _robot: Robot
var _loader: ZoneLoader
var _ui: UIManager
var _hud: Hud
var _structures: BaseStructures


func before_each() -> void:
	GameManager.clear_visit_counts()
	SaveTestSupport.start_world()
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)
	_robot = _main.get_node("%Robot") as Robot
	_loader = _main.get_node("%ZoneLoader") as ZoneLoader
	_ui = _main.get_node("%UIManager") as UIManager
	_hud = _main.get_node("%Hud") as Hud
	_structures = _main.get_node("%BaseStructures") as BaseStructures
	if _loader.is_travelling():
		await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)


func after_each() -> void:
	GameManager.clear_visit_counts()
	SaveTestSupport.reset()


## Walks up to node (placed next to it) and interacts, as the player does.
func _interact_with(node: Node3D, offset: Vector3) -> void:
	_robot.global_position = node.global_position + offset
	await wait_physics_frames(4)
	_robot.request_interact()


func _use_exit() -> void:
	var exit: Node3D = _loader.get_current_zone().get_node("%ExitPoint") as Node3D
	await _interact_with(exit, Vector3(0.0, 0.0, 1.0))
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)


func _collect_scrap(needed: int) -> void:
	var farm: FarmZone = _loader.get_current_zone() as FarmZone
	for box: LootBox in farm.get_boxes():
		if _robot.inventory.count(&"scrap") >= needed:
			return
		await _interact_with(box, Vector3(1.6, 0.0, 0.0))
		var contents: InventoryComponent = box.get_contents()
		var slots: Array[int] = []
		for index: int in contents.get_slot_count():
			slots.append(index)
		_robot.inventory.take_from(contents, slots)
		_ui.close_all()


func _screen_of(screen_id: StringName) -> UIScreen:
	for child: Node in _ui.get_children():
		var screen: UIScreen = child as UIScreen
		if screen != null and not screen.is_queued_for_deletion():
			if (screen_id == BenchScreen.SCREEN_ID and screen is BenchScreen) or (
				screen_id == PlacementScreen.SCREEN_ID and screen is PlacementScreen
			):
				return screen
	return null


func test_r_009_54_full_loop() -> void:
	var base: BaseZone = _loader.get_current_zone() as BaseZone
	assert_not_null(base, "the game starts in the base")
	if base == null:
		return
	await _use_exit()
	assert_true(_loader.get_current_zone() is FarmZone, "in the green zone")
	var cost: int = CraftingSystem.cost_of(DataRegistry.get_recipe(&"charging_station"))[&"scrap"]
	await _collect_scrap(cost)
	assert_gte(_robot.inventory.count(&"scrap"), cost, "enough scrap collected")
	await _use_exit()
	base = _loader.get_current_zone() as BaseZone
	assert_not_null(base, "back in the base")
	if base == null:
		return
	assert_lt(_robot.battery.get_current(), _robot.battery.get_maximum(), "entering does not recharge")

	await _interact_with(base.get_node("%RepairBench") as Node3D, Vector3(0.0, 0.0, 1.5))
	var build: BenchScreen = _screen_of(BenchScreen.SCREEN_ID) as BenchScreen
	assert_not_null(build, "the bench opens the bench screen")
	if build == null:
		return
	var entry: Node = build.get_node("%BuildSection").get_node("charging_station")
	(entry.get_node("ActionButton") as Button).pressed.emit()
	var placement: PlacementScreen = _screen_of(PlacementScreen.SCREEN_ID) as PlacementScreen
	assert_not_null(placement, "placement starts")
	if placement == null:
		return
	placement.select_cell(FIRST_CELL)
	assert_true(placement.confirm().ok, "the station is placed")
	var uid: String = _structures.structure_at(FIRST_CELL)
	assert_ne(uid, "", "on its cell")

	_robot.battery.consume(30.0)
	var station: Node3D = base.get_structures_root().get_child(0) as Node3D
	await _interact_with(station, Vector3(0.0, 0.0, 1.2))
	assert_eq(_robot.battery.get_current(), _robot.battery.get_maximum(), "recharged to 100 %")

	(_hud.get_node("%EditBaseButton") as Button).pressed.emit()
	var edit: PlacementScreen = _screen_of(PlacementScreen.SCREEN_ID) as PlacementScreen
	assert_not_null(edit, "edit mode")
	if edit == null:
		return
	edit.select_cell(FIRST_CELL)
	edit.select_cell(MOVED_CELL)
	assert_true(edit.confirm().ok, "moved")
	(_hud.get_node("%EditBaseButton") as Button).pressed.emit()
	assert_false(_ui.is_modal_open(), "edit mode closed")

	await _use_exit()
	await _use_exit()
	base = _loader.get_current_zone() as BaseZone
	assert_not_null(base, "back in the base again")
	if base == null:
		return
	assert_eq(_structures.get_cell(uid), MOVED_CELL, "the station is where it was moved")
	assert_eq(base.get_structures_root().get_child_count(), 1, "and it stands in the base")
	if base.get_structures_root().get_child_count() == 1:
		var standing: Node3D = base.get_structures_root().get_child(0) as Node3D
		assert_eq(
			standing.global_position,
			_structures.cell_to_world(DataRegistry.get_structure(&"charging_station"), MOVED_CELL),
			"on its cell"
		)
