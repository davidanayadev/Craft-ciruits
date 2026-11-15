extends GutTest
## ZonePopulation (spec 004, R-004-21): how many boxes a zone gets and on which
## of its hand-placed markers, decided only by the RNG it is given.

const MARKERS := 10
const MIN_BOXES := 5
const MAX_BOXES := 7
const SEEDS := 100


func _new_rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


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
