extends GutTest
## Green farm zone (spec 004): ground tiles, decoration and colliders
## (R-004-01), inside one grid cell (R-004-03), boundaries that keep the robot
## in (R-004-04), and boxes placed on hand-made markers by the seeded RNG
## (R-004-11, R-004-21), and the zone relays the opened signal of each box
## (R-005-16). The zone is generated with seeds given here, never
## through GameManager.
## Spec 008: contents depend on the visit (R-008-08), repopulate() starts a visit (R-008-09).
## Spec 009: one exit point next to the spawn point, towards the base (R-009-10, R-009-12).

const ZONE_SCENE := preload("res://scenes/farm_zone/farm_zone_green.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const ZOMBIE_SCENE := preload("res://scenes/entities/zombie.tscn")
const WORLD_GRID_PATH := "res://resources/config/world_grid.tres"
const DEV_WORLD_PATH := "res://resources/config/dev_world.tres"
const SEED_A := 1001
## Seeds checked to give different layouts; see test_r_004_11_other_seed_other_layout.
const SEED_B := 1002
const DECORATION_KINDS: PackedStringArray = ["Tree", "Rock", "Scrap"]
## Distance from the edge at which the robot starts pushing outward.
const EDGE_MARGIN := 1.0
const PUSH_SECONDS := 2.0

var _grid_config: WorldGridConfigData


func before_each() -> void:
	_grid_config = load(WORLD_GRID_PATH) as WorldGridConfigData


func after_each() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)


func _new_zone() -> FarmZone:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(zone)
	return zone


func _generated_zone(world_seed: int) -> FarmZone:
	var zone: FarmZone = _new_zone()
	zone.generate(world_seed, ZonePopulation.FIRST_VISIT)
	return zone


func _box_positions(zone: FarmZone) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for box: LootBox in zone.get_boxes():
		positions.append(box.position)
	return positions


func _marker_positions(zone: FarmZone) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for marker: Node in zone.get_node("%BoxMarkers").get_children():
		positions.append((marker as Marker3D).position)
	return positions


func _half_size(zone: FarmZone) -> Vector2:
	return zone.data.size_m / 2.0


func test_r_004_01_ground_tiles_cover_zone() -> void:
	var zone: FarmZone = _new_zone()
	var ground: GridMap = zone.get_node("%Ground") as GridMap
	assert_not_null(ground, "the ground is a GridMap")
	if ground == null:
		return
	var half: Vector2 = _half_size(zone)
	var tiles_seen: Dictionary[int, bool] = {}
	var outside: int = 0
	var covered_area: float = 0.0
	for cell: Vector3i in ground.get_used_cells():
		tiles_seen[ground.get_cell_item(cell)] = true
		var centre: Vector3 = ground.map_to_local(cell)
		var reach: Vector2 = Vector2(ground.cell_size.x, ground.cell_size.z) / 2.0
		covered_area += ground.cell_size.x * ground.cell_size.z
		if absf(centre.x) + reach.x > half.x + 0.001 or absf(centre.z) + reach.y > half.y + 0.001:
			outside += 1
	assert_eq(outside, 0, "no ground tile outside the zone")
	assert_almost_eq(
		covered_area, zone.data.size_m.x * zone.data.size_m.y, 0.01, "tiles cover the whole zone"
	)
	assert_eq(tiles_seen.size(), 2, "grass and dirt tiles are both used")
	assert_eq(ground.mesh_library.get_item_list().size(), 2, "the tile library has grass and dirt")


func test_r_004_01_decoration_of_every_kind() -> void:
	var zone: FarmZone = _new_zone()
	var decoration: Node = zone.get_node("%Decoration")
	for kind: String in DECORATION_KINDS:
		var found: Array[Node] = decoration.find_children(kind + "*", "StaticBody3D", false, false)
		assert_gt(found.size(), 0, "the zone has decoration of kind %s" % kind)


