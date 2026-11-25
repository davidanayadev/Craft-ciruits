extends GutTest
## BatteryComponent rules (spec 003): starts full (R-003-01), drains by gait
## (R-003-02..04) and by elapsed time only (R-003-05), reports changes
## (R-003-06), warns once when low (R-003-07), stops at 0 (R-003-08), lets other
## systems consume and add (R-003-09), rejects negative amounts (R-003-10) and
## keeps its state per instance (R-003-14). Spec 010: save and load (R-010-08, 09, 11, 24).
## No scene and no physics: the component gets delta and gait by parameter.
## Values come from the real .tres files (BALANCE §1.1 and §4.2 single source):
## since spec 015 the maximum and the rates are the stats of the robot with the
## starting equipment (basic Core and legs), which its entity gives it.

const ROBOT_BATTERY_PATH := "res://resources/battery/robot_battery.tres"
const BASE_STATS_PATH := "res://resources/robot/robot_base_stats.tres"
const STARTING_PIECES: Array[String] = [
	"res://resources/pieces/basic_core.tres", "res://resources/pieces/basic_legs.tres",
]
## Float error allowed after adding up many small per-frame drains.
const TOLERANCE := 0.0001

var _config: BatteryConfigData
## Stats of the robot with the starting equipment.
var _stats: Dictionary[StringName, float] = {}
var _maximum: float = 0.0
var _battery: BatteryComponent


func before_each() -> void:
	_config = load(ROBOT_BATTERY_PATH) as BatteryConfigData
	_stats = _starting_stats()
	_maximum = _stats[StatIds.MAX_BATTERY]
	_battery = _new_battery()
	watch_signals(_battery)


func _starting_stats() -> Dictionary[StringName, float]:
	var base: RobotBaseStatsData = load(BASE_STATS_PATH) as RobotBaseStatsData
	var modifiers: Array[StatModifier] = []
	for path: String in STARTING_PIECES:
		var piece: PieceData = load(path) as PieceData
		modifiers.append_array(piece.modifiers)
	return StatsCalculator.compute(base.to_stats(), modifiers)


## Given its stats and filled, as its entity does (spec 015, plan D5).
func _new_battery() -> BatteryComponent:
	var battery: BatteryComponent = BatteryComponent.new()
	battery.config = _config
	battery.name = "Battery"
	add_child_autofree(battery)
	battery.set_drain_rates(
		_stats[StatIds.PASSIVE_DRAIN], _stats[StatIds.WALK_DRAIN], _stats[StatIds.RUN_DRAIN]
	)
	battery.set_base_maximum(_maximum)
	battery.recharge_full()
	return battery


func _drained_after_one_second(step: float, gait: LocomotionSystem.Gait) -> float:
	var battery: BatteryComponent = _new_battery()
	var steps: int = roundi(1.0 / step)
	for i: int in steps:
		battery.tick(step, gait)
	return battery.get_maximum() - battery.get_current()


func _low_threshold() -> float:
	return _maximum * _config.low_threshold_ratio


func test_r_003_01_starts_full() -> void:
	assert_eq(_battery.get_maximum(), 100.0, "maximum of the basic Core (BALANCE §4.2), given by its entity")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "starts full")
	assert_false(_battery.is_depleted(), "a full battery is not depleted")


func test_r_003_01_missing_resources_report_error() -> void:
	var battery: BatteryComponent = BatteryComponent.new()
	battery.name = "Orphan"
	add_child_autofree(battery)
	assert_push_error("Orphan")
	assert_eq(battery.get_maximum(), 0.0, "no config, no charge")


func test_r_003_02_idle_drains_passive_rate() -> void:
	assert_almost_eq(
		_battery.drain_per_second(LocomotionSystem.Gait.IDLE), 0.1, TOLERANCE, "0.1/s standing"
	)
	_battery.tick(1.0, LocomotionSystem.Gait.IDLE)
	assert_almost_eq(_battery.get_current(), 99.9, TOLERANCE, "one second standing")


func test_r_003_03_walk_adds_legs_walk_drain() -> void:
	assert_almost_eq(
		_battery.drain_per_second(LocomotionSystem.Gait.WALK), 0.15, TOLERANCE, "0.15/s walking"
	)
	_battery.tick(1.0, LocomotionSystem.Gait.WALK)
	assert_almost_eq(_battery.get_current(), 99.85, TOLERANCE, "one second walking")


