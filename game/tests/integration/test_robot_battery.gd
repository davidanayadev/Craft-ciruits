extends GutTest
## Robot + BatteryComponent with real physics (R-003-02..04): the robot feeds
## its own gait to the battery every physics frame. Input goes through the
## InputMap actions, the same path the game uses. Expected totals mirror
## BALANCE §1.1.

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
## wait_physics_frames() may run a few frames more or fewer than requested.
const FRAME_SLACK := 4.0

var _robot: Robot


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)


func after_each() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"run")


func _drained_in_one_second() -> float:
	var start: float = _robot.battery.get_current()
	await wait_physics_frames(Engine.physics_ticks_per_second)
	return start - _robot.battery.get_current()


func _tolerance(drain_per_second: float) -> float:
	return drain_per_second * FRAME_SLACK / Engine.physics_ticks_per_second


func test_r_003_01_robot_battery_starts_full() -> void:
	assert_not_null(_robot.battery, "the robot exposes its BatteryComponent")
	if _robot.battery == null:
		return
	assert_eq(_robot.battery.get_current(), 100.0, "full battery of the basic Core")


func test_r_003_02_idle_robot_drains() -> void:
	var drained: float = await _drained_in_one_second()
	assert_almost_eq(drained, 0.1, _tolerance(0.1), "0.1/s standing still")


func test_r_003_03_walking_robot_drains_more() -> void:
	Input.action_press(&"move_forward")
	var drained: float = await _drained_in_one_second()
	assert_almost_eq(drained, 0.15, _tolerance(0.15), "0.15/s walking")


func test_r_003_04_running_robot_drains_most() -> void:
	Input.action_press(&"move_forward")
	Input.action_press(&"run")
	var drained: float = await _drained_in_one_second()
	assert_almost_eq(drained, 0.25, _tolerance(0.25), "0.25/s running")


func test_r_003_04_run_intent_without_moving_is_idle() -> void:
	Input.action_press(&"run")
	var drained: float = await _drained_in_one_second()
	assert_almost_eq(drained, 0.1, _tolerance(0.1), "holding run while standing only drains passively")
