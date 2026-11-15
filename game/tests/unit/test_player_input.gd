extends GutTest
## PlayerInput (spec 005, R-005-27): while input is blocked (a UIManager screen
## is open) it gives no direction, no run intent and no interact, from the
## keyboard actions or from the joystick; unblocking brings them back.

const ACTIONS: Array[StringName] = [&"move_forward", &"run", &"interact"]

var _input: PlayerInput


func before_each() -> void:
	_input = PlayerInput.new()
	add_child_autofree(_input)


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _joystick_sample() -> JoystickLogic.Sample:
	var sample: JoystickLogic.Sample = JoystickLogic.Sample.new()
	sample.active = true
	sample.direction = Vector2.RIGHT
	sample.run_intent = true
	return sample


func test_r_005_27_not_blocked_by_default() -> void:
	assert_false(_input.is_input_blocked(), "a new PlayerInput is not blocked")


func test_r_005_27_blocked_ignores_movement_and_interact() -> void:
	Input.action_press(&"move_forward")
	Input.action_press(&"run")
	Input.action_press(&"interact")
	assert_ne(_input.get_direction(), Vector2.ZERO, "the keyboard gives a direction")
	assert_true(_input.is_run_intent(), "and the run intent")
	assert_true(_input.is_interact_just_pressed(), "and the interact press")
	_input.set_input_blocked(true)
	assert_true(_input.is_input_blocked(), "blocked")
	assert_eq(_input.get_direction(), Vector2.ZERO, "no direction while blocked")
	assert_false(_input.is_run_intent(), "no run intent while blocked")
	assert_false(_input.is_interact_just_pressed(), "no interact while blocked")
	_input.set_input_blocked(false)
	assert_ne(_input.get_direction(), Vector2.ZERO, "the direction comes back when unblocked")
	assert_true(_input.is_run_intent(), "and the run intent")


func test_r_005_27_blocked_ignores_joystick() -> void:
	_input.set_joystick_sample(_joystick_sample())
	assert_eq(_input.get_direction(), Vector2.RIGHT, "the joystick gives a direction")
	_input.set_input_blocked(true)
	assert_eq(_input.get_direction(), Vector2.ZERO, "no joystick direction while blocked")
	assert_false(_input.is_run_intent(), "no joystick run intent while blocked")
	_input.set_input_blocked(false)
	assert_eq(_input.get_direction(), Vector2.RIGHT, "the joystick comes back when unblocked")