func test_r_003_04_run_replaces_walk_drain() -> void:
	assert_almost_eq(
		_battery.drain_per_second(LocomotionSystem.Gait.RUN), 0.25, TOLERANCE, "0.25/s running"
	)
	_battery.tick(1.0, LocomotionSystem.Gait.RUN)
	assert_almost_eq(_battery.get_current(), 99.75, TOLERANCE, "one second running")


func test_r_003_05_same_drain_at_any_frame_rate() -> void:
	var steps: Array[float] = [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0, 1.0]
	for step: float in steps:
		var drained: float = _drained_after_one_second(step, LocomotionSystem.Gait.RUN)
		assert_almost_eq(drained, 0.25, TOLERANCE, "one second in steps of %f" % step)


func test_r_003_06_emits_changed_with_values() -> void:
	_battery.tick(1.0, LocomotionSystem.Gait.IDLE)
	assert_signal_emit_count(_battery, "battery_changed", 1)
	var parameters: Array = get_signal_parameters(_battery, "battery_changed", 0)
	var current: float = parameters[0]
	var maximum: float = parameters[1]
	assert_almost_eq(current, 99.9, TOLERANCE, "first argument is the new current value")
	assert_eq(maximum, 100.0, "second argument is the maximum")


func test_r_003_06_no_signal_without_change() -> void:
	_battery.tick(0.0, LocomotionSystem.Gait.RUN)
	assert_signal_not_emitted(_battery, "battery_changed", "no time passed, nothing changed")


func test_r_003_07_low_emitted_once_below_threshold() -> void:
	_battery.consume(_battery.get_maximum() - _low_threshold())
	assert_signal_not_emitted(_battery, "battery_low", "exactly at the threshold is not below it")
	_battery.consume(1.0)
	assert_signal_emit_count(_battery, "battery_low", 1, "crossing below the threshold warns")
	_battery.consume(1.0)
	assert_signal_emit_count(_battery, "battery_low", 1, "staying below does not warn again")


func test_r_003_07_low_rearms_after_rising_above() -> void:
	_battery.consume(_battery.get_maximum() - _low_threshold() + 1.0)
	_battery.add(1.0)
	_battery.consume(1.0)
	assert_signal_emit_count(_battery, "battery_low", 1, "back to the threshold does not rearm")
	_battery.add(2.0)
	_battery.consume(2.0)
	assert_signal_emit_count(_battery, "battery_low", 2, "rising above the threshold rearms")


func test_r_003_08_depleted_clamps_and_emits_once() -> void:
	_battery.consume(_battery.get_maximum() + 50.0)
	assert_eq(_battery.get_current(), 0.0, "clamped at 0")
	assert_true(_battery.is_depleted(), "0 means depleted")
	_battery.consume(10.0)
	assert_signal_emit_count(_battery, "battery_depleted", 1, "depleted is reported once")


func test_r_003_08_no_drain_after_depleted() -> void:
	_battery.consume(_battery.get_maximum())
	var changes: int = get_signal_emit_count(_battery, "battery_changed")
	_battery.tick(10.0, LocomotionSystem.Gait.RUN)
	assert_eq(_battery.get_current(), 0.0, "stays at 0")
	assert_signal_emit_count(_battery, "battery_changed", changes, "nothing changes at 0")
	assert_signal_emit_count(_battery, "battery_depleted", 1, "no second depleted")


func test_r_003_08_depleted_again_after_recharge() -> void:
	_battery.consume(_battery.get_maximum())
	_battery.recharge_full()
	assert_false(_battery.is_depleted(), "recharging works from 0")
	_battery.consume(_battery.get_maximum())
	assert_signal_emit_count(_battery, "battery_depleted", 2, "a new arrival at 0 reports again")


func test_r_003_08_signal_order() -> void:
	var order: Array[String] = []
	_battery.battery_changed.connect(
		func(_current: float, _maximum: float) -> void: order.append("battery_changed")
	)
	_battery.battery_low.connect(func() -> void: order.append("battery_low"))
	_battery.battery_depleted.connect(func() -> void: order.append("battery_depleted"))
	_battery.consume(_battery.get_maximum())
	var expected: Array[String] = ["battery_changed", "battery_low", "battery_depleted"]
	assert_eq(order, expected, "changed, then low, then depleted")


func test_r_003_09_consume() -> void:
	_battery.consume(30.0)
	assert_eq(_battery.get_current(), 70.0, "consume takes the amount")
	assert_signal_emitted_with_parameters(_battery, "battery_changed", [70.0, 100.0])


