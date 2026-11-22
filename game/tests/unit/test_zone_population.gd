extends GutTest
## ZonePopulation (spec 013, R-013-04, R-013-05; replaces R-004-21): how many
## boxes a zone gets and on which of its hand-placed markers, grouped in sites
## with a per-site maximum, decided only by the RNG it is given.
## Enemies (spec 006): how many, of which kind and on which marker (R-006-23),
## the same for the same RNG (R-006-25). The numbers here are test inputs; the
## values of the green zone are checked in test_zone_resources.gd.

const MARKERS := 10
## Markers of each site, as the green zone has them (BALANCE §7.1).
const SITE_MARKERS: Array[int] = [4, 3, 4, 4, 3, 3]
const MAX_PER_SITE := 2
const MIN_BOXES := 5
const MAX_BOXES := 7
const SEEDS := 100
const MIN_ENEMIES := 5
const MAX_ENEMIES := 8


func _new_rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func _new_entry(id: StringName, weight: int, min_count: int) -> EnemySpawnEntryData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	var entry: EnemySpawnEntryData = EnemySpawnEntryData.new()
	entry.enemy = enemy
	entry.weight = weight
	entry.min_count = min_count
	return entry


## Two kinds, one of each guaranteed and the rest split evenly.
func _new_entries() -> Array[EnemySpawnEntryData]:
	return [_new_entry(&"slow", 1, 1), _new_entry(&"fast", 1, 1)]


func _pick(
	entries: Array[EnemySpawnEntryData], rng_seed: int
) -> Array[ZonePopulation.EnemySpawn]:
	return ZonePopulation.pick_enemy_spawns(
		MARKERS, MIN_ENEMIES, MAX_ENEMIES, entries, _new_rng(rng_seed)
	)


func _count_of(spawns: Array[ZonePopulation.EnemySpawn], id: StringName) -> int:
	var count: int = 0
	for spawn: ZonePopulation.EnemySpawn in spawns:
		if spawn.enemy.id == id:
			count += 1
	return count


