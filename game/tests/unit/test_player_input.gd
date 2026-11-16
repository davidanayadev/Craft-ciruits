extends GutTest
## PlayerInput (spec 005, R-005-27): while input is blocked (a UIManager screen
## is open) it gives no direction, no run intent and no interact, from the
## keyboard actions or from the joystick; unblocking brings them back.
## Spec 007, the attack: a press is reported once and not kept (R-007-07),
## nothing is reported while blocked (R-007-09), and it comes only from events
## no control consumed or from the HUD attack button, never from the action
## state alone, which a click on any HUD button also sets (R-007-15).

const ACTIONS: Array[StringName] = [&"move_forward", &"run", &"interact", &"attack"]
## Frames for a parsed event to reach _unhandled_input.
const INPUT_FRAMES := 2

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


func _attack_action(pressed: bool) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"attack"
	event.pressed = pressed
	return event


func _left_click(device: int) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func test_r_007_07_poll_clears_press() -> void:
	assert_false(_input.poll_attack(), "no attack without input")
	# A tap shorter than a physics step: down and up before the next poll.
	_input._unhandled_input(_attack_action(true))
	_input._unhandled_input(_attack_action(false))
	assert_true(_input.poll_attack(), "the tap is reported once")
	assert_false(_input.poll_attack(), "and not kept for the next step")


func test_r_007_07_button_tap_reported_once() -> void:
	_input.set_attack_button_held(true)
	_input.set_attack_button_held(false)
	assert_true(_input.poll_attack(), "a tap on the HUD button is one press")
	assert_false(_input.poll_attack(), "and only one")


func test_r_007_07_button_held_keeps_attacking() -> void:
	_input.set_attack_button_held(true)
	assert_true(_input.poll_attack(), "held: attack")
	assert_true(_input.poll_attack(), "still held: still attack")
	_input.set_attack_button_held(false)
	assert_false(_input.poll_attack(), "released: no attack")


func test_r_007_09_blocked_reports_no_attack() -> void:
	_input.set_attack_button_held(true)
	_input.set_input_blocked(true)
	assert_false(_input.poll_attack(), "no attack while blocked, even with the button held")
	_input.set_input_blocked(false)
	assert_true(_input.poll_attack(), "the held button counts again when unblocked")


func test_r_007_09_press_while_blocked_not_kept() -> void:
	_input.set_input_blocked(true)
	_input._unhandled_input(_attack_action(true))
	_input._unhandled_input(_attack_action(false))
	assert_false(_input.poll_attack(), "no attack while blocked")
	_input.set_input_blocked(false)
	assert_false(_input.poll_attack(), "and the press is gone when the screen closes")


func test_r_007_15_unhandled_attack_counts() -> void:
	Input.parse_input_event(_attack_action(true))
	await wait_process_frames(INPUT_FRAMES)
	assert_true(_input.poll_attack(), "an attack event nobody consumed is an attack")
	assert_true(_input.poll_attack(), "and it stays held")
	Input.parse_input_event(_attack_action(false))
	await wait_process_frames(INPUT_FRAMES)
	assert_false(_input.poll_attack(), "until the action is released")


func test_r_007_15_action_state_alone_is_not_attack() -> void:
	# What a click on a HUD button leaves behind: the action is down for Input,
	# but the control consumed the event.
	Input.action_press(&"attack")
	assert_false(_input.poll_attack(), "the action state alone is no attack")


func test_r_007_15_mouse_click_counts_only_from_the_mouse() -> void:
	_input._unhandled_input(_left_click(InputEvent.DEVICE_ID_MOUSE))
	assert_true(_input.poll_attack(), "a left click nobody consumed is an attack")


func test_r_007_15_emulated_mouse_ignored() -> void:
	# A touch on the scenery or on the joystick also arrives as an emulated
	# left click, which must not swing.
	_input._unhandled_input(_left_click(InputEvent.DEVICE_ID_EMULATION))
	assert_false(_input.poll_attack(), "a mouse click emulated from a touch is no attack")


func test_r_007_15_not_stuck_after_release() -> void:
	Input.action_press(&"attack")
	_input._unhandled_input(_attack_action(true))
	assert_true(_input.poll_attack(), "held")
	# The release ends in a control and never reaches _unhandled_input.
	Input.action_release(&"attack")
	assert_false(_input.poll_attack(), "the attack does not stay stuck")
	Input.action_press(&"attack")
	assert_false(_input.poll_attack(), "and a later click on the HUD does not bring it back")
