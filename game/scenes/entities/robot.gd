class_name Robot
extends CharacterBody3D
## Player robot (spec 002): reads PlayerInput, applies LocomotionSystem results
## and moves with real physics. Presentation and wiring only (P3).
## It also feeds its gait to its BatteryComponent every physics frame (spec 003).

@export var movement_stats: MovementStatsData
@export var control_config: ControlConfigData
## Yaw source for camera-relative movement; null falls back to world axes.
@export var camera_rig: Node3D

@onready var player_input: PlayerInput = %PlayerInput
@onready var battery: BatteryComponent = %BatteryComponent


func _physics_process(delta: float) -> void:
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
