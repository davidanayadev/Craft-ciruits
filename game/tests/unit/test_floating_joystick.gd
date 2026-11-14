extends GutTest
## Virtual joystick event handling (R-002-10/11) and touch UI visibility
## (R-002-12). Headless cannot click Controls (ADR 0002), so touch events are
## synthesized and fed straight to the handler; the real gesture is verified
## on the device (T-002-08).

const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/touch_controls.tscn")
const CONTROLS_PATH := "res://resources/config/controls.tres"

var _joystick: FloatingJoystick


func before_each() -> void:
	_joystick = FloatingJoystick.new()
	_joystick.config = load(CONTROLS_PATH) as ControlConfigData
	_joystick.size = Vector2(1080.0, 1920.0)
	add_child_autofree(_joystick)
	watch_signals(_joystick)


func _touch(index: int, pressed: bool, screen_position: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = screen_position
	_joystick._unhandled_input(event)


func _drag(index: int, screen_position: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = screen_position
	_joystick._unhandled_input(event)


func test_r_002_10_touch_in_left_half_grabs_and_centers() -> void:
	_touch(0, true, Vector2(200.0, 1000.0))
	_drag(0, Vector2(260.0, 1000.0))
	assert_signal_emitted(_joystick, "sample_changed")
	var parameters: Array = get_signal_parameters(_joystick, "sample_changed", 0)
	var sample: JoystickLogic.Sample = parameters[0]
	assert_true(sample.active, "a 40% push past the dead zone moves")
	assert_almost_eq(sample.direction.x, 1.0, 0.001, "direction relative to the touch center")


func test_r_002_10_touch_in_right_half_is_ignored() -> void:
	_touch(0, true, Vector2(800.0, 1000.0))
	_drag(0, Vector2(860.0, 1000.0))
	assert_signal_not_emitted(_joystick, "sample_changed", "the right half belongs to other controls")


func test_r_002_10_release_emits_released() -> void:
	_touch(0, true, Vector2(200.0, 1000.0))
	_touch(0, false, Vector2(200.0, 1000.0))
	assert_signal_emitted(_joystick, "released")


func test_r_002_11_second_finger_is_ignored() -> void:
	_touch(0, true, Vector2(200.0, 1000.0))
	_touch(1, true, Vector2(300.0, 1200.0))
	_drag(1, Vector2(400.0, 1200.0))
	assert_signal_not_emitted(_joystick, "sample_changed", "another finger never moves the stick")
	_drag(0, Vector2(280.0, 1000.0))
	assert_signal_emitted(_joystick, "sample_changed")


func test_r_002_12_hidden_without_touchscreen() -> void:
	var controls: TouchControls = TOUCH_CONTROLS_SCENE.instantiate() as TouchControls
	add_child_autofree(controls)
	assert_false(controls.visible, "headless has no touchscreen: touch UI hidden")


func test_r_002_12_debug_flag_forces_touch_ui() -> void:
	var controls: TouchControls = TOUCH_CONTROLS_SCENE.instantiate() as TouchControls
	controls.force_touch_debug = true
	add_child_autofree(controls)
	assert_true(controls.visible, "debug flag shows the touch UI on PC")
	assert_true(controls.joystick.accept_mouse_debug, "debug flag lets the mouse act as a touch")