func test_r_003_09_add_capped_at_maximum() -> void:
	_battery.consume(30.0)
	_battery.add(10.0)
	assert_eq(_battery.get_current(), 80.0, "add gives the amount")
	_battery.add(50.0)
	assert_eq(_battery.get_current(), _battery.get_maximum(), "add never passes the maximum")


func test_r_003_09_recharge_full() -> void:
	_battery.consume(60.0)
	_battery.recharge_full()
	assert_eq(_battery.get_current(), _battery.get_maximum(), "back to full")


func test_r_003_09_no_signal_without_change() -> void:
	_battery.consume(0.0)
	_battery.add(0.0)
	_battery.add(10.0)
	_battery.recharge_full()
	assert_signal_not_emitted(_battery, "battery_changed", "a full battery did not change")


func test_r_003_10_negative_consume_rejected() -> void:
	_battery.consume(-5.0)
	assert_push_error("consume")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "battery unchanged")
	assert_signal_not_emitted(_battery, "battery_changed")


func test_r_003_10_negative_add_rejected() -> void:
	_battery.consume(30.0)
	_battery.add(-5.0)
	assert_push_error("add")
	assert_eq(_battery.get_current(), 70.0, "battery unchanged")
	assert_signal_emit_count(_battery, "battery_changed", 1, "only the consume was reported")


func test_r_003_14_two_components_do_not_share_state() -> void:
	var other: BatteryComponent = _new_battery()
	_battery.tick(10.0, LocomotionSystem.Gait.RUN)
	assert_lt(_battery.get_current(), _battery.get_maximum(), "the ticked component drained")
	assert_eq(other.get_current(), other.get_maximum(), "the other one is untouched")
	assert_eq(_config.low_threshold_ratio, 0.2, "the shared resource is not modified")


## Spec 009: the station recharges through this method, which reports like any
## other change (R-009-48).
func test_r_009_48_recharge_full_emits_change() -> void:
	_battery.consume(40.0)
	_battery.recharge_full()
	assert_eq(_battery.get_current(), _battery.get_maximum(), "full")
	assert_signal_emit_count(_battery, "battery_changed", 2, "one for the drain, one for the recharge")
	assert_signal_emitted_with_parameters(
		_battery, "battery_changed", [_battery.get_maximum(), _battery.get_maximum()]
	)


# --- Spec 010: save and load (R-010-08, R-010-09, R-010-11, R-010-24, D15) -----


func test_r_010_08_save_key() -> void:
	assert_eq(BatteryComponent.SAVE_KEY, &"battery", "const")
	assert_eq(_battery.get_save_key(), &"battery", "getter")


func test_r_010_24_save_data_is_only_the_current_charge() -> void:
	_battery.consume(30.0)
	var data: Dictionary = _battery.to_save_data()
	assert_eq(data.size(), 1, "only one key: the maximum comes from the config")
	assert_true(data.has("current"), "current")
	var current: float = data["current"] as float
	assert_almost_eq(current, _battery.get_maximum() - 30.0, TOLERANCE, "current charge")
	assert_eq(typeof(data["current"]), TYPE_FLOAT, "a JSON number")


func test_r_010_09_load_sets_charge_and_emits_changed_once() -> void:
	_battery.from_save_data({"current": 42.5})
	assert_almost_eq(_battery.get_current(), 42.5, TOLERANCE, "loaded")
	assert_signal_emit_count(_battery, "battery_changed", 1, "one state signal")
	assert_signal_emitted_with_parameters(_battery, "battery_changed", [42.5, _battery.get_maximum()])


func test_r_010_09_load_accepts_an_int() -> void:
	_battery.from_save_data({"current": 50})
	assert_almost_eq(_battery.get_current(), 50.0, TOLERANCE, "int 50 accepted")


func test_r_010_09_load_accepts_the_maximum_without_a_signal() -> void:
	_battery.from_save_data({"current": _battery.get_maximum()})
	assert_eq(_battery.get_current(), _battery.get_maximum(), "still full")
	assert_signal_not_emitted(_battery, "battery_changed", "equal value, nothing announced")


func test_r_010_09_load_same_value_emits_nothing() -> void:
	_battery.consume(10.0)
	clear_signal_watcher()
	watch_signals(_battery)
	var same: float = _battery.get_current()
	_battery.from_save_data({"current": same})
	assert_signal_not_emitted(_battery, "battery_changed", "equal value")


