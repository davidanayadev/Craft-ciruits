class_name Robot
extends CharacterBody3D
## Player robot (spec 002): reads PlayerInput, applies LocomotionSystem results
## and moves with real physics. Presentation and wiring only (P3).
## It also feeds its gait to its BatteryComponent every physics frame (spec 003)
## and interacts with the target of its InteractorComponent (spec 004).
## It owns its inventory, sized by its chassis level (spec 005).

@export var movement_stats: MovementStatsData
@export var control_config: ControlConfigData
## Inventory slots per chassis level. Only level 1 until ACTION_PLAN 2.7 adds levelling up.
@export var chassis_levels: ChassisLevelData
## Yaw source for camera-relative movement; null falls back to world axes.
@export var camera_rig: Node3D

@onready var player_input: PlayerInput = %PlayerInput
@onready var battery: BatteryComponent = %BatteryComponent
@onready var interactor: InteractorComponent = %Interactor
@onready var inventory: InventoryComponent = %InventoryComponent


func _ready() -> void:
	if chassis_levels == null:
		push_error("Robot '%s': chassis_levels must be assigned." % name)
		return
	inventory.set_slot_count(chassis_levels.get_inventory_slots(ChassisLevelData.FIRST_LEVEL))


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
## battery (R-004-16) or with its input blocked by a screen (R-005-27) does
## nothing.
func request_interact() -> void:
	if battery.is_depleted() or player_input.is_input_blocked():
		return
	interactor.interact_with_target(self)