func _describe(spawns: Array[ZonePopulation.EnemySpawn]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for spawn: ZonePopulation.EnemySpawn in spawns:
		lines.append("%d:%s" % [spawn.marker_index, spawn.enemy.id])
	return lines


func _pick_boxes(rng_seed: int) -> Array[int]:
	return ZonePopulation.pick_box_markers(
		SITE_MARKERS, MIN_BOXES, MAX_BOXES, MAX_PER_SITE, _new_rng(rng_seed)
	)


## Site of each flat marker index, sites in order (FarmZone, plan 013 D1).
func _site_of_markers(site_markers: Array[int]) -> Array[int]:
	var sites: Array[int] = []
	for site: int in site_markers.size():
		for i: int in site_markers[site]:
			sites.append(site)
	return sites


func _boxes_per_site(picked: Array[int], site_markers: Array[int]) -> Array[int]:
	var site_of: Array[int] = _site_of_markers(site_markers)
	var per_site: Array[int] = []
	per_site.resize(site_markers.size())
	per_site.fill(0)
	for marker: int in picked:
		per_site[site_of[marker]] += 1
	return per_site


func test_r_013_04_count_in_range() -> void:
	var counts_seen: Dictionary[int, bool] = {}
	var out_of_range: int = 0
	for rng_seed: int in SEEDS:
		var picked: Array[int] = _pick_boxes(rng_seed)
		counts_seen[picked.size()] = true
		if picked.size() < MIN_BOXES or picked.size() > MAX_BOXES:
			out_of_range += 1
	assert_eq(out_of_range, 0, "the number of boxes is always inside the range")
	assert_eq(counts_seen.size(), MAX_BOXES - MIN_BOXES + 1, "every count of the range comes up")


func test_r_013_04_at_most_max_per_site() -> void:
	var over: int = 0
	var full_sites: int = 0
	for rng_seed: int in SEEDS:
		for boxes: int in _boxes_per_site(_pick_boxes(rng_seed), SITE_MARKERS):
			if boxes > MAX_PER_SITE:
				over += 1
			elif boxes == MAX_PER_SITE:
				full_sites += 1
	assert_eq(over, 0, "no site holds more than %d boxes" % MAX_PER_SITE)
	assert_gt(full_sites, 0, "sites do reach the maximum")


func test_r_013_04_distinct_sorted_markers() -> void:
	var markers_seen: Dictionary[int, bool] = {}
	var misplaced: int = 0
	var marker_count: int = _site_of_markers(SITE_MARKERS).size()
	for rng_seed: int in SEEDS:
		var picked: Array[int] = _pick_boxes(rng_seed)
		for i: int in picked.size():
			markers_seen[picked[i]] = true
			if picked[i] < 0 or picked[i] >= marker_count:
				misplaced += 1
			elif i > 0 and picked[i] <= picked[i - 1]:
				misplaced += 1
	assert_eq(misplaced, 0, "marker indices are valid, ascending and without repeats")
	assert_eq(markers_seen.size(), marker_count, "every marker is used by some seed")


func test_r_013_05_same_rng_same_markers() -> void:
	assert_eq(_pick_boxes(42), _pick_boxes(42), "the same RNG seed gives the same boxes")


func test_r_013_05_known_answer() -> void:
	# Pins which markers each RNG seed gives. The box layout of saved worlds
	# depends on it (BALANCE §7.2), so a refactor must not move it.
	var expected: Dictionary[int, Array] = {
		42: [1, 2, 13, 15, 16, 18, 19],
		7: [2, 5, 7, 9, 12, 13, 20],
		20261115: [0, 2, 7, 8, 11, 13],
	}
	for rng_seed: int in expected:
		var known: Array[int] = []
		known.assign(expected[rng_seed])
		assert_eq(_pick_boxes(rng_seed), known, "markers of RNG seed %d" % rng_seed)


func test_r_013_05_sites_too_small_reports_error() -> void:
	# Capacity under a maximum of 2 per site: 1 + 1 + 2 = 4 boxes.
	var small_sites: Array[int] = [1, 1, 3]
	var picked: Array[int] = ZonePopulation.pick_box_markers(
		small_sites, MIN_BOXES, MAX_BOXES, MAX_PER_SITE, _new_rng(1)
	)
	assert_push_error("sites")
	assert_eq(picked.size(), 4, "as many boxes as fit")
	for boxes: int in _boxes_per_site(picked, small_sites):
		assert_lte(boxes, MAX_PER_SITE, "and never over the per-site maximum")


func test_r_013_05_invalid_range_reports_error() -> void:
	var inverted: Array[int] = ZonePopulation.pick_box_markers(
		SITE_MARKERS, 7, 5, MAX_PER_SITE, _new_rng(1)
	)
	assert_eq(inverted.size(), 0, "no boxes with an inverted range")
	var negative: Array[int] = ZonePopulation.pick_box_markers(
		SITE_MARKERS, -1, 5, MAX_PER_SITE, _new_rng(1)
	)
	assert_eq(negative.size(), 0, "no boxes with a negative minimum")
	assert_push_error("range", "the inverted range is reported")
	assert_push_error("range", "the negative minimum is reported")


func test_r_013_05_invalid_max_per_site_reports_error() -> void:
	var picked: Array[int] = ZonePopulation.pick_box_markers(
		SITE_MARKERS, MIN_BOXES, MAX_BOXES, 0, _new_rng(1)
	)
	assert_eq(picked.size(), 0, "no boxes without a per-site maximum")
	assert_push_error("per site")


func test_r_013_05_negative_site_count_reports_error() -> void:
	var broken_sites: Array[int] = [4, -1, 4, 4]
	var picked: Array[int] = ZonePopulation.pick_box_markers(
		broken_sites, MIN_BOXES, MAX_BOXES, MAX_PER_SITE, _new_rng(1)
	)
	assert_eq(picked.size(), 0, "no boxes with a negative site")
	assert_push_error("site")


func test_r_006_23_count_in_range() -> void:
	var entries: Array[EnemySpawnEntryData] = _new_entries()
	var counts_seen: Dictionary[int, bool] = {}
	var out_of_range: int = 0
	for rng_seed: int in SEEDS:
		var count: int = _pick(entries, rng_seed).size()
		counts_seen[count] = true
		if count < MIN_ENEMIES or count > MAX_ENEMIES:
			out_of_range += 1
	assert_eq(out_of_range, 0, "the number of enemies is always inside the range")
	assert_eq(counts_seen.size(), MAX_ENEMIES - MIN_ENEMIES + 1, "every count comes up")


func test_r_006_23_at_least_one_of_each() -> void:
	var entries: Array[EnemySpawnEntryData] = _new_entries()
	var missing_kind: int = 0
	var slow_total: int = 0
	var fast_total: int = 0
	for rng_seed: int in SEEDS:
		var spawns: Array[ZonePopulation.EnemySpawn] = _pick(entries, rng_seed)
		var slow: int = _count_of(spawns, &"slow")
		var fast: int = _count_of(spawns, &"fast")
		slow_total += slow
		fast_total += fast
		if slow < 1 or fast < 1 or slow + fast != spawns.size():
			missing_kind += 1
	assert_eq(missing_kind, 0, "every roll has both kinds and nothing else")
	# Equal weights: over many seeds neither kind takes nearly everything.
	assert_gt(slow_total * 2, fast_total, "slow gets its share of the rest")
	assert_gt(fast_total * 2, slow_total, "fast gets its share of the rest")


func test_r_006_23_min_count_comes_before_weights() -> void:
	var entries: Array[EnemySpawnEntryData] = [
		_new_entry(&"slow", 0, 2), _new_entry(&"fast", 1, 0)
	]
	var wrong: int = 0
	for rng_seed: int in SEEDS:
		if _count_of(_pick(entries, rng_seed), &"slow") != 2:
			wrong += 1
	assert_eq(wrong, 0, "an entry with weight 0 appears exactly its minimum")


func test_r_006_23_distinct_markers() -> void:
	var entries: Array[EnemySpawnEntryData] = _new_entries()
	var markers_seen: Dictionary[int, bool] = {}
	var first_marker_kinds: Dictionary[StringName, bool] = {}
	var misplaced: int = 0
	for rng_seed: int in SEEDS:
		var spawns: Array[ZonePopulation.EnemySpawn] = _pick(entries, rng_seed)
		if spawns.is_empty():
			fail_test("seed %d gave no enemies" % rng_seed)
			return
		first_marker_kinds[spawns[0].enemy.id] = true
		for i: int in spawns.size():
			var index: int = spawns[i].marker_index
			markers_seen[index] = true
			if index < 0 or index >= MARKERS:
				misplaced += 1
			elif i > 0 and index <= spawns[i - 1].marker_index:
				misplaced += 1
	assert_eq(misplaced, 0, "marker indices are valid, ascending and without repeats")
	assert_eq(markers_seen.size(), MARKERS, "every marker is used by some seed")
	assert_eq(first_marker_kinds.size(), 2, "kinds are shuffled over the markers")


func test_r_006_23_invalid_data_reports_error() -> void:
	var entries: Array[EnemySpawnEntryData] = _new_entries()
	var no_entries: Array[EnemySpawnEntryData] = []
	var without_enemy: Array[EnemySpawnEntryData] = [EnemySpawnEntryData.new()]
	var empty_slot: Array[EnemySpawnEntryData] = [null]
	var negative: Array[EnemySpawnEntryData] = [_new_entry(&"slow", -1, 0)]
	var weightless: Array[EnemySpawnEntryData] = [_new_entry(&"slow", 0, 1)]
	var too_many_minimums: Array[EnemySpawnEntryData] = [
		_new_entry(&"slow", 1, 3), _new_entry(&"fast", 1, 3)
	]
	var rng: RandomNumberGenerator = _new_rng(1)
	assert_eq(
		ZonePopulation.pick_enemy_spawns(MARKERS, 8, 5, entries, rng).size(), 0, "inverted range"
	)
	assert_push_error("range")
	assert_eq(
		ZonePopulation.pick_enemy_spawns(3, MIN_ENEMIES, MAX_ENEMIES, entries, rng).size(),
		0,
		"fewer markers than the maximum"
	)
	assert_push_error("markers")
	var invalid_sets: Array[Array] = [
		no_entries, without_enemy, empty_slot, negative, weightless, too_many_minimums
	]
	for i: int in invalid_sets.size():
		var invalid: Array[EnemySpawnEntryData] = []
		invalid.assign(invalid_sets[i])
		assert_eq(_pick(invalid, 1).size(), 0, "invalid entries %d give no enemies" % i)
		assert_push_error("ZonePopulation")


func test_r_006_23_zero_enemies_is_valid() -> void:
	var no_entries: Array[EnemySpawnEntryData] = []
	var spawns: Array[ZonePopulation.EnemySpawn] = ZonePopulation.pick_enemy_spawns(
		MARKERS, 0, 0, no_entries, _new_rng(1)
	)
	assert_eq(spawns.size(), 0, "a zone without enemies is not an error")
	assert_push_error_count(0)


func test_r_006_25_same_seed_same_spawns() -> void:
	var entries: Array[EnemySpawnEntryData] = _new_entries()
	var layouts: Dictionary[String, bool] = {}
	for rng_seed: int in SEEDS:
		var first: PackedStringArray = _describe(_pick(entries, rng_seed))
		var second: PackedStringArray = _describe(_pick(entries, rng_seed))
		assert_eq(first, second, "RNG seed %d gives the same enemies twice" % rng_seed)
		layouts[", ".join(first)] = true
	assert_gt(layouts.size() * 2, SEEDS, "different seeds give different enemies")