func test_r_010_09_load_below_threshold_no_fact() -> void:
	var below: float = _low_threshold() * 0.5
	_battery.from_save_data({"current": below})
	assert_almost_eq(_battery.get_current(), below, TOLERANCE, "loaded")
	assert_signal_not_emitted(_battery, "battery_low", "loading is not a fact")
	assert_signal_not_emitted(_battery, "battery_depleted", "loading is not a fact")


func test_r_010_09_load_below_threshold_does_not_rearm_the_warning() -> void:
	_battery.from_save_data({"current": _low_threshold() * 0.5})
	_battery.consume(1.0)
	assert_signal_not_emitted(_battery, "battery_low", "the warning counts as already given")


func test_r_010_09_load_above_threshold_rearms_the_warning() -> void:
	_battery.from_save_data({"current": _low_threshold() * 0.5})
	_battery.from_save_data({"current": _maximum * 0.9})
	_battery.consume(_maximum)
	assert_signal_emit_count(_battery, "battery_low", 1, "armed again by the load above")


func test_r_010_09_round_trip_battery() -> void:
	_battery.consume(37.0)
	var saved: Dictionary = _battery.to_save_data()
	var other: BatteryComponent = _new_battery()
	watch_signals(other)
	other.from_save_data(saved)
	assert_almost_eq(other.get_current(), _battery.get_current(), TOLERANCE, "same charge")
	assert_signal_emit_count(other, "battery_changed", 1, "one state signal")
	var again: Dictionary = other.to_save_data()
	assert_eq(again, saved, "saves the same data")


func test_r_010_11_load_zero_is_rejected() -> void:
	_battery.from_save_data({"current": 0.0})
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "unchanged")
	assert_signal_not_emitted(_battery, "battery_changed")


func test_r_010_11_load_negative_is_rejected() -> void:
	_battery.from_save_data({"current": -5.0})
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "unchanged")
	assert_signal_not_emitted(_battery, "battery_changed")


## Replaces test_r_010_11_load_above_maximum_is_rejected (plan 012 D11, §5.4):
## the same final charge (the maximum) and the same push_error, now raised when
## the pending charge is dropped without being applied.
func test_r_012_14_above_without_bonus_reported_and_at_maximum() -> void:
	_battery.from_save_data({"current": _battery.get_maximum() + 1.0})
	assert_push_error_count(0, "not reported yet: a bonus may still come")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "at the maximum")
	assert_signal_not_emitted(_battery, "battery_changed")
	_battery.tick(0.0, LocomotionSystem.Gait.IDLE)
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "still at the maximum")


func test_r_010_11_load_missing_current_is_rejected() -> void:
	_battery.from_save_data({})
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "unchanged")
	assert_signal_not_emitted(_battery, "battery_changed")


func test_r_010_11_load_non_number_is_rejected() -> void:
	_battery.from_save_data({"current": "50"})
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), _battery.get_maximum(), "unchanged")
	assert_signal_not_emitted(_battery, "battery_changed")


# --- Maximum battery bonus (spec 012) ----------------------------------------
# R-012-11 to R-012-14. The bonus value is made up: the real one is data of the
# generator (test_structure_resources.gd).

const BONUS := 20.0


func test_r_012_11_maximum_with_bonus() -> void:
	_battery.set_maximum_bonus(BONUS)
	assert_eq(_battery.get_maximum(), _maximum + BONUS, "the maximum without bonus plus the bonus")
	_battery.set_maximum_bonus(0.0)
	assert_eq(_battery.get_maximum(), _maximum, "back without bonus")


func test_r_012_11_negative_bonus_rejected() -> void:
	_battery.set_maximum_bonus(-1.0)
	assert_push_error("Battery")
	assert_eq(_battery.get_maximum(), _maximum, "no change")
	assert_signal_not_emitted(_battery, "battery_changed")


func test_r_012_11_bonus_set_before_ready_kept() -> void:
	var battery: BatteryComponent = BatteryComponent.new()
	battery.config = _config
	battery.set_base_maximum(_maximum)
	battery.set_maximum_bonus(BONUS)
	add_child_autofree(battery)
	assert_eq(battery.get_maximum(), _maximum + BONUS, "the bonus and the stat survive _ready()")


