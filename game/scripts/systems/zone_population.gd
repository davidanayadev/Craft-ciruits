class_name ZonePopulation
extends RefCounted
## What a zone is filled with when it is generated (spec 004), on which box
## markers each visit puts its boxes (spec 013) and which enemies (spec 006).
## Pure rules: the RNG comes by parameter, so the same seed always gives the
## same zone.

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


## Number of boxes in [min_count, max_count], then that many distinct markers
## with at most max_per_site in each site (spec 013). site_marker_counts[i] is
## the number of markers of site i; markers are numbered flat, site by site
## (FarmZone). Returns flat indices sorted ascending.
## Sites that hold fewer than max_count under max_per_site → push_error and at
## most what fits. Invalid range, max_per_site < 1 or a negative site count →
## push_error and no boxes.
## The order of the RNG calls is a contract with saved worlds: the count, then
## a full permutation of the markers walked in order, taking each marker whose
## site is not full yet (plan 013 D2).
static func pick_box_markers(
	site_marker_counts: Array[int],
	min_count: int,
	max_count: int,
	max_per_site: int,
	rng: RandomNumberGenerator
) -> Array[int]:
	var picked: Array[int] = []
	var problem: String = _find_box_site_problem(site_marker_counts, min_count, max_count, max_per_site)
	if not problem.is_empty():
		push_error("ZonePopulation: %s." % problem)
		return picked
	var site_of_marker: Array[int] = _site_of_each_marker(site_marker_counts)
	var capacity: int = _box_capacity(site_marker_counts, max_per_site)
	if capacity < max_count:
		push_error(
			"ZonePopulation: box sites hold %d boxes under %d per site, for up to %d boxes."
			% [capacity, max_per_site, max_count]
		)
	var count: int = mini(rng.randi_range(min_count, max_count), capacity)
	var order: Array[int] = _pick_distinct(site_of_marker.size(), site_of_marker.size(), rng)
	picked = _take_within_sites(order, site_of_marker, site_marker_counts.size(), max_per_site, count)
	picked.sort()
	return picked


## Site index of each flat marker index.
static func _site_of_each_marker(site_marker_counts: Array[int]) -> Array[int]:
	var site_of_marker: Array[int] = []
	for site: int in site_marker_counts.size():
		for i: int in site_marker_counts[site]:
			site_of_marker.append(site)
	return site_of_marker


## Boxes the sites hold under max_per_site.
static func _box_capacity(site_marker_counts: Array[int], max_per_site: int) -> int:
	var capacity: int = 0
	for markers: int in site_marker_counts:
		capacity += mini(markers, max_per_site)
	return capacity


## The first count markers of order whose site is not full yet.
static func _take_within_sites(
	order: Array[int], site_of_marker: Array[int], site_count: int, max_per_site: int, count: int
) -> Array[int]:
	var taken: Array[int] = []
	var boxes_per_site: Array[int] = []
	boxes_per_site.resize(site_count)
	boxes_per_site.fill(0)
	for marker: int in order:
		if taken.size() == count:
			break
		if boxes_per_site[site_of_marker[marker]] < max_per_site:
			boxes_per_site[site_of_marker[marker]] += 1
			taken.append(marker)
	return taken


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


## Empty when the box data is valid; otherwise what is wrong with it.
static func _find_box_site_problem(
	site_marker_counts: Array[int], min_count: int, max_count: int, max_per_site: int
) -> String:
	if min_count < 0 or min_count > max_count:
		return "invalid box count range %d-%d" % [min_count, max_count]
	if max_per_site < 1:
		return "invalid maximum of %d boxes per site" % max_per_site
	for site: int in site_marker_counts.size():
		if site_marker_counts[site] < 0:
			return "box site %d has %d markers" % [site, site_marker_counts[site]]
	return ""


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
