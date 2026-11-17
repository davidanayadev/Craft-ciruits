extends GutTest
## Zombies in the green zone (spec 006): a patrol point that cannot be reached
## still ends the patrol (R-006-12), the navmesh covers the playable area and
## nothing else (R-006-20), a dead zombie goes back to the pool (R-006-21),
## the spawner places the zombies of BALANCE §7.1 on hand-placed markers out
## of sight of the spawn point (R-006-23), the same for the same seed and
## visit (R-006-25) and different on another visit (R-006-26), and unloading
## returns every zombie to the pool (R-006-27).
## The zone is spawned with seeds given here, never through GameManager.
## Spec 010: enemies killed or skipped on a visit stay out when the zone is
## populated again, and nobody else moves (R-010-32).

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
const DROP_SEED := 4321
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


## These tests check who spawns and what drops, never movement. Several of
## these zones coexist at the same place, and their identical navmeshes in one
## navigation map raise edge-merge errors when the map syncs, so the region is
## removed before the zone enters the tree (disabling it in the tree is not
## enough: the region still reaches the map).
func _spawned_zone(world_seed: int, visit: int, pool: ObjectPool) -> FarmZone:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	zone.get_node("%Navigation").free()
	add_child_autofree(zone)
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
	zombie.activate(data, home, brain_seed, DROP_SEED)
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
		zone.spawn_enemies(world_seed, ZonePopulation.FIRST_VISIT, pool)
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
	zone.spawn_enemies(SEED_A, ZonePopulation.FIRST_VISIT, pool)
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
	var zone: FarmZone = _spawned_zone(SEED_A, ZonePopulation.FIRST_VISIT, pool)
	var before: PackedStringArray = _describe(zone)
	zone.spawn_enemies(SEED_A + 1, ZonePopulation.FIRST_VISIT, pool)
	assert_push_error("already")
	assert_eq(_describe(zone), before, "the second call changes nothing")


func test_r_006_23_spawn_without_pool_reports_error() -> void:
	var zone: FarmZone = _new_zone()
	zone.spawn_enemies(SEED_A, ZonePopulation.FIRST_VISIT, null)
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
		var zone: FarmZone = _spawned_zone(world_seed, ZonePopulation.FIRST_VISIT, pool)
		layouts[", ".join(_describe(zone))] = true
	assert_gt(layouts.size(), SEEDS / 2, "the zombies depend on the world seed")


func test_r_006_25_spawn_does_not_move_the_boxes() -> void:
	var pool: ObjectPool = _new_pool()
	var with_enemies: FarmZone = _new_zone()
	with_enemies.spawn_enemies(SEED_A, ZonePopulation.FIRST_VISIT, pool)
	with_enemies.generate(SEED_A, ZonePopulation.FIRST_VISIT)
	var without: FarmZone = _new_zone()
	without.generate(SEED_A, ZonePopulation.FIRST_VISIT)
	var first: Array[Vector3] = []
	for box: LootBox in with_enemies.get_boxes():
		first.append(box.position)
	var second: Array[Vector3] = []
	for box: LootBox in without.get_boxes():
		second.append(box.position)
	assert_eq(first, second, "enemies use streams of their own")


func test_r_006_26_first_visit_is_zero() -> void:
	assert_eq(ZonePopulation.FIRST_VISIT, 0, "the visit counter starts at 0 (BALANCE §7.2)")


func test_r_006_26_visit_changes_spawns() -> void:
	var pool: ObjectPool = _new_pool()
	var changed: int = 0
	var seeds: int = 10
	for world_seed: int in seeds:
		var first_visit: FarmZone = _spawned_zone(world_seed, ZonePopulation.FIRST_VISIT, pool)
		var next_visit: FarmZone = _spawned_zone(world_seed, ZonePopulation.FIRST_VISIT + 1, pool)
		if _describe(first_visit) != _describe(next_visit):
			changed += 1
	assert_gt(changed, seeds / 2, "a new visit spawns the zombies again, elsewhere")


