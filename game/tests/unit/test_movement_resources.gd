extends GutTest
## R-002-14: speeds, thresholds and camera framing live in .tres resources.
## R-004-17: so does the interaction range.
## R-013-19: and how long a move highlights its destination slots.
## The expected values mirror BALANCE.md §4.2 and §11; update both together.

const BASIC_LEGS_PATH := "res://resources/movement/basic_legs.tres"
const CONTROLS_PATH := "res://resources/config/controls.tres"
const CAMERA_PATH := "res://resources/config/camera.tres"


func test_r_002_14_basic_legs_match_balance_4_2() -> void:
	var stats: MovementStatsData = load(BASIC_LEGS_PATH) as MovementStatsData
	assert_not_null(stats, "basic_legs.tres exists and is a MovementStatsData")
	if stats == null:
		return
	assert_eq(stats.walk_speed, 3.0, "walk speed (BALANCE §4.2)")
	assert_eq(stats.run_speed, 4.8, "run speed (BALANCE §4.2)")
	assert_true(stats.can_run, "basic legs can run")


func test_r_002_14_controls_match_balance_11() -> void:
	var config: ControlConfigData = load(CONTROLS_PATH) as ControlConfigData
	assert_not_null(config, "controls.tres exists and is a ControlConfigData")
	if config == null:
		return
	assert_eq(config.joystick_dead_zone_ratio, 0.15, "dead zone (BALANCE §11)")
	assert_eq(config.joystick_run_ratio, 0.8, "run threshold (BALANCE §11)")
	assert_eq(config.joystick_walk_back_ratio, 0.7, "walk-back threshold (BALANCE §11)")
	assert_eq(config.turn_speed_rad, 10.0, "turn speed (BALANCE §11)")


func test_r_004_17_interaction_range_matches_balance() -> void:
	var config: ControlConfigData = load(CONTROLS_PATH) as ControlConfigData
	assert_not_null(config, "controls.tres exists and is a ControlConfigData")
	if config == null:
		return
	assert_eq(config.interaction_range_m, 2.0, "interaction range (BALANCE §11)")


func test_r_013_19_highlight_matches_balance() -> void:
	var config: ControlConfigData = load(CONTROLS_PATH) as ControlConfigData
	assert_not_null(config, "controls.tres exists and is a ControlConfigData")
	if config == null:
		return
	assert_eq(config.move_highlight_s, 0.4, "destination slot highlight (BALANCE §11)")


func test_r_002_14_camera_matches_balance_11() -> void:
	var config: CameraConfigData = load(CAMERA_PATH) as CameraConfigData
	assert_not_null(config, "camera.tres exists and is a CameraConfigData")
	if config == null:
		return
	assert_eq(config.yaw_degrees, 45.0, "camera yaw (BALANCE §11)")
	assert_eq(config.pitch_degrees, 35.0, "camera pitch (BALANCE §11)")
	assert_eq(config.distance, 20.0, "camera physical distance (BALANCE §11)")
	assert_eq(config.ortho_size, 10.0, "orthographic size (BALANCE §11)")
