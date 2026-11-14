class_name PlayerInput
extends Node
## Single source of movement input (R-002-13): merges the InputMap keyboard
## actions (PC) and the virtual joystick (touch). Gameplay reads this node and
## never touches events or keys directly.

var _joystick_sample: JoystickLogic.Sample = null


## Analog direction in screen space, |v| <= 1. Joystick wins while active.
func get_direction() -> Vector2:
	if _joystick_sample != null and _joystick_sample.active:
		return _joystick_sample.direction
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func is_run_intent() -> bool:
	if _joystick_sample != null and _joystick_sample.active:
		return _joystick_sample.run_intent
	return Input.is_action_pressed(&"run")


func set_joystick_sample(sample: JoystickLogic.Sample) -> void:
	_joystick_sample = sample


func clear_joystick() -> void:
	_joystick_sample = null
