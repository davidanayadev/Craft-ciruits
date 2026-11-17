class_name ZonePopulation
extends RefCounted
## What a zone is filled with when it is generated (spec 004) and which
## enemies each visit puts in it (spec 006). Pure rules: the RNG comes by
## parameter, so the same seed always gives the same zone.

## Visit number of a zone nobody died in or left yet (BALANCE §7.2).
const FIRST_VISIT := 0


## One enemy to place: which kind on which marker.
class EnemySpawn:
	extends RefCounted
	var marker_index: int
	var enemy: EnemyData

	func _init(spawn_marker_index: int, spawn_enemy: EnemyData) -> void:
		marker_index = spawn_marker_index
		enemy = spawn_enemy


## Number of boxes in [min_count, max_count], then that many distinct marker
## indices, sorted ascending. Fewer markers than max_count → push_error and at
## most one box per marker. Invalid range → push_error and no boxes.
static func pick_box_markers(
	marker_count: int, min_count: int, max_count: int, rng: RandomNumberGenerator
) -> Array[int]:
	var picked: Array[int] = []
	if min_count < 0 or min_count > max_count:
		push_error("ZonePopulation: invalid box count range %d-%d." % [min_count, max_count])
		return picked
	if marker_count < max_count:
		push_error(
			"ZonePopulation: %d box markers for up to %d boxes." % [marker_count, max_count]
		)
	var count: int = mini(rng.randi_range(min_count, max_count), marker_count)
	picked = _pick_distinct(marker_count, count, rng)
	picked.sort()
	return picked


## Number of enemies in [min_count, max_count], each on a marker of its own,
## sorted by marker index. Every entry gets its min_count first; each of the
## rest goes to an entry by weight. Invalid range, fewer markers than
## max_count or invalid entries → push_error and no enemies.
## The order of the RNG calls is a contract with saved worlds: count, markers,
## kind of each of the rest, then the shuffle of kinds over markers.
static func pick_enemy_spawns(
	marker_count: int,
	min_count: int,
	max_count: int,
	entries: Array[EnemySpawnEntryData],
	rng: RandomNumberGenerator
) -> Array[EnemySpawn]:
	var spawns: Array[EnemySpawn] = []
	var problem: String = _find_enemy_spawn_problem(marker_count, min_count, max_count, entries)
	if not problem.is_empty():
		push_error("ZonePopulation: %s." % problem)
		return spawns
	var count: int = rng.randi_range(min_count, max_count)
	var markers: Array[int] = _pick_distinct(marker_count, count, rng)
	var kinds: Array[EnemyData] = _pick_enemy_kinds(count, entries, rng)
	var order: Array[int] = _pick_distinct(count, count, rng)
	for i: int in count:
		spawns.append(EnemySpawn.new(markers[i], kinds[order[i]]))
	spawns.sort_custom(_by_marker_index)
	return spawns


## count distinct indices of [0, total), in random order.
## Partial Fisher-Yates with the given RNG: Array.shuffle() uses the global one.
static func _pick_distinct(total: int, count: int, rng: RandomNumberGenerator) -> Array[int]:
	var indices: Array[int] = []
	for i: int in total:
		indices.append(i)
	for i: int in count:
		var other: int = rng.randi_range(i, total - 1)
		var swapped: int = indices[i]
		indices[i] = indices[other]
		indices[other] = swapped
	return indices.slice(0, count)


## Empty when the data is valid; otherwise what is wrong with it.
static func _find_enemy_spawn_problem(
	marker_count: int, min_count: int, max_count: int, entries: Array[EnemySpawnEntryData]
) -> String:
	if min_count < 0 or min_count > max_count:
		return "invalid enemy count range %d-%d" % [min_count, max_count]
	if marker_count < max_count:
		return "%d enemy markers for up to %d enemies" % [marker_count, max_count]
	var guaranteed: int = 0
	var total_weight: int = 0
	for i: int in entries.size():
		var entry: EnemySpawnEntryData = entries[i]
		if entry == null or entry.enemy == null:
			return "enemy spawn entry %d has no enemy" % i
		if entry.min_count < 0 or entry.weight < 0:
			return "enemy spawn entry %d has a negative min_count or weight" % i
		guaranteed += entry.min_count
		total_weight += entry.weight
	if guaranteed > min_count:
		return "%d guaranteed enemies for a minimum of %d" % [guaranteed, min_count]
	if total_weight == 0 and max_count > guaranteed:
		return "no enemy spawn entry has a weight to share out up to %d enemies" % max_count
	return ""


static func _pick_enemy_kinds(
	count: int, entries: Array[EnemySpawnEntryData], rng: RandomNumberGenerator
) -> Array[EnemyData]:
	var kinds: Array[EnemyData] = []
	var total_weight: int = 0
	for entry: EnemySpawnEntryData in entries:
		total_weight += entry.weight
		for i: int in entry.min_count:
			kinds.append(entry.enemy)
	while kinds.size() < count:
		kinds.append(_pick_by_weight(entries, rng.randi_range(1, total_weight)))
	return kinds


## The entry whose share holds the roll, a number in [1, total weight].
static func _pick_by_weight(entries: Array[EnemySpawnEntryData], roll: int) -> EnemyData:
	var reached: int = 0
	for entry: EnemySpawnEntryData in entries:
		reached += entry.weight
		if roll <= reached:
			return entry.enemy
	return null


static func _by_marker_index(a: EnemySpawn, b: EnemySpawn) -> bool:
	return a.marker_index < b.marker_index
