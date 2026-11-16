class_name ZombieSpawner
extends Node3D
## Puts the zombies of a visit in a zone and takes them back (spec 006).
## How many, of which kind and on which marker comes from the enemy_spawn
## stream; the brain seed of each zombie from the enemy_brain stream, in the
## order they are placed. Both use the visit as index, so a new visit spawns
## them again elsewhere, and changing the AI never moves where they appear.
## Zombies come from a pool that outlives the zone and go back to it when they
## die or when the zone is unloaded.

## Visit number of a zone that was never left. The caller passes it until
## spec 010 adds the per-zone visit counter (BALANCE §7.2).
const FIRST_VISIT := 0

## Parent of the zombies while they are active.
@export var enemies_root: Node3D

var _active: Array[Zombie] = []
var _pool: ObjectPool


## Places the zombies of this visit on the markers. Missing zone data, pool or
## enemies_root, or zombies still active → push_error, no change.
func spawn(
	zone: ZoneData, markers: Array[Node], world_seed: int, visit: int, pool: ObjectPool
) -> void:
	if zone == null or pool == null or enemies_root == null:
		push_error("ZombieSpawner '%s': spawn() needs zone data, a pool and enemies_root." % name)
		return
	if not _active.is_empty():
		push_error("ZombieSpawner '%s': zombies were already spawned; despawn them first." % name)
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
	for enemy_spawn: ZonePopulation.EnemySpawn in spawns:
		_place(enemy_spawn, markers[enemy_spawn.marker_index] as Marker3D, brain_rng.randi())


## Returns every active zombie to the pool (R-006-27).
func despawn_all() -> void:
	for zombie: Zombie in _active:
		_release(zombie)
	_active.clear()


func get_active() -> Array[Zombie]:
	return _active


func _place(enemy_spawn: ZonePopulation.EnemySpawn, marker: Marker3D, brain_seed: int) -> void:
	if marker == null:
		push_error(
			"ZombieSpawner '%s': enemy marker %d is not a Marker3D."
			% [name, enemy_spawn.marker_index]
		)
		return
	var instance: Node = _pool.acquire()
	var zombie: Zombie = instance as Zombie
	if zombie == null:
		push_error("ZombieSpawner '%s': the pool '%s' does not hold zombies." % [name, _pool.name])
		if instance != null:
			_pool.release(instance)
		return
	# In place before it enters the tree: a body that enters somewhere else and
	# jumps to its marker in the same frame drags along, as a moving platform
	# would, any character it was overlapping (the robot, at the zone's origin).
	zombie.position = enemies_root.to_local(marker.global_position)
	enemies_root.add_child(zombie)
	zombie.activate(enemy_spawn.enemy, marker.global_position, brain_seed)
	zombie.defeated.connect(_on_zombie_defeated)
	_active.append(zombie)


func _release(zombie: Zombie) -> void:
	zombie.defeated.disconnect(_on_zombie_defeated)
	_pool.release(zombie)


func _on_zombie_defeated(zombie: Zombie) -> void:
	# Deferred: died arrives in the middle of a physics step, and taking the
	# body out of the tree there removes it from the physics space mid-step.
	_return_defeated.call_deferred(zombie)


func _return_defeated(zombie: Zombie) -> void:
	# The zone may have been despawned between the death and this call.
	if not _active.has(zombie):
		return
	_active.erase(zombie)
	_release(zombie)
