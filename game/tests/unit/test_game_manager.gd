extends GutTest
## GameManager holds the world of the current game (spec 004 R-004-08, spec 008,
## spec 009 R-009-09, spec 010 R-010-09, R-010-20, R-010-21, R-010-26).
## It is an autoload shared by every test, so a sane world is restored around each one.

const KNOWN_SEED := 20261115
const ZONE_A := Vector2i(0, 0)
const ZONE_B := Vector2i(4, -3)
const EXPECTED_VARIABLES: PackedStringArray = [
	"_world_id",
	"_world_name",
	"_world_seed",
	"_ruleset",
	"_visit_counts",
	"_time_service",
	"_store",
	"_current_zone_id",
	"_has_current_zone",
]

func before_each() -> void:
	_restore_world()

func after_each() -> void:
	_restore_world()

func _restore_world() -> void:
	var ruleset: RulesetData = DataRegistry.get_ruleset(&"normal")
	GameManager.begin_world(Uid.generate(), "", KNOWN_SEED, ruleset)

func test_r_010_20_world_from_begin_world() -> void:
	var ruleset: RulesetData = DataRegistry.get_ruleset(&"normal")
	assert_not_null(ruleset, "the catalog has the normal ruleset")
	GameManager.begin_world("world-abc", "My world", 777, ruleset)
	assert_eq(GameManager.get_world_id(), "world-abc", "id")
	assert_eq(GameManager.get_world_name(), "My world", "name")
	assert_eq(GameManager.get_world_seed(), 777, "seed")
	assert_same(GameManager.get_ruleset(), ruleset, "it is the catalog's own object")

func test_r_010_20_begin_world_clears_visits_and_zone() -> void:
	GameManager.increment_visit_count(ZONE_A)
	GameManager.set_current_zone(ZONE_B)
	var ruleset: RulesetData = DataRegistry.get_ruleset(&"normal")
	GameManager.begin_world("other", "", 5, ruleset)
	assert_eq(GameManager.get_visit_count(ZONE_A), ZonePopulation.FIRST_VISIT, "counters cleared")
	assert_false(GameManager.has_current_zone(), "no zone is loaded in a new world")

func test_r_010_21_no_seed_setter() -> void:
	var script: Script = GameManager.get_script() as Script
	assert_not_null(script, "GameManager is a script autoload")
	if script == null:
		return
	var offenders: PackedStringArray = PackedStringArray()
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.containsn("seed") and method_name != "get_world_seed":
			offenders.append(method_name)
	assert_eq(offenders, PackedStringArray(), "the seed can only be read")

func test_r_010_20_only_save_manager_begins_a_world() -> void:
	var callers: PackedStringArray = PackedStringArray()
	for directory: String in SCRIPT_DIRS:
		_collect_callers(directory, "begin_world(", callers)
	var others: PackedStringArray = PackedStringArray()
	for caller: String in callers:
		if caller != SAVE_MANAGER_PATH:
			others.append(caller)
	assert_eq(others, PackedStringArray(), "only SaveManager begins a world")

func test_r_010_09_group_persistent() -> void:
	assert_true(GameManager.is_in_group(&"persistent"), "GameManager is saved with the world")

func test_r_010_09_save_key() -> void:
	assert_eq(GameManager.SAVE_KEY, &"zone_visits", "constant")
	assert_eq(GameManager.get_save_key(), &"zone_visits", "method")

func test_r_010_09_empty_save_data() -> void:
	var data: Dictionary = GameManager.to_save_data()
	assert_eq(data, {"zones": []}, "no visits, no entries")

func test_r_010_09_save_data_sorted_by_zone() -> void:
	GameManager.increment_visit_count(ZONE_B)
	GameManager.increment_visit_count(ZONE_A)
	GameManager.increment_visit_count(ZONE_A)
	var expected: Dictionary = {
		"zones":
		[
			{"zone_id": [ZONE_A.x, ZONE_A.y], "visit": 2},
			{"zone_id": [ZONE_B.x, ZONE_B.y], "visit": 1},
		]
	}
	assert_eq(GameManager.to_save_data(), expected, "sorted by zone id, JSON types only")

