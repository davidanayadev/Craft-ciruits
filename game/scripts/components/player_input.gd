class_name PlayerInput
extends Node
## Single source of player input (R-002-13): merges the InputMap keyboard
## actions (PC) and the virtual joystick (touch). Gameplay reads this node and
## never touches events or keys directly.
## While blocked (a UIManager screen is open, R-005-27) it reports no input.

var _joystick_sample: JoystickLogic.Sample = null
var _input_blocked: bool = false


## Analog direction in screen space, |v| <= 1. Joystick wins while active.
func get_direction() -> Vector2:
	if _input_blocked:
		return Vector2.ZERO
	if _joystick_sample != null and _joystick_sample.active:
		return _joystick_sample.direction
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func is_run_intent() -> bool:
	if _input_blocked:
		return false
	if _joystick_sample != null and _joystick_sample.active:
		return _joystick_sample.run_intent
	return Input.is_action_pressed(&"run")


## True only on the physics frame the interact action goes down. On touch the
## HUD button asks the robot directly (R-004-14).
func is_interact_just_pressed() -> bool:
	return not _input_blocked and Input.is_action_just_pressed(&"interact")


## Blocked input gives no direction, no run intent and no interact. The robot
## keeps processing, so the battery still drains.
func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked


func is_input_blocked() -> bool:
	return _input_blocked


func set_joystick_sample(sample: JoystickLogic.Sample) -> void:
	_joystick_sample = sample


func clear_joystick() -> void:
	_joystick_sample = null
