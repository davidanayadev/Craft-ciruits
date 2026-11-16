class_name PlayerInput
extends Node
## Single source of player input (R-002-13): merges the InputMap keyboard
## actions (PC) and the virtual joystick (touch). Gameplay reads this node and
## never touches events or keys directly.
## While blocked (a UIManager screen is open, R-005-27) it reports no input.
## The attack (spec 007) is not polled from Input: the action state changes
## before the GUI gets the event, so a click on a HUD button would count as an
## attack (R-007-15). It is taken from unhandled events and from the HUD attack
## button instead.

var _joystick_sample: JoystickLogic.Sample = null
var _input_blocked: bool = false
## The attack action went down in an event no control consumed.
var _attack_action_down: bool = false
var _attack_button_held: bool = false
## A press since the last poll_attack(), so a tap shorter than a physics step
## is not lost.
var _attack_press_pending: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_attack_action_down = true
		_attack_press_pending = true
	elif event.is_action_released(&"attack"):
		_attack_action_down = false


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


## True while the attack is held (action or HUD button) or if it was pressed
## since the last call; the call clears that press, so one that cannot become a
## swing is not kept for later (R-007-07). Call it once per physics step.
## False while blocked (R-007-09).
func poll_attack() -> bool:
	var pressed: bool = _attack_press_pending
	_attack_press_pending = false
	# The release can end in a control and never arrive here; the action state
	# then says it is up, and a later click on the HUD must not bring it back.
	if _attack_action_down and not Input.is_action_pressed(&"attack"):
		_attack_action_down = false
	if _input_blocked:
		return false
	return pressed or _attack_action_down or _attack_button_held


## The HUD attack button went down or up.
func set_attack_button_held(held: bool) -> void:
	if held and not _attack_button_held:
		_attack_press_pending = true
	_attack_button_held = held


## Blocked input gives no direction, no run intent, no interact and no attack.
## The robot keeps processing, so the battery still drains.
func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked


func is_input_blocked() -> bool:
	return _input_blocked


func set_joystick_sample(sample: JoystickLogic.Sample) -> void:
	_joystick_sample = sample


func clear_joystick() -> void:
	_joystick_sample = null
