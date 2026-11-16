extends GutTest
## Zombies in the green zone (spec 006): a patrol point that cannot be reached
## still ends the patrol (R-006-12), the navmesh covers the playable area and
## nothing else (R-006-20), a dead zombie goes back to the pool (R-006-21),
## the spawner places the zombies of BALANCE §7.1 on hand-placed markers out
## of sight of the spawn point (R-006-23), the same for the same seed and
## visit (R-006-25) and different on another visit (R-006-26), and unloading
## returns every zombie to the pool (R-006-27).
## The zone is spawned with seeds given here, never through GameManager.

const ZONE_SCENE := preload("res://scenes/farm_zone/farm_zone_green.tscn")
const ZOMBIE_SCENE := preload("res://scenes/entities/zombie.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const ZOMBIE_AI_PATH := "res://resources/ai/zombie_ai.tres"
const FAST_PATH := "res://resources/enemies/zombie_fast.tres"
const SEED_A := 1001
const SEEDS := 30
## Physics frames the navigation map may take to synchronise (plan 006 §5.1).
const NAV_SYNC_MAX_FRAMES := 30
## The navmesh is baked for an agent this wide, so it stops this far from
## every wall and obstacle (NavigationMesh.agent_radius of the zone).
const NAV_AGENT_RADIUS := 0.5
## Horizontal error allowed when a point is expected to be on the navmesh.
const ON_NAVMESH_TOLERANCE := 0.3
const BRAIN_SEED_SEARCH := 5000
## The state is sampled every few frames: a patrol lasts far longer than this.
const POLL_FRAMES := 5


func _new_zone() -> FarmZone:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(zone)
	return zone


func _new_pool() -> ObjectPool:
	var pool: ObjectPool = ObjectPool.new()
	pool.name = "ZombiePool"
	pool.scene = ZOMBIE_SCENE
	add_child_autofree(pool)
	return pool


func _spawned_zone(world_seed: int, visit: int, pool: ObjectPool) -> FarmZone:
	var zone: FarmZone = _new_zone()
	zone.spawn_enemies(world_seed, visit, pool)
	return zone


func _marker_positions(zone: FarmZone) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for marker: Node in zone.get_node("%EnemyMarkers").get_children():
		positions.append((marker as Marker3D).global_position)
	return positions


## One "id @ position" line per zombie, in spawn order.
func _describe(zone: FarmZone) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for zombie: Zombie in zone.get_enemies():
		lines.append("%s @ %s" % [zombie.get_data().id, zombie.global_position])
	return lines


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _is_inside(zone: FarmZone, point: Vector3, margin: float) -> bool:
	var half: Vector2 = zone.data.size_m / 2.0
	return absf(point.x) <= half.x - margin and absf(point.z) <= half.y - margin


## Waits until the navigation map of the scene has synchronised its regions.
func _wait_for_navigation(zone: Node3D) -> bool:
	var map: RID = zone.get_world_3d().navigation_map
	for i: int in NAV_SYNC_MAX_FRAMES:
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			map, Vector3(-20.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), true
		)
		if path.size() >= 2:
			return true
	return false


## First patrol point a brain with this seed picks around home.
func _first_patrol_point(data: EnemyData, home: Vector3, brain_seed: int) -> Vector3:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = brain_seed
	var brain: EnemyBrain = EnemyBrain.new(data.ai, data.attack_interval, rng)
	brain.reset(home)
	brain.tick(data.ai.patrol_pause_max + 1.0, INF, false)
	return brain.get_patrol_point()


## A brain seed whose first patrol point is closer than reach to target, or -1.
func _find_brain_seed(data: EnemyData, home: Vector3, target: Vector3, reach: float) -> int:
	for brain_seed: int in BRAIN_SEED_SEARCH:
		if _flat_distance(_first_patrol_point(data, home, brain_seed), target) < reach:
			return brain_seed
	return -1


## A visit of this world seed that puts no zombie on the given marker, or -1.
func _find_visit_leaving_free(world_seed: int, marker: Vector3) -> int:
	var pool: ObjectPool = _new_pool()
	var probe: FarmZone = _new_zone()
	for visit: int in range(1, SEEDS):
		probe.spawn_enemies(world_seed, visit, pool)
		var free: bool = true
		for zombie: Zombie in probe.get_enemies():
			if zombie.global_position == marker:
				free = false
		probe.despawn_enemies()
		if free:
			return visit
	return -1


