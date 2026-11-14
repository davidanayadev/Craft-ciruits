class_name FloatingJoystick
extends Control
## Floating virtual joystick (R-002-10/11): appears where a touch starts in
## the left half of the screen, tracks only that finger and interprets the
## offset through JoystickLogic. Only this script reads touch events; the
## gameplay consumes the emitted samples via PlayerInput (R-002-13).

signal sample_changed(sample: JoystickLogic.Sample)
signal released

const NO_TOUCH := -1
## Index real touches never produce; used by the mouse debug mode (R-002-12).
const MOUSE_INDEX := -1000

@export var config: ControlConfigData
## Stick radius in pixels: UI layout, not a gameplay value (BALANCE owns those).
@export var radius: float = 150.0
## Debug only (R-002-12): lets the left mouse button act as a touch on PC.
var accept_mouse_debug: bool = false

var _touch_index: int = NO_TOUCH
var _center: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
var _was_running: bool = false


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		_handle_touch(touch)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		if drag.index == _touch_index:
			_update_offset(drag.position)
		return
	if accept_mouse_debug:
		_handle_mouse(event)


func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_try_grab(touch.index, touch.position)
	elif touch.index == _touch_index:
		_release()


func _handle_mouse(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_try_grab(MOUSE_INDEX, button.position)
		elif _touch_index == MOUSE_INDEX:
			_release()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _touch_index == MOUSE_INDEX:
		_update_offset(motion.position)


func _try_grab(index: int, screen_position: Vector2) -> void:
	if _touch_index != NO_TOUCH:
		return  # another finger already owns the stick (R-002-11)
	if screen_position.x >= size.x * 0.5:
		return  # only the left half spawns the stick (R-002-10)
	_touch_index = index
	_center = screen_position
	_offset = Vector2.ZERO
	_was_running = false
	queue_redraw()


func _update_offset(screen_position: Vector2) -> void:
	_offset = JoystickLogic.clamp_to_radius(screen_position - _center, radius)
	var sample: JoystickLogic.Sample = JoystickLogic.interpret(
		_offset, radius, _was_running, config
	)
	_was_running = sample.run_intent
	sample_changed.emit(sample)
	queue_redraw()


func _release() -> void:
	_touch_index = NO_TOUCH
	_offset = Vector2.ZERO
	_was_running = false
	released.emit()
	queue_redraw()


func _draw() -> void:
	if _touch_index == NO_TOUCH:
		return
	draw_circle(_center, radius, Color(1.0, 1.0, 1.0, 0.1))
	draw_circle(_center + _offset, radius * 0.4, Color(1.0, 1.0, 1.0, 0.35))
