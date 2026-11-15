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


func _zone() -> FarmZone:
	var slot: Node = _main.get_node("World/ZoneSlot")
	if slot.get_child_count() != 1:
		return null
	return slot.get_child(0) as FarmZone


## Moves the robot next to the first box of the zone and waits for its
## interactor to pick it up.
func _go_to_first_box() -> LootBox:
	var box: LootBox = _zone().get_boxes()[0]
	_robot().global_position = box.global_position + Vector3(1.6, 0.0, 0.0)
	await wait_physics_frames(4)
	return box


func test_r_004_05_green_zone_loaded() -> void:
	var slot: Node = _main.get_node("World/ZoneSlot")
	assert_eq(slot.get_child_count(), 1, "one zone loaded in ZoneSlot")
	var zone: FarmZone = _zone()
	assert_not_null(zone, "the loaded zone is a FarmZone")
	if zone == null:
		return
	assert_eq(zone.data.zone_id, Vector2i(0, 0), "it is the green zone, zone (0, 0)")
	assert_between(
		zone.get_boxes().size(),
		zone.data.box_count_min,
		zone.data.box_count_max,
		"Main generated its boxes"
	)


func test_r_004_05_zone_generated_from_world_seed() -> void:
	var zone: FarmZone = _zone()
	var reference: FarmZone = (
		load("res://scenes/farm_zone/farm_zone_green.tscn") as PackedScene
	).instantiate() as FarmZone
	add_child_autofree(reference)
	reference.generate(GameManager.get_world_seed())
	var expected: Array[Vector3] = []
	for box: LootBox in reference.get_boxes():
		expected.append(box.position)
	var actual: Array[Vector3] = []
	for box: LootBox in zone.get_boxes():
		actual.append(box.position)
	assert_eq(actual, expected, "the boxes are those of GameManager's world seed")


func test_r_004_05_robot_at_spawn_point() -> void:
	var zone: FarmZone = _zone()
	var distance: float = _robot().global_position.distance_to(zone.get_spawn_position())
	assert_lt(distance, 0.01, "the robot starts on the zone's spawn point")


func test_r_004_13_hud_button_follows_robot_target() -> void:
	var button: Button = _main.get_node("UI/Hud").get_node("%InteractButton") as Button
	await wait_physics_frames(4)
	assert_false(button.visible, "no button at the spawn point, away from every box")
	await _go_to_first_box()
	assert_true(button.visible, "the button appears next to a box")
	assert_eq(button.text, "PROMPT_OPEN", "with the box's prompt")


func test_r_004_14_hud_button_opens_box() -> void:
	var button: Button = _main.get_node("UI/Hud").get_node("%InteractButton") as Button
	var box: LootBox = await _go_to_first_box()
	button.pressed.emit()
	assert_true(box.is_opened(), "pressing the HUD button opens the box")
	await wait_physics_frames(4)
	assert_false(button.visible, "the opened box is no longer offered")


func test_r_004_14_interact_action_opens_box_in_main() -> void:
	var box: LootBox = await _go_to_first_box()
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	assert_true(box.is_opened(), "the interact action opens the box")


func test_r_004_16_no_interaction_after_game_over() -> void:
	var button: Button = _main.get_node("UI/Hud").get_node("%InteractButton") as Button
	var box: LootBox = await _go_to_first_box()
	var robot: Robot = _robot()
	robot.battery.consume(robot.battery.get_current())
	await wait_physics_frames(2)
	button.pressed.emit()
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	assert_false(box.is_opened(), "a depleted robot opens nothing")
