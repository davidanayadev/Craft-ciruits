class_name Robot
extends CharacterBody3D
## Player robot (spec 002): reads PlayerInput, applies LocomotionSystem results
## and moves with real physics. Presentation and wiring only (P3).
## It also feeds its gait to its BatteryComponent every physics frame (spec 003)
## and interacts with the target of its InteractorComponent (spec 004).

@export var movement_stats: MovementStatsData
@export var control_config: ControlConfigData
## Yaw source for camera-relative movement; null falls back to world axes.
@export var camera_rig: Node3D

@onready var player_input: PlayerInput = %PlayerInput
@onready var battery: BatteryComponent = %BatteryComponent
@onready var interactor: InteractorComponent = %Interactor


func _physics_process(delta: float) -> void:
	if player_input.is_interact_just_pressed():
		request_interact()
	var camera_yaw: float = camera_rig.rotation.y if camera_rig != null else 0.0
	var world_dir: Vector3 = LocomotionSystem.world_direction(
		player_input.get_direction(), camera_yaw
	)
	var run_intent: bool = player_input.is_run_intent()
	velocity = LocomotionSystem.horizontal_velocity(world_dir, run_intent, movement_stats)
	# The gait comes from the intent, not from the real displacement: pushing
	# against a wall drains like walking (plan 003 §7).
	battery.tick(delta, LocomotionSystem.gait(world_dir, run_intent, movement_stats))
	if world_dir != Vector3.ZERO:
		rotation.y = LocomotionSystem.rotate_toward_yaw(
			rotation.y,
			LocomotionSystem.target_yaw(world_dir),
			control_config.turn_speed_rad,
			delta
		)
	move_and_slide()


## Interacts with the nearest interactable in range, if any. Both input paths
## end here: the interact action and the HUD button. A robot with a depleted
## battery does nothing (R-004-16).
func request_interact() -> void:
	if battery.is_depleted():
		return
	interactor.interact_with_target(self)
