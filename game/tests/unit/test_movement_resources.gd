extends GutTest
## R-002-14: speeds, thresholds and camera framing live in .tres resources.
## R-004-17: so does the interaction range.
## R-013-19: and how long a move highlights its destination slots.
## Since spec 015 the legs' numbers are modifiers of the basic legs piece over
## the robot's base stats (R-015-02).
## The expected values mirror BALANCE.md §4.2 and §11; update both together.

const BASE_STATS_PATH := "res://resources/robot/robot_base_stats.tres"
const BASIC_LEGS_PATH := "res://resources/pieces/basic_legs.tres"
const CONTROLS_PATH := "res://resources/config/controls.tres"
const CAMERA_PATH := "res://resources/config/camera.tres"


## Movement of the robot with only legs_path equipped (no legs when empty).
func _movement_with(legs_path: String) -> MovementStatsData:
	var stats: StatsComponent = StatsComponent.new()
	stats.base_stats = load(BASE_STATS_PATH) as RobotBaseStatsData
	add_child_autofree(stats)
	if not legs_path.is_empty():
		var legs: PieceData = load(legs_path) as PieceData
		stats.recompute(legs.modifiers)
	return stats.get_movement()


func test_r_002_14_basic_legs_match_balance_4_2() -> void:
	var stats: MovementStatsData = _movement_with(BASIC_LEGS_PATH)
	assert_eq(stats.walk_speed, 3.0, "walk speed (BALANCE §4.2)")
	assert_eq(stats.run_speed, 4.8, "run speed (BALANCE §4.2)")
	assert_true(stats.can_run, "basic legs can run")


func test_r_002_14_no_legs_match_balance_4_2() -> void:
	var stats: MovementStatsData = _movement_with("")
	assert_eq(stats.walk_speed, 0.5, "walk speed without legs (BALANCE §4.2)")
	assert_false(stats.can_run, "without legs it cannot run (BALANCE §4.2)")


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