func test_r_006_21_death_returns_to_pool() -> void:
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _spawned_zone(SEED_A, ZonePopulation.FIRST_VISIT, pool)
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
	var zone: FarmZone = _spawned_zone(SEED_A, ZonePopulation.FIRST_VISIT, pool)
	var zombies: Array[Zombie] = zone.get_enemies().duplicate()
	assert_gt(zombies.size(), 0, "the zone has zombies")
	assert_eq(pool.get_free_count(), 0, "all of them in use")
	zone.despawn_enemies()
	assert_eq(zone.get_enemies().size(), 0, "no active zombie left")
	assert_eq(zone.get_node("%Enemies").get_child_count(), 0, "none left in the zone")
	assert_eq(pool.get_free_count(), zombies.size(), "every zombie is back in the pool")
	for zombie: Zombie in zombies:
		assert_false(zombie.is_inside_tree(), "%s left the tree" % zombie.name)
	zone.spawn_enemies(SEED_A, ZonePopulation.FIRST_VISIT, pool)
	assert_eq(zone.get_enemies().size(), zombies.size(), "the same visit spawns them again")
	assert_eq(pool.get_free_count(), 0, "reusing the pooled instances")


## Spec 008: drops depend on world seed, visit and spawn index (R-008-36).
const KILLER_UID := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const DROP_SEEDS: Array[int] = [1001, 1002, 1003, 1004]
const DROP_VISITS := 8


func _spawn_order(count: int, reversed: bool) -> Array[int]:
	var order: Array[int] = []
	for i: int in count:
		order.append(count - 1 - i if reversed else i)
	return order


func _dropped_text(zombie: Zombie) -> String:
	if get_signal_emit_count(zombie, "loot_dropped") == 0:
		return ""
	var parameters: Array = get_signal_parameters(zombie, "loot_dropped")
	var stacks: Array[ItemStack] = parameters[0]
	var parts: PackedStringArray = PackedStringArray()
	for stack: ItemStack in stacks:
		parts.append("%s x%d" % [stack.item.id, stack.quantity])
	return ", ".join(parts)


## Kills the zombies in the given order of spawn indices as a player and returns
## what each one dropped, by spawn index.
func _kill_in_order(zombies: Array[Zombie], order: Array[int]) -> PackedStringArray:
	var loot: PackedStringArray = PackedStringArray()
	loot.resize(zombies.size())
	for zombie: Zombie in zombies:
		watch_signals(zombie)
	for i: int in order:
		zombies[i].get_hurtbox().receive_attack(zombies[i].get_data().hp_max, KILLER_UID)
		loot[i] = _dropped_text(zombies[i])
	return loot


func _loot_by_index(zone: FarmZone, reversed: bool) -> PackedStringArray:
	var zombies: Array[Zombie] = zone.get_enemies().duplicate()
	return _kill_in_order(zombies, _spawn_order(zombies.size(), reversed))


func _count_droppers(loot: PackedStringArray) -> int:
	var droppers: int = 0
	for text: String in loot:
		if not text.is_empty():
			droppers += 1
	return droppers


func test_r_008_36_drop_independent_of_kill_order() -> void:
	var pool: ObjectPool = _new_pool()
	var total_drops: int = 0
	for world_seed: int in DROP_SEEDS:
		var forward: PackedStringArray = _loot_by_index(_spawned_zone(world_seed, 2, pool), false)
		var backward: PackedStringArray = _loot_by_index(_spawned_zone(world_seed, 2, pool), true)
		assert_gt(forward.size(), 0, "seed %d: the zone has zombies" % world_seed)
		assert_eq(forward, backward, "seed %d: same loot per spawn index in any order" % world_seed)
		total_drops += _count_droppers(forward)
	assert_gt(total_drops, 0, "some zombies dropped something, so the comparison means something")
	await wait_physics_frames(2)


func test_r_008_36_drop_changes_with_visit() -> void:
	var pool: ObjectPool = _new_pool()
	var patterns: Dictionary[String, bool] = {}
	for visit: int in DROP_VISITS:
		var loot: PackedStringArray = _loot_by_index(_spawned_zone(SEED_A, visit, pool), false)
		var pattern: PackedStringArray = PackedStringArray()
		for text: String in loot:
			pattern.append("1" if not text.is_empty() else "0")
		patterns["".join(pattern)] = true
	assert_gt(patterns.size(), 1, "the zombies that drop are not the same on every visit")
	await wait_physics_frames(2)


