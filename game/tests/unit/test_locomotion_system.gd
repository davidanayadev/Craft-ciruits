extends GutTest
## Pure locomotion rules: camera-relative direction (R-002-05), run speed
## (R-002-06), smooth turn (R-002-07), immediate stop (R-002-08), fixed speed
## per gait (R-002-17) and no legs -> no run (R-002-18).
## Speeds come from the real basic_legs.tres (BALANCE §4.2 single source).

const BASIC_LEGS_PATH := "res://resources/movement/basic_legs.tres"

var _legs: MovementStatsData


func before_each() -> void:
	_legs = load(BASIC_LEGS_PATH) as MovementStatsData


func test_r_002_05_direction_is_camera_relative() -> void:
	var direction: Vector3 = LocomotionSystem.world_direction(Vector2(0.0, -1.0), deg_to_rad(45.0))
	assert_almost_eq(direction.x, -0.7071, 0.001, "screen-up maps to camera forward (x)")
	assert_almost_eq(direction.z, -0.7071, 0.001, "screen-up maps to camera forward (z)")
	assert_eq(direction.y, 0.0, "movement stays on the ground plane")


func test_r_002_05_walk_speed_matches_legs() -> void:
	var velocity: Vector3 = LocomotionSystem.horizontal_velocity(Vector3.FORWARD, false, _legs)
	assert_almost_eq(velocity.length(), 3.0, 0.001, "walking speed of basic legs")


func test_r_002_06_run_speed_matches_legs() -> void:
	var velocity: Vector3 = LocomotionSystem.horizontal_velocity(Vector3.FORWARD, true, _legs)
	assert_almost_eq(velocity.length(), 4.8, 0.001, "running speed of basic legs")


func test_r_002_17_speed_is_fixed_not_proportional() -> void:
	var short_push: Vector3 = Vector3(0.2, 0.0, 0.0)
	var velocity: Vector3 = LocomotionSystem.horizontal_velocity(short_push, false, _legs)
	assert_almost_eq(velocity.length(), 3.0, 0.001, "a soft push still walks at full walk speed")


func test_r_002_18_no_legs_no_run() -> void:
	var no_legs: MovementStatsData = MovementStatsData.new()
	no_legs.walk_speed = 0.5
	no_legs.run_speed = 0.0
	no_legs.can_run = false
	var velocity: Vector3 = LocomotionSystem.horizontal_velocity(Vector3.FORWARD, true, no_legs)
	assert_almost_eq(velocity.length(), 0.5, 0.001, "run input without legs keeps walk speed")


func test_r_002_08_no_input_means_zero_velocity() -> void:
	assert_eq(LocomotionSystem.horizontal_velocity(Vector3.ZERO, false, _legs), Vector3.ZERO)
	assert_eq(LocomotionSystem.horizontal_velocity(Vector3.ZERO, true, _legs), Vector3.ZERO)
	assert_eq(LocomotionSystem.world_direction(Vector2.ZERO, deg_to_rad(45.0)), Vector3.ZERO)


func test_r_002_07_target_yaw_faces_movement_direction() -> void:
	assert_almost_eq(LocomotionSystem.target_yaw(Vector3(0.0, 0.0, -1.0)), 0.0, 0.001)
	assert_almost_eq(LocomotionSystem.target_yaw(Vector3(1.0, 0.0, 0.0)), -PI / 2.0, 0.001)


func test_r_002_07_turn_steps_toward_target() -> void:
	var yaw: float = LocomotionSystem.rotate_toward_yaw(0.0, 2.0, 10.0, 0.016)
	assert_almost_eq(yaw, 0.16, 0.001, "one frame advances turn_speed * delta")


func test_r_002_07_turn_does_not_overshoot() -> void:
	var yaw: float = LocomotionSystem.rotate_toward_yaw(1.0, 1.05, 10.0, 0.016)
	assert_almost_eq(yaw, 1.05, 0.001, "close targets are reached exactly")


func test_r_002_07_turn_takes_shortest_path() -> void:
	var yaw: float = LocomotionSystem.rotate_toward_yaw(3.0, -3.0, 10.0, 0.016)
	assert_almost_eq(yaw, -3.1232, 0.001, "crosses the -PI/PI seam instead of going around")