## Runs one zombie through its first patrol towards an unreachable point and
## checks that the patrol ends.
func _assert_patrol_ends(zone: FarmZone, home: Vector3, target: Vector3, reach: float) -> void:
	var data: EnemyData = load(FAST_PATH) as EnemyData
	var brain_seed: int = _find_brain_seed(data, home, target, reach)
	assert_ne(brain_seed, -1, "a brain seed sends the zombie to %s" % target)
	if brain_seed == -1:
		return
	var zombie: Zombie = ZOMBIE_SCENE.instantiate() as Zombie
	add_child_autofree(zombie)
	zombie.activate(data, home, brain_seed)
	var seconds: float = (
		data.ai.patrol_pause_max + 2.0 * data.ai.patrol_radius / data.move_speed + 1.0
	)
	var patrolled: bool = false
	var ended: bool = false
	for i: int in ceili(seconds * Engine.physics_ticks_per_second / POLL_FRAMES):
		await wait_physics_frames(POLL_FRAMES)
		if zombie.get_state() == EnemyBrain.State.PATROL:
			patrolled = true
		elif patrolled and zombie.get_state() == EnemyBrain.State.IDLE:
			ended = true
			break
	assert_true(patrolled, "the zombie went on patrol")
	assert_true(ended, "and the patrol ended although %s cannot be reached" % target)
	assert_true(
		_is_inside(zone, zombie.global_position, 0.0),
		"without leaving the zone (at %s)" % zombie.global_position
	)
	assert_gt(_flat_distance(zombie.global_position, home), 0.5, "after walking towards it")


func test_r_006_12_unreachable_patrol_point_still_cycles() -> void:
	var zone: FarmZone = _new_zone()
	var synced: bool = await _wait_for_navigation(zone)
	assert_true(synced, "the navigation map synchronised")
	if not synced:
		return
	# Inside the trunk of Tree1, from open ground north of it.
	var tree: Vector3 = (zone.get_node("Decoration/Tree1") as Node3D).global_position
	await _assert_patrol_ends(zone, tree + Vector3(0.0, 0.0, 3.0), tree, 0.3)


func test_r_006_12_patrol_point_beyond_fence_still_cycles() -> void:
	var zone: FarmZone = _new_zone()
	var synced: bool = await _wait_for_navigation(zone)
	assert_true(synced, "the navigation map synchronised")
	if not synced:
		return
	var half: Vector2 = zone.data.size_m / 2.0
	var home: Vector3 = Vector3(half.x - 2.0, 0.0, 0.0)
	await _assert_patrol_ends(zone, home, home + Vector3(4.0, 0.0, 0.0), 1.0)


func test_r_006_20_navmesh_covers_zone() -> void:
	var zone: FarmZone = _new_zone()
	var synced: bool = await _wait_for_navigation(zone)
	assert_true(synced, "the navigation map synchronised")
	if not synced:
		return
	var map: RID = zone.get_world_3d().navigation_map
	var half: Vector2 = zone.data.size_m / 2.0
	var outside: int = 0
	var step: float = 2.5
	var reach: float = maxf(half.x, half.y) + 10.0
	var x: float = -reach
	while x <= reach:
		var z: float = -reach
		while z <= reach:
			var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(x, 0.0, z))
			if not _is_inside(zone, closest, 0.0):
				outside += 1
			z += step
		x += step
	assert_eq(outside, 0, "no walkable point outside the playable area")
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var point: Vector3 = Vector3(corner.x * (half.x - 1.0), 0.0, corner.y * (half.y - 1.0))
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
		assert_lt(_flat_distance(closest, point), ON_NAVMESH_TOLERANCE, "walkable up to %s" % point)
	var blocked: int = 0
	var obstacles: Array[Node] = zone.get_node("Decoration").get_children()
	for obstacle: Node in obstacles:
		var centre: Vector3 = (obstacle as Node3D).global_position
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, centre)
		if _flat_distance(closest, centre) >= NAV_AGENT_RADIUS:
			blocked += 1
	assert_eq(blocked, obstacles.size(), "every obstacle is a hole in the navmesh")


func test_r_006_20_navmesh_is_flat() -> void:
	# No walkable islands on top of trees, rocks or fences (plan 006 §5.1).
	var zone: FarmZone = _new_zone()
	var region: NavigationRegion3D = zone.get_node("%Navigation") as NavigationRegion3D
	assert_not_null(region, "the zone has a NavigationRegion3D")
	if region == null or region.navigation_mesh == null:
		fail_test("the zone has no baked navigation mesh")
		return
	var vertices: PackedVector3Array = region.navigation_mesh.get_vertices()
	assert_gt(region.navigation_mesh.get_polygon_count(), 0, "the navmesh is baked")
	var lowest: float = INF
	var highest: float = -INF
	for vertex: Vector3 in vertices:
		lowest = minf(lowest, vertex.y)
		highest = maxf(highest, vertex.y)
	assert_almost_eq(highest, lowest, 0.01, "one walkable level")
	assert_lt(highest, 1.0, "at ground level")