func test_r_008_36_zone_relays_loot_once() -> void:
	var pool: ObjectPool = _new_pool()
	var droppers: int = 0
	var emitted: int = 0
	for world_seed: int in DROP_SEEDS:
		var zone: FarmZone = _spawned_zone(world_seed, 1, pool)
		watch_signals(zone)
		var loot: PackedStringArray = _loot_by_index(zone, false)
		droppers += _count_droppers(loot)
		emitted += get_signal_emit_count(zone, "enemy_loot_dropped")
	assert_gt(droppers, 0, "some zombies dropped something")
	assert_eq(emitted, droppers, "one enemy_loot_dropped per dropping zombie")
	await wait_physics_frames(2)


func test_r_008_36_relay_carries_stacks_and_position() -> void:
	var pool: ObjectPool = _new_pool()
	for world_seed: int in DROP_SEEDS:
		var zone: FarmZone = _spawned_zone(world_seed, 1, pool)
		watch_signals(zone)
		var zombies: Array[Zombie] = zone.get_enemies().duplicate()
		var loot: PackedStringArray = _kill_in_order(zombies, _spawn_order(zombies.size(), false))
		var seen: int = 0
		for i: int in zombies.size():
			if loot[i].is_empty():
				continue
			var own: Array = get_signal_parameters(zombies[i], "loot_dropped")
			var relayed: Array = get_signal_parameters(zone, "enemy_loot_dropped", seen)
			var own_stacks: Array[ItemStack] = own[0]
			var relayed_stacks: Array[ItemStack] = relayed[0]
			var own_at: Vector3 = own[1]
			var relayed_at: Vector3 = relayed[1]
			assert_same(relayed_stacks, own_stacks, "the same stacks")
			assert_eq(relayed_at, own_at, "from the same place")
			seen += 1
	await wait_physics_frames(2)


func test_r_008_36_reused_zombie_drops_once_per_death() -> void:
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _spawned_zone(SEED_A, 1, pool)
	zone.despawn_enemies()
	zone.spawn_enemies(SEED_A, 2, pool)
	watch_signals(zone)
	var loot: PackedStringArray = _loot_by_index(zone, false)
	await wait_physics_frames(2)
	var emitted: int = get_signal_emit_count(zone, "enemy_loot_dropped")
	assert_eq(
		emitted,
		_count_droppers(loot),
		"a zombie of a previous spawn does not announce its loot twice"
	)
	assert_push_error_count(0)


## Spec 010 (R-010-32): dead enemies are not placed again; the others keep what
## their own seeds gave them.
const SKIPPED: Array[int] = [0, 2]
const SEED_VISIT := 1


func _spawner_of(zone: FarmZone) -> ZombieSpawner:
	return zone.get_node("%ZombieSpawner") as ZombieSpawner


func _kill(zombie: Zombie) -> void:
	zombie.get_hurtbox().receive_attack(zombie.get_data().hp_max, KILLER_UID)


func _zone_skipping(world_seed: int, visit: int, pool: ObjectPool, dead: Array[int]) -> FarmZone:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	zone.get_node("%Navigation").free()
	add_child_autofree(zone)
	zone.spawn_enemies(world_seed, visit, pool, dead)
	return zone


func test_r_010_32_skipped_keep_other_seeds() -> void:
	var pool: ObjectPool = _new_pool()
	var dead: Array[int] = SKIPPED.duplicate()
	for world_seed: int in DROP_SEEDS:
		var full: FarmZone = _spawned_zone(world_seed, SEED_VISIT, pool)
		var full_zombies: Array[Zombie] = full.get_enemies().duplicate()
		var highest_skipped: int = SKIPPED.max()
		assert_gt(full_zombies.size(), highest_skipped, "seed %d: enough zombies" % world_seed)
		var kept_indices: Array[int] = []
		var expected_lines: PackedStringArray = PackedStringArray()
		var full_lines: PackedStringArray = _describe(full)
		for i: int in full_zombies.size():
			if not SKIPPED.has(i):
				kept_indices.append(i)
				expected_lines.append(full_lines[i])
		var full_loot: PackedStringArray = _kill_in_order(
			full_zombies, _spawn_order(full_zombies.size(), false)
		)
		var partial: FarmZone = _zone_skipping(world_seed, SEED_VISIT, pool, dead)
		assert_eq(_describe(partial), expected_lines, "seed %d: same zombies minus skipped" % world_seed)
		var partial_zombies: Array[Zombie] = partial.get_enemies().duplicate()
		var partial_loot: PackedStringArray = _kill_in_order(
			partial_zombies, _spawn_order(partial_zombies.size(), false)
		)
		for k: int in kept_indices.size():
			assert_eq(
				partial_loot[k], full_loot[kept_indices[k]], "seed %d: same drop of index %d" % [world_seed, kept_indices[k]]
			)
	await wait_physics_frames(2)


