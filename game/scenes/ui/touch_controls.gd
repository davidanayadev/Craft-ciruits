class_name TouchControls
extends CanvasLayer
## Touch HUD layer. The only place that asks the platform about touch support
## (P8): gameplay reads PlayerInput and never looks at the device.

## Debug (R-002-12): forces the touch UI on PC to test the joystick with the mouse.
@export var force_touch_debug: bool = false

@onready var joystick: FloatingJoystick = %FloatingJoystick


func _ready() -> void:
	var show_touch: bool = DisplayServer.is_touchscreen_available() or force_touch_debug
	visible = show_touch
	joystick.set_process_unhandled_input(show_touch)
	joystick.accept_mouse_debug = force_touch_debug