func test_r_004_01_every_obstacle_has_collider() -> void:
	var zone: FarmZone = _new_zone()
	var obstacles: Array[Node] = zone.get_node("%Decoration").get_children()
	obstacles.append_array(zone.get_node("%Boundaries").get_children())
	assert_gt(obstacles.size(), 0, "the zone has obstacles")
	for obstacle: Node in obstacles:
		assert_true(obstacle is StaticBody3D, "%s is a static body" % obstacle.name)
		var shapes: Array[Node] = obstacle.find_children("*", "CollisionShape3D", false, false)
		assert_gt(shapes.size(), 0, "%s has a collider" % obstacle.name)
		for shape: Node in shapes:
			assert_not_null((shape as CollisionShape3D).shape, "%s has a shape" % obstacle.name)
	# Every visible mesh of the zone belongs to an obstacle: nothing you can see
	# can be walked through.
	for mesh: Node in zone.find_children("*", "MeshInstance3D", true, false):
		assert_true(mesh.get_parent() is StaticBody3D, "%s belongs to a static body" % mesh.name)


func test_r_004_03_zone_fits_in_one_cell() -> void:
	var zone: FarmZone = _new_zone()
	var half_cell: float = _grid_config.cell_size_m / 2.0
	var outside: PackedStringArray = PackedStringArray()
	for node: Node in zone.find_children("*", "Node3D", true, false):
		var node_3d: Node3D = node as Node3D
		var reach: Vector3 = Vector3.ZERO
		var collision: CollisionShape3D = node as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			# World-axis extents of the box, which may be rotated.
			var half_box: Vector3 = (collision.shape as BoxShape3D).size / 2.0
			var basis: Basis = node_3d.global_basis
			reach = basis.x.abs() * half_box.x + basis.y.abs() * half_box.y + basis.z.abs() * half_box.z
		var position: Vector3 = node_3d.global_position - zone.global_position
		if absf(position.x) + reach.x > half_cell or absf(position.z) + reach.z > half_cell:
			outside.append(String(node.name))
	assert_eq(outside.size(), 0, "nodes outside the %s m cell: %s" % [_grid_config.cell_size_m, outside])
	assert_lte(zone.data.size_m.x, _grid_config.cell_size_m, "the playable area fits too")


func test_r_004_04_robot_cannot_leave() -> void:
	var zone: FarmZone = _generated_zone(SEED_A)
	var half: Vector2 = _half_size(zone)
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	# Without a camera rig the robot moves on world axes: forward is -Z.
	var pushes: Dictionary[StringName, Vector3] = {
		&"move_right": Vector3(half.x - EDGE_MARGIN, 0.0, 3.0),
		&"move_left": Vector3(-half.x + EDGE_MARGIN, 0.0, 3.0),
		&"move_back": Vector3(3.0, 0.0, half.y - EDGE_MARGIN),
		&"move_forward": Vector3(3.0, 0.0, -half.y + EDGE_MARGIN),
	}
	for action: StringName in pushes:
		robot.global_position = pushes[action]
		Input.action_press(action)
		await wait_physics_frames(int(PUSH_SECONDS * Engine.physics_ticks_per_second))
		Input.action_release(action)
		var position: Vector3 = robot.global_position
		assert_lte(absf(position.x), half.x, "%s: still inside on X (%s)" % [action, position])
		assert_lte(absf(position.z), half.y, "%s: still inside on Z (%s)" % [action, position])


func test_r_004_04_invisible_walls_behind_the_fences() -> void:
	var zone: FarmZone = _new_zone()
	var boundaries: Node = zone.get_node("%Boundaries")
	var fences: Array[Node] = boundaries.find_children("Fence*", "StaticBody3D", false, false)
	var walls: Array[Node] = boundaries.find_children("Wall*", "StaticBody3D", false, false)
	assert_eq(fences.size(), 4, "a visible fence on each side")
	assert_eq(walls.size(), 4, "an invisible backup wall on each side")
	for fence: Node in fences:
		var meshes: Array[Node] = fence.find_children("*", "MeshInstance3D", false, false)
		assert_gt(meshes.size(), 0, "%s is visible" % fence.name)
	for wall: Node in walls:
		var meshes: Array[Node] = wall.find_children("*", "MeshInstance3D", false, false)
		assert_eq(meshes.size(), 0, "%s is invisible" % wall.name)


func test_r_004_05_spawn_point_inside_and_clear() -> void:
	var zone: FarmZone = _new_zone()
	var half: Vector2 = _half_size(zone)
	var spawn: Vector3 = zone.get_spawn_position() - zone.global_position
	assert_lt(absf(spawn.x), half.x, "spawn inside the zone on X")
	assert_lt(absf(spawn.z), half.y, "spawn inside the zone on Z")
	for marker: Vector3 in _marker_positions(zone):
		assert_gt(marker.distance_to(spawn), 3.0, "no box marker on top of the spawn point")