func test_r_012_12_bonus_keeps_charge_emits_once() -> void:
	_battery.consume(30.0)
	var before: float = _battery.get_current()
	clear_signal_watcher()
	watch_signals(_battery)
	_battery.set_maximum_bonus(BONUS)
	assert_eq(_battery.get_current(), before, "the charge stays")
	assert_signal_emit_count(_battery, "battery_changed", 1, "one change")
	assert_signal_emitted_with_parameters(_battery, "battery_changed", [before, _maximum + BONUS])
	_battery.set_maximum_bonus(BONUS)
	assert_signal_emit_count(_battery, "battery_changed", 1, "the same bonus again changes nothing")


func test_r_012_12_bonus_emits_no_fact() -> void:
	_battery.consume(_maximum - 21.0)
	clear_signal_watcher()
	watch_signals(_battery)
	_battery.set_maximum_bonus(BONUS)
	assert_signal_not_emitted(_battery, "battery_low", "21 is below 24 % of 120 but nothing was consumed")
	assert_signal_not_emitted(_battery, "battery_depleted")
	_battery.set_maximum_bonus(0.0)
	assert_signal_not_emitted(_battery, "battery_low")


func test_r_012_12_bonus_removed_lowers_charge_above_it() -> void:
	_battery.set_maximum_bonus(BONUS)
	_battery.recharge_full()
	clear_signal_watcher()
	watch_signals(_battery)
	_battery.set_maximum_bonus(0.0)
	assert_eq(_battery.get_current(), _maximum, "lowered to the new maximum")
	assert_signal_emit_count(_battery, "battery_changed", 1)


func test_r_012_13_low_threshold_uses_new_maximum() -> void:
	_battery.set_maximum_bonus(BONUS)
	var threshold: float = (_maximum + BONUS) * _config.low_threshold_ratio
	_battery.consume(_battery.get_current() - threshold - 0.5)
	assert_signal_not_emitted(_battery, "battery_low", "still above the threshold of the new maximum")
	_battery.consume(1.0)
	assert_signal_emit_count(_battery, "battery_low", 1, "warned below the threshold of the new maximum")


func test_r_012_13_recharge_full_to_new_maximum() -> void:
	_battery.set_maximum_bonus(BONUS)
	_battery.recharge_full()
	assert_eq(_battery.get_current(), _maximum + BONUS, "a station fills to the new maximum")


func test_r_012_14_charge_loaded_before_bonus() -> void:
	var saved: float = _maximum + BONUS - 5.0
	_battery.from_save_data({"current": saved})
	assert_eq(_battery.get_current(), _maximum, "held at the maximum while the bonus is unknown")
	_battery.set_maximum_bonus(BONUS)
	assert_eq(_battery.get_current(), saved, "the saved charge once the bonus arrives")
	assert_eq(_battery.get_maximum(), _maximum + BONUS)
	assert_push_error_count(0, "nothing to report")
	assert_signal_not_emitted(_battery, "battery_low")


func test_r_012_14_bonus_before_charge() -> void:
	_battery.set_maximum_bonus(BONUS)
	var saved: float = _maximum + BONUS - 5.0
	_battery.from_save_data({"current": saved})
	assert_eq(_battery.get_current(), saved, "accepted up to the new maximum")
	assert_push_error_count(0)


func test_r_012_14_pending_dropped_by_other_change() -> void:
	_battery.from_save_data({"current": _maximum + 10.0})
	_battery.consume(1.0)
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), _maximum - 1.0, "the pending charge is gone")
	_battery.set_maximum_bonus(BONUS)
	assert_eq(_battery.get_current(), _maximum - 1.0, "a later bonus does not bring it back")


func test_r_012_14_pending_dropped_by_new_load() -> void:
	_battery.from_save_data({"current": _maximum + 10.0})
	_battery.from_save_data({"current": 50.0})
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), 50.0, "the new load wins")
	_battery.set_maximum_bonus(BONUS)
	assert_eq(_battery.get_current(), 50.0, "and the old one is never applied")


func test_r_012_14_bonus_too_small_reports() -> void:
	_battery.from_save_data({"current": _maximum + BONUS + 10.0})
	_battery.set_maximum_bonus(BONUS)
	assert_push_error("Battery")
	assert_eq(_battery.get_current(), _maximum + BONUS, "at the new maximum")


# --- Stats from StatsComponent (spec 015) ------------------------------------
# R-015-15, R-015-18, R-015-19, R-015-43, R-015-44. The numbers are made-up
# inputs: the real ones come from StatsComponent (test_robot_equipment.gd).


