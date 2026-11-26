extends GutTest
## The base scene (spec 009): floor, boundaries, spawn point, exit point, the
## fixed repair bench and an empty buildable area (R-009-19); no enemies and
## no navigation mesh (R-009-18); the exit leads to the green zone (R-009-10,
## R-009-12); the battery drains as anywhere else (R-009-21); the grid is the
## one BaseStructures uses and BuildArea sits on its origin (R-009-23); the
## preview has no collision and shows validity (R-009-34, presentation).

const BASE_SCENE := preload("res://scenes/base/base.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const STATION_PATH := "res://resources/structures/charging_station.tres"
const CONTROLS_PATH := "res://resources/config/controls.tres"
## wait_physics_frames() may run a few frames more or fewer than requested.
const FRAME_SLACK := 4.0
const PUSH_SECONDS := 2.0
const EDGE_MARGIN := 1.0
const MOVE_SECONDS := 0.5

var _base: BaseZone


func before_each() -> void:
	_base = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(_base)


func after_each() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)


func _new_robot_at(position: Vector3) -> Robot:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.global_position = position
	return robot


func _reach() -> float:
	return (load(CONTROLS_PATH) as ControlConfigData).interaction_range_m


func test_r_009_19_has_floor_bounds_spawn_exit_bench_area() -> void:
	assert_true(_base is Zone, "the base is a Zone")
	var ground: GridMap = _base.get_node("%Ground") as GridMap
	assert_not_null(ground, "floor")
	if ground != null:
		assert_gt(ground.get_used_cells().size(), 0, "the floor has tiles")
	var boundaries: Array[Node] = _base.get_node("%Boundaries").get_children()
	assert_eq(boundaries.size(), 4, "a boundary on each side")
	for wall: Node in boundaries:
		assert_true(wall is StaticBody3D, "%s blocks" % wall.name)
	assert_not_null(_base.get_node("%SpawnPoint") as Marker3D, "spawn point")
	assert_not_null(_base.get_node("%ExitPoint") as ExitPoint, "exit point")
	assert_not_null(_base.get_node("%RepairBench") as RepairBench, "repair bench")
	assert_not_null(_base.get_node("%BuildArea") as BuildArea, "buildable area")
	var half: Vector2 = _base.data.size_m / 2.0
	var spawn: Vector3 = _base.get_spawn_position() - _base.global_position
	assert_lt(absf(spawn.x), half.x, "spawn inside on X")
	assert_lt(absf(spawn.z), half.y, "spawn inside on Z")


func test_r_009_19_build_area_starts_empty() -> void:
	assert_eq(_base.get_structures_root().get_child_count(), 0, "no structure placed")
	assert_eq(_base.get_preview_root().get_child_count(), 0, "no preview")
	assert_false(_base.is_grid_visible(), "the grid lines are hidden outside placement")


func test_r_009_19_robot_moves_in_base() -> void:
	# ACTION_PLAN 2.1: the player can move around the base.
	var robot: Robot = _new_robot_at(_base.get_spawn_position())
	var start: Vector3 = robot.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(int(MOVE_SECONDS * Engine.physics_ticks_per_second))
	Input.action_release(&"move_forward")
	assert_gt(robot.global_position.distance_to(start), 0.5, "the robot walked")


func test_r_009_19_bounds_stop_robot() -> void:
	var half: Vector2 = _base.data.size_m / 2.0
	var robot: Robot = _new_robot_at(Vector3.ZERO)
	# Without a camera rig the robot moves on world axes: forward is -Z.
	var pushes: Dictionary[StringName, Vector3] = {
		&"move_right": Vector3(half.x - EDGE_MARGIN, 0.0, 1.0),
		&"move_left": Vector3(-half.x + EDGE_MARGIN, 0.0, 1.0),
		&"move_back": Vector3(0.0, 0.0, half.y - EDGE_MARGIN),
		&"move_forward": Vector3(-4.0, 0.0, -half.y + EDGE_MARGIN),
	}
	for action: StringName in pushes:
		robot.global_position = pushes[action]
		Input.action_press(action)
		await wait_physics_frames(int(PUSH_SECONDS * Engine.physics_ticks_per_second))
		Input.action_release(action)
		var position: Vector3 = robot.global_position
		assert_lte(absf(position.x), half.x, "%s: still inside on X (%s)" % [action, position])
		assert_lte(absf(position.z), half.y, "%s: still inside on Z (%s)" % [action, position])


