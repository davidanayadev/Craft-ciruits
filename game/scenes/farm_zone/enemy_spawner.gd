class_name EnemySpawner
extends Node3D
## Puts the zombies of a visit in a zone and takes them back (spec 006).
## How many, of which kind and on which marker comes from the enemy_spawn
## stream; the brain seed of each enemy from the enemy_brain stream, in the
## order they are placed. Both use the visit as index, so a new visit spawns
## them again elsewhere, and changing the AI never moves where they appear.
## The drop seed of each enemy comes from the enemy_drop stream, the visit
## and its place in the spawn order (spec 008).
## Zombies come from a pool that outlives the zone and go back to it when they
## die or when the zone is unloaded.
## It remembers which spawn indices of the visit are dead, so a saved visit
## comes back without them (spec 010, R-010-32).

## A enemy of this spawner left loot where it died (spec 008).
signal enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3)

## Parent of the zombies while they are active.
@export var enemies_root: Node3D

var _active: Array[Enemy] = []
var _pool: ObjectPool
## Spawn index of each active enemy.
var _spawn_indices: Dictionary[Enemy, int] = {}
## Indices of this visit that were skipped or killed.
var _dead: Array[int] = []


## Places the zombies of this visit on the markers but dead_indices, which
## roll no drop; their brain seed is still drawn, so the others keep theirs.
## Missing zone data, pool or enemies_root, or zombies still active →
## push_error, no change.
func spawn(
	zone: ZoneData,
	markers: Array[Node],
	world_seed: int,
	visit: int,
	pool: ObjectPool,
	dead_indices: Array[int] = []
) -> void:
	if zone == null or pool == null or enemies_root == null:
		push_error("EnemySpawner '%s': spawn() needs zone data, a pool and enemies_root." % name)
		return
	if not _active.is_empty():
		push_error("EnemySpawner '%s': zombies were already spawned; despawn them first." % name)
		return
	_pool = pool
	var spawn_rng: RandomNumberGenerator = SeededRng.create(
		world_seed, zone.zone_id, SeededRng.STREAM_ENEMY_SPAWN, visit
	)
	var brain_rng: RandomNumberGenerator = SeededRng.create(
		world_seed, zone.zone_id, SeededRng.STREAM_ENEMY_BRAIN, visit
	)
	var spawns: Array[ZonePopulation.EnemySpawn] = ZonePopulation.pick_enemy_spawns(
		markers.size(), zone.enemy_count_min, zone.enemy_count_max, zone.enemy_spawns, spawn_rng
	)
	_dead.clear()
	for i: int in spawns.size():
		var brain_seed: int = brain_rng.randi()
		if dead_indices.has(i):
			_mark_dead(i)
			continue
		var drop_seed: int = SeededRng.derive_seed_for_visit(
			world_seed, zone.zone_id, SeededRng.STREAM_ENEMY_DROP, visit, i
		)
		var marker: Marker3D = markers[spawns[i].marker_index] as Marker3D
		_place(spawns[i], marker, brain_seed, drop_seed, i)


## Returns every active enemy to the pool (R-006-27); the visit is over.
func despawn_all() -> void:
	for enemy: Enemy in _active:
		_release(enemy)
	_active.clear()
	_dead.clear()


## Skipped plus killed in this visit, sorted.
func get_dead_indices() -> Array[int]:
	var dead: Array[int] = _dead.duplicate()
	dead.sort()
	return dead


func get_active() -> Array[Enemy]:
	return _active


func _place(
	enemy_spawn: ZonePopulation.EnemySpawn,
	marker: Marker3D,
	brain_seed: int,
	drop_seed: int,
	spawn_index: int
) -> void:
	if marker == null:
		push_error(
			"EnemySpawner '%s': enemy marker %d is not a Marker3D."
			% [name, enemy_spawn.marker_index]
		)
		return
	var instance: Node = _pool.acquire()
	var enemy: Enemy = instance as Enemy
	if enemy == null:
		push_error("EnemySpawner '%s': the pool '%s' does not hold zombies." % [name, _pool.name])
		if instance != null:
			_pool.release(instance)
		return
	# In place before it enters the tree: a body that enters somewhere else and
	# jumps to its marker in the same frame drags along, as a moving platform
	# would, any character it was overlapping (the robot, at the zone's origin).
	enemy.position = enemies_root.to_local(marker.global_position)
	enemies_root.add_child(enemy)
	enemy.activate(enemy_spawn.enemy, marker.global_position, brain_seed, drop_seed)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.loot_dropped.connect(_on_enemy_loot_dropped)
	_active.append(enemy)
	_spawn_indices[enemy] = spawn_index


func _release(enemy: Enemy) -> void:
	enemy.defeated.disconnect(_on_enemy_defeated)
	enemy.loot_dropped.disconnect(_on_enemy_loot_dropped)
	_spawn_indices.erase(enemy)
	_pool.release(enemy)


func _mark_dead(spawn_index: int) -> void:
	if not _dead.has(spawn_index):
		_dead.append(spawn_index)


func _on_enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3) -> void:
	enemy_loot_dropped.emit(stacks, world_position)


func _on_enemy_defeated(enemy: Enemy) -> void:
	if _spawn_indices.has(enemy):
		_mark_dead(_spawn_indices[enemy])
	# Deferred: died arrives in the middle of a physics step, and taking the
	# body out of the tree there removes it from the physics space mid-step.
	_return_defeated.call_deferred(enemy)


func _return_defeated(enemy: Enemy) -> void:
	# The zone may have been despawned between the death and this call.
	if not _active.has(enemy):
		return
	_active.erase(enemy)
	_release(enemy)