func test_r_004_11_same_seed_same_boxes() -> void:
	var first: FarmZone = _generated_zone(SEED_A)
	var second: FarmZone = _generated_zone(SEED_A)
	assert_gt(first.get_boxes().size(), 0, "the zone has boxes")
	assert_eq(_box_positions(first), _box_positions(second), "same number and same positions")


func test_r_004_11_other_seed_other_layout() -> void:
	var first: FarmZone = _generated_zone(SEED_A)
	var second: FarmZone = _generated_zone(SEED_B)
	assert_ne(_box_positions(first), _box_positions(second), "another seed, another layout")


func test_r_004_11_generate_twice_reports_error() -> void:
	var zone: FarmZone = _generated_zone(SEED_A)
	var before: Array[Vector3] = _box_positions(zone)
	zone.generate(SEED_B, ZonePopulation.FIRST_VISIT)
	assert_push_error("already")
	assert_eq(_box_positions(zone), before, "the second call changes nothing")


func test_r_004_21_boxes_on_markers() -> void:
	var zone: FarmZone = _generated_zone(SEED_A)
	var markers: Array[Vector3] = _marker_positions(zone)
	assert_gt(markers.size(), zone.data.box_count_max, "more markers than the maximum of boxes")
	var boxes: Array[Vector3] = _box_positions(zone)
	assert_between(
		boxes.size(), zone.data.box_count_min, zone.data.box_count_max, "boxes within BALANCE §7.1"
	)
	var used: Dictionary[Vector3, bool] = {}
	for box: Vector3 in boxes:
		assert_true(markers.has(box), "box at %s sits on a marker" % box)
		used[box] = true
	assert_eq(used.size(), boxes.size(), "one box per marker at most")


func test_r_004_21_dev_seed_known_boxes() -> void:
	# Pins the boxes of the development world. Number and position of the boxes
	# depend only on seed + zone_id (BALANCE §7.2): later changes to the zone's
	# generation must not move them.
	var dev_world: DevWorldConfigData = load(DEV_WORLD_PATH) as DevWorldConfigData
	assert_eq(dev_world.world_seed, 20261115, "the seed this known answer was taken with")
	var zone: FarmZone = _generated_zone(dev_world.world_seed)
	var expected: Array[Vector3] = [
		Vector3(-12, 0, -13),
		Vector3(-3, 0, -18),
		Vector3(7, 0, 2),
		Vector3(-10, 0, 13),
		Vector3(17, 0, 11),
	]
	assert_eq(_box_positions(zone), expected, "boxes of the development world")


func test_r_004_21_box_count_in_range_for_many_seeds() -> void:
	var counts_seen: Dictionary[int, bool] = {}
	for world_seed: int in 30:
		var zone: FarmZone = _generated_zone(world_seed)
		var count: int = zone.get_boxes().size()
		counts_seen[count] = true
		assert_between(count, zone.data.box_count_min, zone.data.box_count_max, "seed %d" % world_seed)
	assert_gt(counts_seen.size(), 1, "the number of boxes depends on the seed")


func test_r_004_23_box_contents_from_seed_and_marker() -> void:
	var first: FarmZone = _generated_zone(SEED_A)
	var second: FarmZone = _generated_zone(SEED_A)
	var opener: Node3D = Node3D.new()
	add_child_autofree(opener)
	var first_boxes: Array[LootBox] = first.get_boxes()
	var second_boxes: Array[LootBox] = second.get_boxes()
	var first_loot: Array[String] = []
	var second_loot: Array[String] = []
	second_loot.resize(second_boxes.size())
	for box: LootBox in first_boxes:
		first_loot.append(_open_and_describe(box, opener))
	# The second zone is opened in reverse order.
	for i: int in range(second_boxes.size() - 1, -1, -1):
		second_loot[i] = _open_and_describe(second_boxes[i], opener)
	assert_eq(first_loot, second_loot, "each box gives the same loot whatever the opening order")
	var distinct: Dictionary[String, bool] = {}
	for loot: String in first_loot:
		distinct[loot] = true
	assert_gt(distinct.size(), 1, "boxes of one zone do not all share the same roll")


