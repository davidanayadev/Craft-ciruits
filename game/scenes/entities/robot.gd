class_name Robot
extends CharacterBody3D
## Player robot (spec 002): reads PlayerInput, applies LocomotionSystem results
## and moves with real physics. Presentation and wiring only (P3).

@export var movement_stats: MovementStatsData
@export var control_config: ControlConfigData
## Yaw source for camera-relative movement; null falls back to world axes.
@export var camera_rig: Node3D

@onready var player_input: PlayerInput = %PlayerInput


func _physics_process(delta: float) -> void:
	var camera_yaw: float = camera_rig.rotation.y if camera_rig != null else 0.0
	var world_dir: Vector3 = LocomotionSystem.world_direction(
		player_input.get_direction(), camera_yaw
	)
	velocity = LocomotionSystem.horizontal_velocity(
		world_dir, player_input.is_run_intent(), movement_stats
	)
	if world_dir != Vector3.ZERO:
		rotation.y = LocomotionSystem.rotate_toward_yaw(
			rotation.y,
			LocomotionSystem.target_yaw(world_dir),
			control_config.turn_speed_rad,
			delta
		)
	move_and_slide()
