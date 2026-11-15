extends GutTest
## BatteryComponent rules (spec 003): starts full (R-003-01), drains by gait
## (R-003-02..04) and by elapsed time only (R-003-05), reports changes
## (R-003-06), warns once when low (R-003-07), stops at 0 (R-003-08), lets other
## systems consume and add (R-003-09), rejects negative amounts (R-003-10) and
## keeps its state per instance (R-003-14).
## No scene and no physics: the component gets delta and gait by parameter.
## Values come from the real .tres files (BALANCE §1.1 and §4.2 single source).

const ROBOT_BATTERY_PATH := "res://resources/battery/robot_battery.tres"
const BASIC_LEGS_PATH := "res://resources/movement/basic_legs.tres"
## Float error allowed after adding up many small per-frame drains.
const TOLERANCE := 0.0001

var _config: BatteryConfigData
var _legs: MovementStatsData
var _battery: BatteryComponent


func before_each() -> void:
	_config = load(ROBOT_BATTERY_PATH) as BatteryConfigData
	_legs = load(BASIC_LEGS_PATH) as MovementStatsData
	_battery = _new_battery()
	watch_signals(_battery)


func _new_battery() -> BatteryComponent:
	var battery: BatteryComponent = BatteryComponent.new()
	battery.config = _config
	battery.legs = _legs
	add_child_autofree(battery)
	return battery


func _drained_after_one_second(step: float, gait: LocomotionSystem.Gait) -> float:
	var battery: BatteryComponent = _new_battery()
	var steps: int = roundi(1.0 / step)
	for i: int in steps:
		battery.tick(step, gait)
	return battery.get_maximum() - battery.get_current()


func _low_threshold() -> float:
	return _config.maximum * _config.low_threshold_ratio


func test_r_003_01_starts_full() -> void:
	assert_eq(_battery.get_maximum(), 100.0, "maximum from robot_battery.tres")
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
	assert_eq(_config.maximum, 100.0, "the shared resource is not modified")