func test_r_006_23_markers_out_of_sight_of_spawn() -> void:
	var zone: FarmZone = _new_zone()
	var synced: bool = await _wait_for_navigation(zone)
	assert_true(synced, "the navigation map synchronised")
	var ai: EnemyAiData = load(ZOMBIE_AI_PATH) as EnemyAiData
	var map: RID = zone.get_world_3d().navigation_map
	var spawn: Vector3 = zone.get_spawn_position()
	var markers: Array[Vector3] = _marker_positions(zone)
	assert_gt(markers.size(), zone.data.enemy_count_max, "more markers than the maximum of zombies")
	var distinct: Dictionary[Vector3, bool] = {}
	for marker: Vector3 in markers:
		distinct[marker] = true
		assert_gt(
			_flat_distance(marker, spawn),
			ai.vision_radius + ai.patrol_radius,
			"marker %s: a patrolling zombie cannot see the spawn point" % marker
		)
		assert_true(_is_inside(zone, marker, NAV_AGENT_RADIUS), "marker %s is inside" % marker)
		if synced:
			var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, marker)
			assert_lt(
				_flat_distance(closest, marker), ON_NAVMESH_TOLERANCE, "marker %s is walkable" % marker
			)
	assert_eq(distinct.size(), markers.size(), "no two markers on the same spot")


func test_r_006_23_green_zone_spawns_in_range() -> void:
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _new_zone()
	var markers: Array[Vector3] = _marker_positions(zone)
	var enemies_root: Node = zone.get_node("%Enemies")
	var counts_seen: Dictionary[int, bool] = {}
	for world_seed: int in SEEDS:
		zone.spawn_enemies(world_seed, ZombieSpawner.FIRST_VISIT, pool)
		var zombies: Array[Zombie] = zone.get_enemies()
		counts_seen[zombies.size()] = true
		assert_between(
			zombies.size(),
			zone.data.enemy_count_min,
			zone.data.enemy_count_max,
			"seed %d: zombies within BALANCE §7.1" % world_seed
		)
		var kinds: Dictionary[StringName, bool] = {}
		var used: Dictionary[Vector3, bool] = {}
		var misplaced: int = 0
		for zombie: Zombie in zombies:
			kinds[zombie.get_data().id] = true
			used[zombie.global_position] = true
			if not markers.has(zombie.global_position) or zombie.get_parent() != enemies_root:
				misplaced += 1
			if zombie.get_state() != EnemyBrain.State.IDLE or zombie.get_health().is_dead():
				misplaced += 1
		assert_eq(misplaced, 0, "seed %d: alive, idle, on markers, under %%Enemies" % world_seed)
		assert_eq(used.size(), zombies.size(), "seed %d: one zombie per marker" % world_seed)
		assert_eq(kinds.size(), 2, "seed %d: at least one slow and one fast" % world_seed)
		zone.despawn_enemies()
	assert_gt(counts_seen.size(), 1, "the number of zombies depends on the seed")


func test_r_006_23_spawning_does_not_drag_bodies_along() -> void:
	# A zombie that entered the tree at the origin and jumped to its marker
	# carried away a character standing there, like a moving platform.
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _new_zone()
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	var start: Vector3 = zone.get_spawn_position()
	robot.global_position = start
	await wait_physics_frames(2)
	zone.spawn_enemies(SEED_A, ZombieSpawner.FIRST_VISIT, pool)
	await wait_physics_frames(5)
	assert_eq(robot.global_position, start, "first spawn: the robot stays where it was")
	# Pooled zombies keep the position of their previous life: the robot now
	# stands where one was, on a marker the next spawn leaves free.
	var first_marker: Vector3 = zone.get_enemies()[0].global_position
	var next_visit: int = _find_visit_leaving_free(SEED_A, first_marker)
	assert_ne(next_visit, -1, "some visit leaves the marker at %s free" % first_marker)
	if next_visit == -1:
		return
	zone.despawn_enemies()
	robot.global_position = first_marker
	await wait_physics_frames(2)
	zone.spawn_enemies(SEED_A, next_visit, pool)
	await wait_physics_frames(5)
	assert_eq(robot.global_position, first_marker, "reused zombies do not drag it either")


func test_r_006_23_spawn_twice_reports_error() -> void:
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _spawned_zone(SEED_A, ZombieSpawner.FIRST_VISIT, pool)
	var before: PackedStringArray = _describe(zone)
	zone.spawn_enemies(SEED_A + 1, ZombieSpawner.FIRST_VISIT, pool)
	assert_push_error("already")
	assert_eq(_describe(zone), before, "the second call changes nothing")


