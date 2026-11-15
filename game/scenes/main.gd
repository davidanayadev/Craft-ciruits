extends Node
## Main scene boot (architecture §6): wires the persistent skeleton together
## (robot <-> camera rig; UI input joins in as the HUD grows). References go
## through unique names, never deep hardcoded paths (P6).

@onready var _robot: Robot = %Robot
@onready var _camera_rig: CameraRig = %CameraRig
@onready var _touch_controls: TouchControls = %TouchControls
@onready var _hud: Hud = %Hud


func _ready() -> void:
	_robot.camera_rig = _camera_rig
	_camera_rig.target = _robot
	_hud.bind(_robot)
	_touch_controls.joystick.sample_changed.connect(_on_joystick_sample_changed)
	_touch_controls.joystick.released.connect(_on_joystick_released)


func _on_joystick_sample_changed(sample: JoystickLogic.Sample) -> void:
	_robot.player_input.set_joystick_sample(sample)


func _on_joystick_released() -> void:
	_robot.player_input.clear_joystick()
