extends GutTest
## ZonePopulation (spec 004, R-004-21): how many boxes a zone gets and on which
## of its hand-placed markers, decided only by the RNG it is given.
## Enemies (spec 006): how many, of which kind and on which marker (R-006-23),
## the same for the same RNG (R-006-25). The numbers here are test inputs; the
## values of the green zone are checked in test_zone_resources.gd.

const MARKERS := 10
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


func test_r_004_21_count_in_range() -> void:
	var counts_seen: Dictionary[int, bool] = {}
	var out_of_range: int = 0
	for rng_seed: int in SEEDS:
		var picked: Array[int] = ZonePopulation.pick_box_markers(
			MARKERS, MIN_BOXES, MAX_BOXES, _new_rng(rng_seed)
		)
		counts_seen[picked.size()] = true
		if picked.size() < MIN_BOXES or picked.size() > MAX_BOXES:
			out_of_range += 1
	assert_eq(out_of_range, 0, "the number of boxes is always inside the range")
	assert_eq(counts_seen.size(), MAX_BOXES - MIN_BOXES + 1, "every count of the range comes up")


func test_r_004_21_distinct_sorted_markers() -> void:
	var markers_seen: Dictionary[int, bool] = {}
	var misplaced: int = 0
	for rng_seed: int in SEEDS:
		var picked: Array[int] = ZonePopulation.pick_box_markers(
			MARKERS, MIN_BOXES, MAX_BOXES, _new_rng(rng_seed)
		)
		for i: int in picked.size():
			markers_seen[picked[i]] = true
			if picked[i] < 0 or picked[i] >= MARKERS:
				misplaced += 1
			elif i > 0 and picked[i] <= picked[i - 1]:
				misplaced += 1
	assert_eq(misplaced, 0, "marker indices are valid, ascending and without repeats")
	assert_eq(markers_seen.size(), MARKERS, "every marker is used by some seed")


func test_r_004_21_same_rng_same_markers() -> void:
	var first: Array[int] = ZonePopulation.pick_box_markers(
		MARKERS, MIN_BOXES, MAX_BOXES, _new_rng(42)
	)
	var second: Array[int] = ZonePopulation.pick_box_markers(
		MARKERS, MIN_BOXES, MAX_BOXES, _new_rng(42)
	)
	assert_eq(first, second, "the same RNG seed gives the same boxes")


func test_r_004_21_too_few_markers_reports_error() -> void:
	var picked: Array[int] = ZonePopulation.pick_box_markers(3, MIN_BOXES, MAX_BOXES, _new_rng(1))
	var every_marker: Array[int] = [0, 1, 2]
	assert_eq(picked, every_marker, "at most one box per marker")
	assert_push_error("markers")


func test_r_004_21_invalid_range_reports_error() -> void:
	var picked: Array[int] = ZonePopulation.pick_box_markers(MARKERS, 7, 5, _new_rng(1))
	assert_eq(picked.size(), 0, "no boxes with an inverted range")
	assert_push_error("range")


func test_r_004_21_known_answer() -> void:
	# Pins which markers each RNG seed gives. The box layout of saved worlds
	# depends on it (BALANCE §7.2), so a refactor must not move it.
	var expected: Dictionary[int, Array] = {
		42: [0, 3, 4, 5, 6, 8, 9],
		7: [1, 4, 5, 6, 7, 8, 9],
		20261115: [0, 1, 2, 4, 6, 9],
	}
	for rng_seed: int in expected:
		var picked: Array[int] = ZonePopulation.pick_box_markers(
			MARKERS, MIN_BOXES, MAX_BOXES, _new_rng(rng_seed)
		)
		var known: Array[int] = []
		known.assign(expected[rng_seed])
		assert_eq(picked, known, "markers of RNG seed %d" % rng_seed)


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