func test_r_010_09_round_trip_visit_counters() -> void:
	GameManager.increment_visit_count(ZONE_B)
	GameManager.increment_visit_count(ZONE_A)
	GameManager.increment_visit_count(ZONE_A)
	var saved: Dictionary = GameManager.to_save_data()
	var ruleset: RulesetData = DataRegistry.get_ruleset(&"normal")
	GameManager.begin_world("other", "", 5, ruleset)
	GameManager.from_save_data(saved)
	assert_eq(GameManager.get_visit_count(ZONE_A), ZonePopulation.FIRST_VISIT + 2, "zone A")
	assert_eq(GameManager.get_visit_count(ZONE_B), ZonePopulation.FIRST_VISIT + 1, "zone B")
	assert_eq(GameManager.to_save_data(), saved, "same document")

func test_r_010_26_load_replaces_counters_and_emits_no_fact() -> void:
	GameManager.increment_visit_count(ZONE_A)
	watch_signals(GameManager)
	var data: Dictionary = {"zones": [{"zone_id": [ZONE_B.x, ZONE_B.y], "visit": 3}]}
	GameManager.from_save_data(data)
	assert_eq(GameManager.get_visit_count(ZONE_A), ZonePopulation.FIRST_VISIT, "old counters replaced")
	assert_eq(GameManager.get_visit_count(ZONE_B), 3, "loaded counter")
	assert_signal_not_emitted(GameManager, "zone_visit_counted", "loading counts no visit")

func test_r_010_09_malformed_entry_keeps_first_visit() -> void:
	var data: Dictionary = {
		"zones":
		[
			{"zone_id": [1], "visit": 4},
			{"zone_id": [ZONE_B.x, ZONE_B.y], "visit": "many"},
			{"zone_id": [ZONE_A.x, ZONE_A.y], "visit": 2},
		]
	}
	GameManager.from_save_data(data)
	assert_push_error_count(2)
	assert_eq(GameManager.get_visit_count(ZONE_A), 2, "the good entry loads")
	assert_eq(GameManager.get_visit_count(ZONE_B), ZonePopulation.FIRST_VISIT, "bad one stays first")
	assert_eq(GameManager.get_visit_count(Vector2i(1, 0)), ZonePopulation.FIRST_VISIT, "bad id")

func test_r_008_06_visit_count_starts_at_zero() -> void:
	assert_eq(ZonePopulation.FIRST_VISIT, 0, "the first visit is 0")
	assert_eq(
		GameManager.get_visit_count(ZONE_A),
		ZonePopulation.FIRST_VISIT,
		"a zone never touched is at the first visit"
	)
	assert_eq(
		GameManager.get_visit_count(ZONE_A),
		ZonePopulation.FIRST_VISIT,
		"reading does not count a visit"
	)

func test_r_008_06_counts_are_per_zone() -> void:
	GameManager.increment_visit_count(ZONE_A)
	GameManager.increment_visit_count(ZONE_A)
	GameManager.increment_visit_count(ZONE_B)
	assert_eq(GameManager.get_visit_count(ZONE_A), ZonePopulation.FIRST_VISIT + 2, "zone A")
	assert_eq(GameManager.get_visit_count(ZONE_B), ZonePopulation.FIRST_VISIT + 1, "zone B")
	assert_eq(
		GameManager.get_visit_count(Vector2i(9, 9)),
		ZonePopulation.FIRST_VISIT,
		"other zones are untouched"
	)