func test_r_009_18_no_navigation_region_nor_spawner() -> void:
	assert_eq(_base.find_children("*", "NavigationRegion3D", true, false).size(), 0, "no navmesh")
	var spawners: Array[Node] = _base.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node is EnemySpawner
	)
	assert_eq(spawners.size(), 0, "no zombie spawner")


func test_r_009_10_has_one_exit_point() -> void:
	var exits: Array[Node] = _base.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node is ExitPoint
	)
	assert_eq(exits.size(), 1, "one exit point")


func test_r_009_12_exit_destinations() -> void:
	var exit: ExitPoint = _base.get_node("%ExitPoint") as ExitPoint
	assert_same(exit.destination, DataRegistry.get_zone(Vector2i(0, 0)), "the base leads to the green zone")
	assert_gt(
		exit.global_position.distance_to(_base.get_spawn_position()),
		_reach(),
		"out of reach from the spawn point"
	)


func test_r_009_21_battery_drains_in_base() -> void:
	var robot: Robot = _new_robot_at(_base.get_spawn_position())
	var start: float = robot.battery.get_current()
	await wait_physics_frames(Engine.physics_ticks_per_second)
	var drained: float = start - robot.battery.get_current()
	var expected: float = robot.battery.drain_per_second(LocomotionSystem.Gait.IDLE)
	var tolerance: float = expected * FRAME_SLACK / Engine.physics_ticks_per_second
	assert_almost_eq(drained, expected, tolerance, "the passive drain of anywhere else")


func test_r_009_23_same_grid_resource_and_origin() -> void:
	var grid: BuildGridData = load(BASE_GRID_PATH) as BuildGridData
	assert_same(_base.grid, grid, "the base uses base_grid.tres")
	var area: BuildArea = _base.get_node("%BuildArea") as BuildArea
	assert_same(area.grid, grid, "and so does its BuildArea")
	assert_eq(area.position, grid.area_origin_local, "BuildArea sits on the corner of cell (0, 0)")
	var main_source: String = FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	assert_true(main_source.contains(BASE_GRID_PATH), "BaseStructures in main.tscn uses it too")


func test_r_009_19_reserved_cells_in_front_of_spawn_exit_and_bench() -> void:
	var grid: BuildGridData = _base.grid
	var rules: BuildGrid = BuildGrid.new(grid, _base.data.zone_id)
	for node_name: String in ["%SpawnPoint", "%ExitPoint", "%RepairBench"]:
		var node: Node3D = _base.get_node(node_name) as Node3D
		var local: Vector3 = _base.to_local(node.global_position)
		var cell: Vector2i = rules.local_to_cell(local)
		assert_false(rules.contains(cell), "%s is outside the area" % node_name)
		var nearest: Vector2i = cell.clamp(Vector2i.ZERO, grid.area_size_cells - Vector2i.ONE)
		assert_true(grid.reserved_cells.has(nearest), "the cell in front of %s is reserved" % node_name)


func test_r_009_34_preview_has_no_collision_and_shows_validity() -> void:
	var station: StructureData = load(STATION_PATH) as StructureData
	if station == null or station.scene == null:
		fail_test("the charging station has no scene yet")
		return
	_base.show_preview(station, Vector3(1.5, 0.0, 0.5), true)
	var preview: Node3D = _base.get_preview()
	assert_not_null(preview, "a preview is shown")
	if preview == null:
		return
	assert_eq(preview.process_mode, Node.PROCESS_MODE_DISABLED, "out of physics: no collision")
	assert_eq(_base.to_local(preview.global_position), Vector3(1.5, 0.0, 0.5), "at the local position")
	var meshes: Array[Node] = preview.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "the preview is visible")
	for mesh: Node in meshes:
		assert_same((mesh as MeshInstance3D).material_override, BaseZone.PREVIEW_VALID, "green")
	_base.show_preview(station, Vector3(2.5, 0.0, 0.5), false)
	assert_same(_base.get_preview(), preview, "the same preview moves")
	for mesh: Node in meshes:
		assert_same((mesh as MeshInstance3D).material_override, BaseZone.PREVIEW_INVALID, "red")
	_base.hide_preview()
	assert_null(_base.get_preview(), "hidden")
