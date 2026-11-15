extends GutTest
## Main scene integration (R-002-01..03): isometric camera configured from
## camera.tres, rigid follow, one directional light with shadows and a sky,
## with the architecture §6 skeleton in place. The node paths asserted here
## are the executable spec of that skeleton. Spec 003 adds the HUD bound to the
## robot's battery (R-003-11) and the provisional game over (R-003-12).
## Restarting reloads the current scene, which under GUT is the test runner,
## so the restart itself is a manual step (plan 003 §5).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAMERA_PATH := "res://resources/config/camera.tres"

var _main: Node
var _config: CameraConfigData


func before_each() -> void:
	_config = load(CAMERA_PATH) as CameraConfigData
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)


func _rig() -> CameraRig:
	return _main.get_node("CameraRig") as CameraRig


func _robot() -> Robot:
	return _main.get_node("World/Players/Robot") as Robot


func test_r_002_01_camera_isometric_angles() -> void:
	var rig: CameraRig = _rig()
	assert_not_null(rig, "CameraRig exists under Main")
	if rig == null:
		return
	assert_almost_eq(rig.rotation.y, deg_to_rad(_config.yaw_degrees), 0.001, "yaw 45")
	assert_eq(rig.camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "orthographic camera")
	assert_almost_eq(rig.camera.size, _config.ortho_size, 0.001, "ortho size from camera.tres")
	assert_almost_eq(
		rig.camera.rotation.x, -deg_to_rad(_config.pitch_degrees), 0.001, "pitch 35 down"
	)


func test_r_002_02_camera_follows_robot_keeping_distance() -> void:
	var rig: CameraRig = _rig()
	var robot: Robot = _robot()
	assert_not_null(robot, "Robot exists under World/Players")
	if rig == null or robot == null:
		return
	robot.global_position = Vector3(5.0, 0.0, -3.0)
	await wait_physics_frames(2)
	var offset: float = rig.global_position.distance_to(robot.global_position)
	assert_lt(offset, 0.001, "the rig sits on the robot")
	var camera_distance: float = rig.camera.global_position.distance_to(robot.global_position)
	assert_almost_eq(camera_distance, _config.distance, 0.01, "constant camera distance")


func test_r_002_03_one_directional_light_with_shadows_and_sky() -> void:
	var lights: Array[Node] = _main.find_children("*", "DirectionalLight3D", true, false)
	assert_eq(lights.size(), 1, "exactly one directional light (PMV §3.2 budget)")
	if not lights.is_empty():
		var sun: DirectionalLight3D = lights[0] as DirectionalLight3D
		assert_true(sun.shadow_enabled, "the sun casts shadows")
	var environments: Array[Node] = _main.find_children("*", "WorldEnvironment", true, false)
	assert_eq(environments.size(), 1, "one WorldEnvironment")
	if not environments.is_empty():
		var world_environment: WorldEnvironment = environments[0] as WorldEnvironment
		assert_not_null(world_environment.environment, "environment resource set")
		assert_eq(
			world_environment.environment.background_mode,
			Environment.BG_SKY,
			"sky background"
		)
		assert_not_null(world_environment.environment.sky, "sky resource set")


func test_r_002_04_robot_wired_in_main_scene() -> void:
	var robot: Robot = _robot()
	assert_not_null(robot, "Robot instanced under World/Players")
	if robot == null:
		return
	assert_not_null(robot.camera_rig, "robot knows the camera rig for relative movement")


func test_r_003_11_hud_bound_to_robot() -> void:
	var hud: Hud = _main.get_node("UI/Hud") as Hud
	assert_not_null(hud, "Hud exists under UI")
	if hud == null:
		return
	var label: Label = hud.get_node("%BatteryLabel") as Label
	assert_eq(label.text, "100", "the HUD shows the robot's full battery from the start")
	_robot().battery.consume(30.0)
	assert_eq(label.text, "70", "the HUD follows the robot's battery")


func test_r_003_12_depletion_opens_game_over_and_freezes_world() -> void:
	var screen: GameOverScreen = _main.get_node("UI/GameOverScreen") as GameOverScreen
	assert_not_null(screen, "GameOverScreen exists under UI")
	if screen == null:
		return
	assert_false(screen.visible, "no game over while the battery has charge")
	assert_connected(screen, _main, "restart_requested")
	var robot: Robot = _robot()
	# Leaves less than one physics frame of passive drain, so the robot's own
	# tick depletes the battery: the same path as in the game.
	var one_frame_drain: float = (
		robot.battery.drain_per_second(LocomotionSystem.Gait.IDLE) / Engine.physics_ticks_per_second
	)
	robot.battery.consume(robot.battery.get_current() - one_frame_drain / 2.0)
	assert_false(robot.battery.is_depleted(), "still alive before the next tick")
	await wait_physics_frames(3)
	assert_true(robot.battery.is_depleted(), "the next tick depletes the battery")
	assert_true(screen.visible, "depletion opens the game over screen")
	var world: Node = _main.get_node("World")
	assert_eq(world.process_mode, Node.PROCESS_MODE_DISABLED, "the world stops processing")
	var frozen_position: Vector3 = robot.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(10)
	Input.action_release(&"move_forward")
	assert_eq(robot.global_position, frozen_position, "the robot no longer moves")