func _open_and_describe(box: LootBox, opener: Node3D) -> String:
	watch_signals(box)
	(box.get_node("%Interactable") as InteractableComponent).interact(opener)
	var parameters: Array = get_signal_parameters(box, "loot_generated")
	var stacks: Array[ItemStack] = parameters[0]
	var parts: PackedStringArray = PackedStringArray()
	for stack: ItemStack in stacks:
		parts.append("%s x%d" % [stack.item.id, stack.quantity])
	return ", ".join(parts)


func test_r_005_16_zone_relays_box_opened() -> void:
	var zone: FarmZone = _generated_zone(SEED_A)
	var opener: Node3D = Node3D.new()
	add_child_autofree(opener)
	watch_signals(zone)
	var boxes: Array[LootBox] = zone.get_boxes()
	assert_gt(boxes.size(), 0, "the zone has boxes")
	for i: int in boxes.size():
		(boxes[i].get_node("%Interactable") as InteractableComponent).interact(opener)
		assert_signal_emit_count(zone, "box_opened", i + 1, "one box_opened per opened box")
		var parameters: Array = get_signal_parameters(zone, "box_opened", i)
		var box: LootBox = parameters[0]
		var relayed_opener: Node3D = parameters[1]
		assert_same(box, boxes[i], "box_opened says which box")
		assert_same(relayed_opener, opener, "and who opened it")


## Rolled contents of every box of the zone, in box order. Opens every box.
func _describe_contents(zone: FarmZone) -> Array[String]:
	var opener: Node3D = Node3D.new()
	add_child_autofree(opener)
	var contents: Array[String] = []
	for box: LootBox in zone.get_boxes():
		contents.append(_open_and_describe(box, opener))
	return contents


func _visit_zone(world_seed: int, visit: int) -> FarmZone:
	var zone: FarmZone = _new_zone()
	zone.generate(world_seed, visit)
	return zone


func _new_zombie_pool() -> ObjectPool:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = ZOMBIE_SCENE
	add_child_autofree(pool)
	return pool


## One "id @ position" line per zombie, in spawn order.
func _describe_enemies(zone: FarmZone) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for zombie: Zombie in zone.get_enemies():
		lines.append("%s @ %s" % [zombie.get_data().id, zombie.global_position])
	return lines


func test_r_008_08_contents_change_with_visit() -> void:
	var by_visit: Array[Array] = []
	for visit: int in 3:
		var zone: FarmZone = _visit_zone(SEED_A, visit)
		by_visit.append(_describe_contents(zone))
	assert_gt(by_visit[0].size(), 0, "the zone has boxes")
	var all_equal: bool = by_visit[0] == by_visit[1] and by_visit[1] == by_visit[2]
	assert_false(all_equal, "another visit rolls other contents for the same boxes")


func test_r_008_08_positions_same_on_every_visit() -> void:
	var reference: Array[Vector3] = _box_positions(_visit_zone(SEED_A, 0))
	assert_gt(reference.size(), 0, "the zone has boxes")
	for visit: int in [1, 5]:
		assert_eq(
			_box_positions(_visit_zone(SEED_A, visit)), reference, "visit %d: same boxes in the same places" % visit
		)


func test_r_008_09_repopulate_closes_boxes_with_new_contents() -> void:
	var pool: ObjectPool = _new_zombie_pool()
	var zone: FarmZone = _visit_zone(SEED_A, 0)
	var positions: Array[Vector3] = _box_positions(zone)
	var old_boxes: Array[LootBox] = zone.get_boxes().duplicate()
	_describe_contents(zone)
	zone.repopulate(SEED_A, 1, pool)
	await wait_process_frames(1)
	assert_eq(zone.get_boxes().size(), positions.size(), "same number of boxes")
	assert_eq(_box_positions(zone), positions, "on the same markers")
	for box: LootBox in zone.get_boxes():
		assert_false(box.is_opened(), "a new visit closes every box")
	for old_box: LootBox in old_boxes:
		assert_false(is_instance_valid(old_box), "the old box is gone")
	var expected: Array[String] = _describe_contents(_visit_zone(SEED_A, 1))
	assert_eq(_describe_contents(zone), expected, "contents of visit 1, as if generated directly")


