extends GutTest
## GameManager holds the world seed of the current game (spec 004, R-004-08).
## Until worlds are saved (spec 010) it is the fixed development seed.

const DEV_WORLD_PATH := "res://resources/config/dev_world.tres"


func test_r_004_08_world_seed_from_dev_world() -> void:
	var dev_world: DevWorldConfigData = load(DEV_WORLD_PATH) as DevWorldConfigData
	assert_not_null(dev_world, "dev_world.tres exists and is a DevWorldConfigData")
	if dev_world == null:
		return
	assert_ne(dev_world.world_seed, 0, "the development seed is set")
	assert_eq(GameManager.get_world_seed(), dev_world.world_seed, "GameManager holds that seed")


## Spec 008: the ruleset, the visit counters and the clock live in GameManager.
## It is an autoload shared by every test, so the counters are cleared around each one.
const ZONE_A := Vector2i(0, 0)
const ZONE_B := Vector2i(4, -3)
const EXPECTED_VARIABLES: PackedStringArray = [
	"_world_seed",
	"_ruleset",
	"_visit_counts",
	"_time_service",
	"_current_zone_id",
	"_has_current_zone",
]


func before_each() -> void:
	GameManager.clear_visit_counts()


func after_each() -> void:
	GameManager.clear_visit_counts()


func test_r_008_02_ruleset_from_dev_world() -> void:
	var dev_world: DevWorldConfigData = load(DEV_WORLD_PATH) as DevWorldConfigData
	assert_not_null(dev_world, "dev_world.tres exists")
	if dev_world == null:
		return
	var ruleset: RulesetData = GameManager.get_ruleset()
	assert_not_null(ruleset, "GameManager holds a ruleset")
	if ruleset == null:
		return
	assert_eq(ruleset.id, dev_world.ruleset_id, "its id is the one of dev_world.tres")
	var from_registry: RulesetData = DataRegistry.get_ruleset(dev_world.ruleset_id)
	assert_same(ruleset, from_registry, "it is the catalog's own object")


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
	assert_signal_emit_count(GameManager, "zone_visit_changed", 1)
	assert_signal_emitted_with_parameters(GameManager, "zone_visit_changed", [ZONE_A, first])
	var second: int = GameManager.increment_visit_count(ZONE_A)
	assert_eq(second, first + 1, "adds exactly one each time")
	assert_signal_emit_count(GameManager, "zone_visit_changed", 2)


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
const ZONE_LOADER_PATH := "res://scenes/zones/zone_loader.gd"


func test_r_009_09_current_zone() -> void:
	watch_signals(GameManager)
	GameManager.set_current_zone(ZONE_B)
	assert_true(GameManager.has_current_zone(), "a zone is loaded")
	assert_eq(GameManager.get_current_zone_id(), ZONE_B, "the one that was set")
	GameManager.set_current_zone(ZONE_A)
	assert_eq(GameManager.get_current_zone_id(), ZONE_A, "the last one set")
	assert_signal_not_emitted(GameManager, "zone_visit_changed", "setting the zone counts no visit")
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