func test_r_008_07_increment_adds_one_and_emits() -> void:
	watch_signals(GameManager)
	var first: int = GameManager.increment_visit_count(ZONE_A)
	assert_eq(first, ZonePopulation.FIRST_VISIT + 1, "returns the new count")
	assert_eq(GameManager.get_visit_count(ZONE_A), first, "and stores it")
	assert_signal_emit_count(GameManager, "zone_visit_counted", 1)
	assert_signal_emitted_with_parameters(GameManager, "zone_visit_counted", [ZONE_A, first])
	var second: int = GameManager.increment_visit_count(ZONE_A)
	assert_eq(second, first + 1, "adds exactly one each time")
	assert_signal_emit_count(GameManager, "zone_visit_counted", 2)

func test_r_008_07_clear_visit_counts_resets_every_zone() -> void:
	GameManager.increment_visit_count(ZONE_A)
	GameManager.increment_visit_count(ZONE_B)
	GameManager.clear_visit_counts()
	assert_eq(GameManager.get_visit_count(ZONE_A), ZonePopulation.FIRST_VISIT, "zone A cleared")
	assert_eq(GameManager.get_visit_count(ZONE_B), ZonePopulation.FIRST_VISIT, "zone B cleared")

func test_r_008_19_exposes_time_service() -> void:
	var service: ITimeService = GameManager.get_time_service()
	assert_not_null(service, "GameManager exposes a clock")
	assert_true(service is LocalTimeService, "the local implementation")
	assert_same(GameManager.get_time_service(), service, "always the same instance")

func test_r_008_34_holds_only_world_state() -> void:
	var script: Script = GameManager.get_script() as Script
	assert_not_null(script, "GameManager is a script autoload")
	if script == null:
		return
	var variables: PackedStringArray = PackedStringArray()
	for property: Dictionary in script.get_script_property_list():
		var usage: int = property["usage"]
		var property_name: String = property["name"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			variables.append(property_name)
	variables.sort()
	var expected: PackedStringArray = EXPECTED_VARIABLES.duplicate()
	expected.sort()
	assert_eq(variables, expected, "only world state, no per-player value")

## Spec 009: the loaded zone is global state of GameManager, set only by
## ZoneLoader (R-009-09).
const SCRIPT_DIRS: PackedStringArray = ["res://scenes", "res://scripts"]
const GAME_MANAGER_PATH := "res://scripts/autoload/game_manager.gd"
const SAVE_MANAGER_PATH := "res://scripts/autoload/save_manager.gd"
const ZONE_LOADER_PATH := "res://scenes/zones/zone_loader.gd"

func test_r_009_09_current_zone() -> void:
	watch_signals(GameManager)
	GameManager.set_current_zone(ZONE_B)
	assert_true(GameManager.has_current_zone(), "a zone is loaded")
	assert_eq(GameManager.get_current_zone_id(), ZONE_B, "the one that was set")
	GameManager.set_current_zone(ZONE_A)
	assert_eq(GameManager.get_current_zone_id(), ZONE_A, "the last one set")
	assert_signal_not_emitted(GameManager, "zone_visit_counted", "setting the zone counts no visit")
	assert_eq(GameManager.get_visit_count(ZONE_B), ZonePopulation.FIRST_VISIT, "no visit counted")

func test_r_009_09_only_zone_loader_sets_it() -> void:
	var callers: PackedStringArray = PackedStringArray()
	for directory: String in SCRIPT_DIRS:
		_collect_callers(directory, "set_current_zone(", callers)
	var others: PackedStringArray = PackedStringArray()
	for caller: String in callers:
		if caller != ZONE_LOADER_PATH:
			others.append(caller)
	assert_eq(others, PackedStringArray(), "only ZoneLoader sets the zone")

func _collect_callers(directory: String, needle: String, callers: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(directory):
		_collect_callers(directory.path_join(sub), needle, callers)
	for file: String in DirAccess.get_files_at(directory):
		var path: String = directory.path_join(file)
		if not file.ends_with(".gd") or path == GAME_MANAGER_PATH:
			continue
		if FileAccess.get_file_as_string(path).contains(needle):
			callers.append(path)