func test_r_008_09_repopulate_discards_leftovers() -> void:
	var pool: ObjectPool = _new_zombie_pool()
	var zone: FarmZone = _visit_zone(SEED_A, 0)
	_describe_contents(zone)
	zone.repopulate(SEED_A, 1, pool)
	await wait_process_frames(1)
	for box: LootBox in zone.get_boxes():
		assert_true(box.get_contents().is_empty(), "nothing left over from the previous visit")
	var expected: Array[String] = _describe_contents(_visit_zone(SEED_A, 1))
	var opener: Node3D = Node3D.new()
	add_child_autofree(opener)
	var boxes: Array[LootBox] = zone.get_boxes()
	for i: int in boxes.size():
		var described: String = _open_and_describe(boxes[i], opener)
		var held: int = 0
		for stack: ItemStack in boxes[i].get_contents().get_slots():
			if stack != null:
				held += stack.quantity
		var rolled: int = 0
		for part: String in described.split(", ", false):
			rolled += int(part.get_slice(" x", 1))
		assert_eq(held, rolled, "box %d holds only what its new roll gave" % i)
		assert_eq(described, expected[i], "box %d: roll of visit 1" % i)


func test_r_008_09_repopulate_places_enemies_of_the_visit() -> void:
	var pool: ObjectPool = _new_zombie_pool()
	var zone: FarmZone = _visit_zone(SEED_A, 0)
	zone.spawn_enemies(SEED_A, 0, pool)
	var before: int = zone.get_enemies().size()
	zone.repopulate(SEED_A, 1, pool)
	await wait_process_frames(1)
	var fresh_pool: ObjectPool = _new_zombie_pool()
	var fresh: FarmZone = _new_zone()
	fresh.spawn_enemies(SEED_A, 1, fresh_pool)
	assert_gt(zone.get_enemies().size(), 0, "the zone has zombies again")
	assert_eq(_describe_enemies(zone), _describe_enemies(fresh), "the zombies of visit 1")
	var after: int = zone.get_enemies().size()
	assert_eq(
		pool.get_free_count(), maxi(before - after, 0), "the zombies of visit 0 were reused, none leaked"
	)


func test_r_008_09_repopulate_before_generate_reports_error() -> void:
	var pool: ObjectPool = _new_zombie_pool()
	var zone: FarmZone = _new_zone()
	zone.repopulate(SEED_A, 1, pool)
	assert_push_error("generate")
	assert_eq(zone.get_boxes().size(), 0, "no boxes were placed")
	assert_eq(zone.get_enemies().size(), 0, "no zombies were placed")


func test_r_009_10_has_one_exit_point() -> void:
	var zone: FarmZone = _new_zone()
	assert_true(zone is Zone, "the green zone is a Zone")
	var exits: Array[Node] = zone.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node is ExitPoint
	)
	assert_eq(exits.size(), 1, "one exit point")
	if exits.size() != 1:
		return
	var exit: ExitPoint = exits[0] as ExitPoint
	var spawn: Vector3 = zone.get_spawn_position()
	var distance: float = exit.global_position.distance_to(spawn)
	assert_lt(distance, 6.0, "next to the spawn point")
	var reach: float = (load("res://resources/config/controls.tres") as ControlConfigData).interaction_range_m
	assert_gt(distance, reach, "out of reach from the spawn point, so arriving does not offer leaving")


func test_r_009_12_exit_destinations() -> void:
	var zone: FarmZone = _new_zone()
	var exit: ExitPoint = zone.get_node("%ExitPoint") as ExitPoint
	assert_not_null(exit, "the zone has %ExitPoint")
	if exit == null:
		return
	assert_same(exit.destination, DataRegistry.get_base_zone(), "the green zone leads to the base")


func test_r_009_10_zone_relays_exit_request() -> void:
	var zone: FarmZone = _new_zone()
	var traveller: Node3D = Node3D.new()
	add_child_autofree(traveller)
	watch_signals(zone)
	(zone.get_node("%ExitPoint").get_node("Interactable") as InteractableComponent).interact(traveller)
	assert_signal_emit_count(zone, "exit_requested", 1, "the zone relays its exit point")
	assert_signal_emitted_with_parameters(
		zone, "exit_requested", [DataRegistry.get_base_zone(), traveller]
	)