func test_r_015_15_drain_rates_by_gait() -> void:
	_battery.set_drain_rates(0.5, 0.25, 1.0)
	assert_eq(_battery.drain_per_second(LocomotionSystem.Gait.IDLE), 0.5, "passive while standing")
	assert_eq(_battery.drain_per_second(LocomotionSystem.Gait.WALK), 0.75, "passive + walk")
	assert_eq(_battery.drain_per_second(LocomotionSystem.Gait.RUN), 1.5, "passive + run, never walk")


func test_r_015_15_negative_rate_rejected() -> void:
	var before: float = _battery.drain_per_second(LocomotionSystem.Gait.WALK)
	_battery.set_drain_rates(0.5, -0.25, 1.0)
	assert_push_error("Battery")
	assert_eq(_battery.drain_per_second(LocomotionSystem.Gait.WALK), before, "no change")


func test_r_015_44_passive_rate_from_stats() -> void:
	_battery.set_drain_rates(0.25, 0.0, 0.0)
	_battery.tick(2.0, LocomotionSystem.Gait.IDLE)
	assert_almost_eq(_battery.get_current(), _battery.get_maximum() - 0.5, TOLERANCE, "the rate it was given")


func test_r_015_18_maximum_is_stat_plus_bonus() -> void:
	_battery.set_base_maximum(80.0)
	assert_eq(_battery.get_maximum(), 80.0, "the stat")
	_battery.set_maximum_bonus(BONUS)
	assert_eq(_battery.get_maximum(), 80.0 + BONUS, "the stat plus the generator")
	_battery.set_base_maximum(90.0)
	assert_eq(_battery.get_maximum(), 90.0 + BONUS, "a new stat keeps the bonus")


func test_r_015_18_negative_base_maximum_rejected() -> void:
	var before: float = _battery.get_maximum()
	_battery.set_base_maximum(-1.0)
	assert_push_error("Battery")
	assert_eq(_battery.get_maximum(), before, "no change")


func test_r_015_19_base_maximum_keeps_or_lowers_charge() -> void:
	_battery.consume(50.0)
	var half: float = _battery.get_current()
	clear_signal_watcher()
	watch_signals(_battery)
	_battery.set_base_maximum(_battery.get_maximum() + 20.0)
	assert_eq(_battery.get_current(), half, "a higher maximum keeps the charge")
	assert_signal_emit_count(_battery, "battery_changed", 1, "one change")
	_battery.set_base_maximum(30.0)
	assert_eq(_battery.get_current(), 30.0, "a lower maximum lowers a charge above it")
	assert_signal_emit_count(_battery, "battery_changed", 2, "one change each")
	_battery.set_base_maximum(30.0)
	assert_signal_emit_count(_battery, "battery_changed", 2, "the same maximum changes nothing")


func test_r_015_19_no_low_nor_depleted_signal() -> void:
	_battery.consume(_battery.get_maximum() - 21.0)
	clear_signal_watcher()
	watch_signals(_battery)
	_battery.set_base_maximum(200.0)
	assert_signal_not_emitted(_battery, "battery_low", "21 is below 20 % of 200 but nothing was consumed")
	_battery.set_base_maximum(0.0)
	assert_signal_not_emitted(_battery, "battery_depleted", "a maximum of 0 consumes nothing")


func test_r_015_19_loaded_charge_waits_for_base_maximum() -> void:
	var saved: float = _battery.get_maximum() + 10.0
	_battery.from_save_data({"current": saved})
	_battery.set_base_maximum(saved + 5.0)
	assert_eq(_battery.get_current(), saved, "same pending rule as the bonus (plan 015 D6)")
	assert_push_error_count(0, "nothing to report")


func test_r_015_43_is_low() -> void:
	var threshold: float = _battery.get_maximum() * _config.low_threshold_ratio
	assert_false(_battery.is_low(), "a full battery is not low")
	_battery.consume(_battery.get_current() - threshold)
	assert_false(_battery.is_low(), "at the threshold it is not low yet")
	_battery.consume(0.5)
	assert_true(_battery.is_low(), "below the threshold")
	_battery.set_maximum_bonus(BONUS)
	assert_true(_battery.is_low(), "still below the threshold of the larger maximum")
	_battery.recharge_full()
	assert_false(_battery.is_low(), "a recharge ends it")
