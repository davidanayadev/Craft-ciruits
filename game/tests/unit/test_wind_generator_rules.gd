extends GutTest
## WindGeneratorRules (spec 012, plan D7): the generator's clock as pure code.
## The time comes by parameter, so no test waits for real time (R-012-15 to
## R-012-19). Data is made by hand: a period of 100 s and at most 3.

const RULES_PATH := "res://scripts/systems/wind_generator_rules.gd"
const FORBIDDEN_IN_RULES: PackedStringArray = ["DataRegistry", "GameManager", "get_node", "get_tree", "Time."]
const PERIOD := 100
const MAX_STORED := 3
const START := 1_000


func _config(period: int = PERIOD, max_stored: int = MAX_STORED) -> WindGeneratorData:
	var config: WindGeneratorData = WindGeneratorData.new()
	config.seconds_per_battery = period
	config.max_stored = max_stored
	return config


func _settle(stored: int, since: int, now: int) -> WindGeneratorRules.Settled:
	return WindGeneratorRules.settle(stored, since, now, _config())


func test_r_012_15_rules_are_pure() -> void:
	var rules: WindGeneratorRules = WindGeneratorRules.new()
	var as_object: Object = rules
	assert_false(as_object is Node, "WindGeneratorRules is not a Node")
	var script: GDScript = load(RULES_PATH) as GDScript
	assert_not_null(script, "the script loads")
	if script == null:
		return
	for word: String in FORBIDDEN_IN_RULES:
		assert_false(script.source_code.contains(word), "the rules never mention '%s'" % word)


func test_r_012_16_one_battery_per_full_period() -> void:
	var one: WindGeneratorRules.Settled = _settle(0, START, START + PERIOD)
	assert_eq(one.stored, 1, "one full period, one battery")
	assert_eq(one.since_unix, START + PERIOD, "the next period starts where this one ended")
	var two: WindGeneratorRules.Settled = _settle(0, START, START + 2 * PERIOD + 30)
	assert_eq(two.stored, 2, "two full periods, two batteries")
	assert_eq(two.since_unix, START + 2 * PERIOD, "the 30 s of the period in progress are kept")


func test_r_012_16_partial_period_adds_nothing() -> void:
	var settled: WindGeneratorRules.Settled = _settle(1, START, START + PERIOD - 1)
	assert_eq(settled.stored, 1, "a period not yet complete adds nothing")
	assert_eq(settled.since_unix, START, "the period in progress goes on")


func test_r_012_16_surplus_capped_at_max() -> void:
	var settled: WindGeneratorRules.Settled = _settle(1, START, START + 10 * PERIOD)
	assert_eq(settled.stored, MAX_STORED, "never above the maximum")


func test_r_012_17_full_does_not_accumulate() -> void:
	var settled: WindGeneratorRules.Settled = _settle(MAX_STORED, START, START + 50 * PERIOD)
	assert_eq(settled.stored, MAX_STORED, "full stays full")
	assert_eq(settled.since_unix, START, "a full generator does not move its reference")
	assert_eq(
		WindGeneratorRules.seconds_to_next(MAX_STORED, START, START + 7, _config()), -1, "no next battery when full"
	)


func test_r_012_17_taking_from_full_restarts_period() -> void:
	var now: int = START + 50 * PERIOD
	var full: WindGeneratorRules.Settled = _settle(1, START, now)
	assert_eq(full.stored, MAX_STORED, "it filled up long ago")
	var after: WindGeneratorRules.Settled = WindGeneratorRules.after_taking(full, 2, now, _config())
	assert_eq(after.stored, 1, "two taken")
	assert_eq(after.since_unix, now, "the next period starts when a battery is taken")
	assert_eq(WindGeneratorRules.settle(after.stored, after.since_unix, now + PERIOD - 1, _config()).stored, 1)
	assert_eq(WindGeneratorRules.settle(after.stored, after.since_unix, now + PERIOD, _config()).stored, 2)


func test_r_012_17_taking_below_full_keeps_period() -> void:
	var now: int = START + PERIOD + 40
	var settled: WindGeneratorRules.Settled = _settle(0, START, now)
	assert_eq(settled.stored, 1)
	var after: WindGeneratorRules.Settled = WindGeneratorRules.after_taking(settled, 1, now, _config())
	assert_eq(after.stored, 0, "taken")
	assert_eq(after.since_unix, START + PERIOD, "the period in progress goes on")
	assert_eq(WindGeneratorRules.seconds_to_next(after.stored, after.since_unix, now, _config()), PERIOD - 40)


func test_r_012_19_negative_elapsed_counts_zero() -> void:
	assert_eq(WindGeneratorRules.elapsed_s(START, START - 500), 0, "a clock set back counts as 0")
	assert_eq(WindGeneratorRules.elapsed_s(START, START + 5), 5)
	var settled: WindGeneratorRules.Settled = _settle(1, START, START - 10 * PERIOD)
	assert_eq(settled.stored, 1, "no battery gained nor lost")
	assert_eq(settled.since_unix, START, "the reference stays")
	assert_eq(WindGeneratorRules.seconds_to_next(1, START, START - 10, _config()), PERIOD, "a full period to wait")


func test_seconds_to_next_counts_down() -> void:
	assert_eq(WindGeneratorRules.seconds_to_next(0, START, START, _config()), PERIOD, "built now: a whole period")
	assert_eq(WindGeneratorRules.seconds_to_next(0, START, START + 30, _config()), PERIOD - 30)
	assert_eq(WindGeneratorRules.seconds_to_next(0, START, START + PERIOD + 30, _config()), PERIOD - 30)


func test_r_012_04_bad_data_reports_error() -> void:
	for config: WindGeneratorData in [_config(0, MAX_STORED), _config(PERIOD, 0), null]:
		var settled: WindGeneratorRules.Settled = WindGeneratorRules.settle(0, START, START + 99 * PERIOD, config)
		assert_eq(settled.stored, 0, "bad data makes no batteries")
		assert_eq(WindGeneratorRules.seconds_to_next(0, START, START, config), -1, "and no next one")
	assert_push_error_count(6)


func test_taking_more_than_held_reports_error() -> void:
	var settled: WindGeneratorRules.Settled = _settle(1, START, START)
	var after: WindGeneratorRules.Settled = WindGeneratorRules.after_taking(settled, 2, START, _config())
	assert_eq(after.stored, 1, "no change")
	assert_eq(after.since_unix, START, "no change")
	assert_push_error("cannot take 2")