func test_r_010_32_dead_indices_are_skipped_plus_killed() -> void:
	var pool: ObjectPool = _new_pool()
	var dead: Array[int] = [2]
	var zone: FarmZone = _zone_skipping(SEED_A, SEED_VISIT, pool, dead)
	var spawner: ZombieSpawner = _spawner_of(zone)
	assert_eq(spawner.get_dead_indices(), [2] as Array[int], "only the skipped one at first")
	var full: FarmZone = _spawned_zone(SEED_A, SEED_VISIT, pool)
	var full_lines: PackedStringArray = _describe(full)
	full.despawn_enemies()
	# Spawn index 2 was skipped, so the placed zombies are 0, 1, 3 and 4.
	var placed: Array[Zombie] = zone.get_enemies().duplicate()
	assert_eq(placed.size(), full_lines.size() - 1, "one zombie less")
	_kill(placed[3])
	_kill(placed[0])
	await wait_physics_frames(2)
	assert_eq(
		spawner.get_dead_indices(), [0, 2, 4] as Array[int], "sorted, no repeats, spawn indices"
	)


func test_r_010_32_despawn_clears_dead_indices() -> void:
	var pool: ObjectPool = _new_pool()
	var dead: Array[int] = [1]
	var zone: FarmZone = _zone_skipping(SEED_A, SEED_VISIT, pool, dead)
	var spawner: ZombieSpawner = _spawner_of(zone)
	zone.despawn_enemies()
	assert_eq(spawner.get_dead_indices(), [] as Array[int], "nothing remembered after despawn")
	zone.spawn_enemies(SEED_A, SEED_VISIT, pool)
	assert_eq(spawner.get_dead_indices(), [] as Array[int], "a clean spawn has none dead")


## FarmZone round trip of a visit (spec 010, R-010-27, R-010-32).
func _populated_zone(world_seed: int, visit: int, pool: ObjectPool, state: Dictionary) -> FarmZone:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	zone.get_node("%Navigation").free()
	add_child_autofree(zone)
	zone.populate(world_seed, visit, pool, state)
	return zone


func test_r_010_32_zone_exposes_its_visit() -> void:
	var pool: ObjectPool = _new_pool()
	var generated: FarmZone = _new_zone()
	generated.generate(SEED_A, 3)
	assert_eq(generated.get_visit(), 3, "the visit given to generate()")
	generated.repopulate(SEED_A, 5, pool)
	assert_eq(generated.get_visit(), 5, "the visit given to repopulate()")


func test_r_010_32_visit_state_lists_dead_and_no_closed_boxes() -> void:
	var pool: ObjectPool = _new_pool()
	var zone: FarmZone = _populated_zone(SEED_A, SEED_VISIT, pool, {})
	var closed_state: Dictionary = zone.get_visit_state()
	var no_boxes: Array = closed_state["boxes"]
	var no_dead: Array = closed_state["dead_enemies"]
	assert_eq(no_boxes.size(), 0, "closed boxes are not saved")
	assert_eq(no_dead.size(), 0, "nobody dead yet")
	var victim: Zombie = zone.get_enemies()[1]
	_kill(victim)
	await wait_physics_frames(2)
	var state: Dictionary = zone.get_visit_state()
	var dead: Array = state["dead_enemies"]
	assert_eq(dead, [1], "the killed zombie, by spawn index")


func test_r_010_32_populate_without_state_equals_generate_and_spawn() -> void:
	var pool: ObjectPool = _new_pool()
	var plain: FarmZone = _new_zone()
	plain.get_node("%Navigation").free()
	plain.generate(SEED_A, 2)
	plain.spawn_enemies(SEED_A, 2, pool)
	var populated: FarmZone = _populated_zone(SEED_A, 2, pool, {})
	assert_eq(_describe(populated), _describe(plain), "same zombies")
	assert_eq(populated.get_boxes().size(), plain.get_boxes().size(), "same boxes")
	assert_eq(populated.get_visit(), 2, "populate gives the visit")
