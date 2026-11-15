extends Node
## Main scene boot (architecture §6): wires the persistent skeleton together
## (robot <-> camera rig; UI input joins in as the HUD grows). References go
## through unique names, never deep hardcoded paths (P6).
## Until ZoneLoader exists (spec 009) the green zone sits in ZoneSlot from the
## start: Main generates it from the world seed and puts the robot on its
## spawn point (spec 004).

@onready var _robot: Robot = %Robot
@onready var _camera_rig: CameraRig = %CameraRig
@onready var _touch_controls: TouchControls = %TouchControls
@onready var _hud: Hud = %Hud
@onready var _world: Node3D = %World
@onready var _zone: FarmZone = %GreenZone
@onready var _game_over_screen: GameOverScreen = %GameOverScreen


func _ready() -> void:
	_zone.generate(GameManager.get_world_seed())
	_robot.global_position = _zone.get_spawn_position()
	_robot.camera_rig = _camera_rig
	_camera_rig.target = _robot
	_hud.bind(_robot)
	_hud.interact_pressed.connect(_robot.request_interact)
	_touch_controls.joystick.sample_changed.connect(_on_joystick_sample_changed)
	_touch_controls.joystick.released.connect(_on_joystick_released)
	_robot.battery.battery_depleted.connect(_on_battery_depleted)
	_game_over_screen.restart_requested.connect(_on_restart_requested)


func _on_joystick_sample_changed(sample: JoystickLogic.Sample) -> void:
	_robot.player_input.set_joystick_sample(sample)


func _on_joystick_released() -> void:
	_robot.player_input.clear_joystick()


## Provisional game over (spec 003); spec 008 replaces it with the ruleset and
## the respawn. Disabling World freezes the robot and the zone without pausing
## the tree, so no global state survives the reload.
func _on_battery_depleted() -> void:
	# Deferred: the signal arrives in the middle of the robot's physics frame,
	# and disabling World there removes its body from the physics space while
	# it is still moving.
	_freeze_world.call_deferred()
	_game_over_screen.open()


func _freeze_world() -> void:
	_world.process_mode = Node.PROCESS_MODE_DISABLED


func _on_restart_requested() -> void:
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("Main: could not reload the scene to restart (error %d)." % error)
