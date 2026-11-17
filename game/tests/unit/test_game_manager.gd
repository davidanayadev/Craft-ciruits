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
	"_world_seed", "_ruleset", "_visit_counts", "_time_service"
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
