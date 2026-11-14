extends GutTest
## Pure joystick interpretation: dead zone (R-002-15), run hysteresis 80/70
## (R-002-16) and stick geometry (clamp + analog direction, part of R-002-10).
## Thresholds come from the real controls.tres so BALANCE stays the only source.

const CONTROLS_PATH := "res://resources/config/controls.tres"
const RADIUS := 100.0

var _config: ControlConfigData


func before_each() -> void:
	_config = load(CONTROLS_PATH) as ControlConfigData


func _sample(strength: float, was_running: bool) -> JoystickLogic.Sample:
	return JoystickLogic.interpret(Vector2(RADIUS * strength, 0.0), RADIUS, was_running, _config)


func test_r_002_15_below_dead_zone_produces_no_movement() -> void:
	var sample: JoystickLogic.Sample = _sample(0.14, false)
	assert_false(sample.active, "inside the dead zone the joystick is inactive")
	assert_eq(sample.direction, Vector2.ZERO, "no direction inside the dead zone")
	assert_false(sample.run_intent, "no run inside the dead zone")


func test_r_002_15_past_dead_zone_moves() -> void:
	var sample: JoystickLogic.Sample = _sample(0.2, false)
	assert_true(sample.active, "past the dead zone the joystick moves")


func test_r_002_16_run_starts_beyond_run_threshold() -> void:
	assert_false(_sample(0.79, false).run_intent, "below 80% it walks")
	assert_true(_sample(0.81, false).run_intent, "beyond 80% it runs")


func test_r_002_16_run_releases_only_below_walk_back_threshold() -> void:
	assert_true(_sample(0.75, true).run_intent, "between 70% and 80% it keeps running")
	assert_false(_sample(0.65, true).run_intent, "below 70% it walks again")
	assert_false(_sample(0.75, false).run_intent, "between 70% and 80% it keeps walking")


func test_r_002_10_offset_is_clamped_to_radius() -> void:
	assert_eq(JoystickLogic.clamp_to_radius(Vector2(300.0, 0.0), RADIUS), Vector2(RADIUS, 0.0))
	assert_eq(JoystickLogic.clamp_to_radius(Vector2(30.0, 40.0), RADIUS), Vector2(30.0, 40.0))


func test_r_002_10_direction_is_analog_and_normalized() -> void:
	var offset := Vector2(RADIUS, RADIUS)
	var sample: JoystickLogic.Sample = JoystickLogic.interpret(offset, RADIUS, false, _config)
	assert_almost_eq(sample.direction.x, 0.7071, 0.001, "diagonal x component")
	assert_almost_eq(sample.direction.y, 0.7071, 0.001, "diagonal y component")
	assert_almost_eq(sample.direction.length(), 1.0, 0.001, "direction is normalized")