func test_r_006_23_spawn_without_pool_reports_error() -> void:
	var zone: FarmZone = _new_zone()
	zone.spawn_enemies(SEED_A, ZombieSpawner.FIRST_VISIT, null)
	assert_push_error("pool")
	assert_eq(zone.get_enemies().size(), 0, "no pool, no zombies")


func test_r_006_25_same_seed_and_visit_same_zombies() -> void:
	var pool: ObjectPool = _new_pool()
	for world_seed: int in [SEED_A, SEED_A + 1, SEED_A + 2]:
		var first: FarmZone = _spawned_zone(world_seed, 3, pool)
		var second: FarmZone = _spawned_zone(world_seed, 3, pool)
		assert_gt(first.get_enemies().size(), 0, "the zone has zombies")
		assert_eq(_describe(first), _describe(second), "same number, kinds and positions")


func test_r_006_25_other_seed_other_zombies() -> void:
	var pool: ObjectPool = _new_pool()
	var layouts: Dictionary[String, bool] = {}
	for world_seed: int in SEEDS:
		var zone: FarmZone = _spawned_zone(world_seed, ZombieSpawner.FIRST_VISIT, pool)
		layouts[", ".join(_describe(zone))] = true
	assert_gt(layouts.size(), SEEDS / 2, "the zombies depend on the world seed")


func test_r_006_25_spawn_does_not_move_the_boxes() -> void:
	var pool: ObjectPool = _new_pool()
	var with_enemies: FarmZone = _new_zone()
	with_enemies.spawn_enemies(SEED_A, ZombieSpawner.FIRST_VISIT, pool)
	with_enemies.generate(SEED_A)
	var without: FarmZone = _new_zone()
	without.generate(SEED_A)
	var first: Array[Vector3] = []
	for box: LootBox in with_enemies.get_boxes():
		first.append(box.position)
	var second: Array[Vector3] = []
	for box: LootBox in without.get_boxes():
		second.append(box.position)
	assert_eq(first, second, "enemies use streams of their own")


func test_r_006_26_first_visit_is_zero() -> void:
	assert_eq(ZombieSpawner.FIRST_VISIT, 0, "the visit counter starts at 0 (BALANCE §7.2)")


func test_r_006_26_visit_changes_spawns() -> void:
	var pool: ObjectPool = _new_pool()
	var changed: int = 0
	var seeds: int = 10
	for world_seed: int in seeds:
		var first_visit: FarmZone = _spawned_zone(world_seed, ZombieSpawner.FIRST_VISIT, pool)
		var next_visit: FarmZone = _spawned_zone(world_seed, ZombieSpawner.FIRST_VISIT + 1, pool)
		if _describe(first_visit) != _describe(next_visit):
			changed += 1
	assert_gt(changed, seeds / 2, "a new visit spawns the zombies again, elsewhere")


func test_r_006_21_death_returns_to_pool() -> void:
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _spawned_zone(SEED_A, ZombieSpawner.FIRST_VISIT, pool)
	var spawned: int = zone.get_enemies().size()
	var victim: Zombie = zone.get_enemies()[0]
	victim.get_health().take_damage(victim.get_data().hp_max)
	await wait_physics_frames(2)
	assert_false(zone.get_enemies().has(victim), "a dead zombie leaves the active set")
	assert_eq(zone.get_enemies().size(), spawned - 1, "the others stay")
	assert_false(victim.is_inside_tree(), "it leaves the scene")
	assert_eq(pool.get_free_count(), 1, "and waits in the pool")
	zone.despawn_enemies()
	assert_eq(pool.get_free_count(), spawned, "it is not returned twice")
	assert_push_error_count(0)


func test_r_006_27_despawn_returns_all_to_pool() -> void:
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _spawned_zone(SEED_A, ZombieSpawner.FIRST_VISIT, pool)
	var zombies: Array[Zombie] = zone.get_enemies().duplicate()
	assert_gt(zombies.size(), 0, "the zone has zombies")
	assert_eq(pool.get_free_count(), 0, "all of them in use")
	zone.despawn_enemies()
	assert_eq(zone.get_enemies().size(), 0, "no active zombie left")
	assert_eq(zone.get_node("%Enemies").get_child_count(), 0, "none left in the zone")
	assert_eq(pool.get_free_count(), zombies.size(), "every zombie is back in the pool")
	for zombie: Zombie in zombies:
		assert_false(zombie.is_inside_tree(), "%s left the tree" % zombie.name)
	zone.spawn_enemies(SEED_A, ZombieSpawner.FIRST_VISIT, pool)
	assert_eq(zone.get_enemies().size(), zombies.size(), "the same visit spawns them again")
	assert_eq(pool.get_free_count(), 0, "reusing the pooled instances")
