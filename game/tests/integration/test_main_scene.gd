extends GutTest
## Main scene integration (R-002-01..03): isometric camera configured from
## camera.tres, rigid follow, one directional light with shadows and a sky,
## with the architecture §6 skeleton in place. The node paths asserted here
## are the executable spec of that skeleton. Spec 003 adds the HUD bound to the
## robot's battery (R-003-11) and the provisional game over (R-003-12).
## Restarting reloads the current scene, which under GUT is the test runner,
## so the restart itself is a manual step (plan 003 §5).
## Spec 005: interacting with a box opens the loot screen (R-005-16), taking
## moves the loot to the robot (R-005-19, R-005-20), the storage button and
## action toggle the inventory screen (R-005-24), a screen blocks the robot
## without pausing the game (R-005-27) and game over closes them (R-005-29).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAMERA_PATH := "res://resources/config/camera.tres"

var _main: Node
var _config: CameraConfigData


func before_each() -> void:
	_config = load(CAMERA_PATH) as CameraConfigData
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)


func after_each() -> void:
	for action: StringName in [&"move_forward", &"interact"]:
		Input.action_release(action)
	_send_open_storage(false)


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
	# The box is offered until it is emptied (R-005-21 replaces R-004-24).
	var contents: InventoryComponent = box.get_contents()
	var every_slot: Array[int] = []
	every_slot.assign(range(contents.get_slot_count()))
	assert_true(_robot().inventory.take_from(contents, every_slot).ok, "the robot takes everything")
	await wait_physics_frames(4)
	assert_false(button.visible, "the emptied box is no longer offered")


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


func _ui_manager() -> UIManager:
	return _main.get_node("UI/UIManager") as UIManager


func _hud() -> Hud:
	return _main.get_node("UI/Hud") as Hud


func _storage_button() -> Button:
	return _hud().get_node("%StorageButton") as Button


## Screens still open, bottom first.
func _open_screens() -> Array[UIScreen]:
	var screens: Array[UIScreen] = []
	for child: Node in _ui_manager().get_children():
		var screen: UIScreen = child as UIScreen
		if screen != null and not screen.is_queued_for_deletion():
			screens.append(screen)
	return screens


func _send_open_storage(pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"open_storage"
	event.pressed = pressed
	Input.parse_input_event(event)


## Contents of an inventory as "item id → quantity".
func _held(inventory: InventoryComponent) -> Dictionary[StringName, int]:
	var held: Dictionary[StringName, int] = {}
	for stack: ItemStack in inventory.get_slots():
		if stack != null:
			held[stack.item.id] = held.get(stack.item.id, 0) + stack.quantity
	return held


## Fills every slot of the robot with full stacks of cables: nothing else fits.
func _fill_robot_inventory() -> void:
	var inventory: InventoryComponent = _robot().inventory
	var cables: ItemData = DataRegistry.get_item(&"cables")
	var result: InventoryAddResult = inventory.add(
		&"cables", cables.stack_max * inventory.get_slot_count()
	)
	assert_true(result.ok, "test setup: the robot's inventory is full of cables")


func test_r_005_16_ui_manager_below_hud() -> void:
	var manager: UIManager = _ui_manager()
	assert_not_null(manager, "UIManager exists under UI")
	if manager == null:
		return
	assert_not_null(manager.catalog, "with its screen catalog")
	# Drawn below the HUD: battery, message and storage button stay on top.
	assert_lt(manager.get_index(), _hud().get_index(), "UIManager comes before Hud in UI")


func test_r_005_16_interacting_opens_loot_screen() -> void:
	var box: LootBox = await _go_to_first_box()
	assert_false(_ui_manager().is_modal_open(), "no screen before interacting")
	_robot().request_interact()
	assert_true(_ui_manager().is_modal_open(), "interacting with a box opens a screen")
	var screens: Array[UIScreen] = _open_screens()
	assert_eq(screens.size(), 1, "one screen")
	if screens.size() != 1:
		return
	assert_true(screens[0] is LootScreen, "the loot screen")
	var source_grid: InventoryGrid = screens[0].get_node("%SourceGrid") as InventoryGrid
	var player_grid: InventoryGrid = screens[0].get_node("%PlayerGrid") as InventoryGrid
	assert_eq(
		source_grid.get_child_count(), box.get_contents().get_slot_count(), "showing the box's slots"
	)
	assert_eq(
		player_grid.get_child_count(), _robot().inventory.get_slot_count(), "and the robot's slots"
	)


func test_r_005_19_open_box_take_all_fills_inventory() -> void:
	var box: LootBox = await _go_to_first_box()
	_robot().request_interact()
	var loot: Dictionary[StringName, int] = _held(box.get_contents())
	assert_gt(loot.size(), 0, "the box holds loot")
	var screens: Array[UIScreen] = _open_screens()
	if screens.size() != 1:
		fail_test("the loot screen did not open")
		return
	(screens[0].get_node("%TakeAllButton") as Button).pressed.emit()
	assert_eq(_held(_robot().inventory), loot, "the robot now holds what the box had")
	assert_true(box.get_contents().is_empty(), "and the box is empty")
	assert_false(_ui_manager().is_modal_open(), "the loot screen closed by itself (R-005-21)")
	var interactable: InteractableComponent = box.get_node("%Interactable") as InteractableComponent
	assert_false(interactable.enabled, "and the box is disabled (R-005-21)")


func test_r_005_20_full_inventory_keeps_rest_in_box() -> void:
	_fill_robot_inventory()
	var box: LootBox = await _go_to_first_box()
	watch_signals(box)
	_robot().request_interact()
	var loot: Dictionary[StringName, int] = _held(box.get_contents())
	var screens: Array[UIScreen] = _open_screens()
	if screens.size() != 1:
		fail_test("the loot screen did not open")
		return
	(screens[0].get_node("%TakeAllButton") as Button).pressed.emit()
	assert_eq(_held(box.get_contents()), loot, "what does not fit stays in the box")
	var message: Label = _hud().get_node("%MessageLabel") as Label
	assert_true(message.visible, "the HUD says the inventory is full")
	assert_eq(message.text, String(InventoryComponent.MSG_INVENTORY_FULL), "with its key")
	assert_true(_ui_manager().is_modal_open(), "the screen stays open: the box is not empty")
	var interactable: InteractableComponent = box.get_node("%Interactable") as InteractableComponent
	assert_true(interactable.enabled, "the box stays interactable")
	_storage_button().pressed.emit()
	assert_false(_ui_manager().is_modal_open(), "the player closes the screen")
	_robot().request_interact()
	assert_true(_ui_manager().is_modal_open(), "and can open the box again")
	assert_eq(_held(box.get_contents()), loot, "which shows the same contents")
	assert_signal_emit_count(box, "loot_generated", 1, "without a new roll")


func test_r_005_22_opener_without_inventory_reports_error() -> void:
	var box: LootBox = _zone().get_boxes()[0]
	var stranger: Node3D = Node3D.new()
	stranger.name = "Stranger"
	add_child_autofree(stranger)
	(box.get_node("%Interactable") as InteractableComponent).interact(stranger)
	assert_push_error("'Stranger' opened the box '%s'" % box.name)
	assert_false(_ui_manager().is_modal_open(), "no screen is opened")
	assert_true(box.is_opened(), "the roll already happened")
	assert_false(box.get_contents().is_empty(), "and its contents are untouched")


func test_r_005_24_storage_toggles_inventory() -> void:
	_storage_button().pressed.emit()
	var screens: Array[UIScreen] = _open_screens()
	assert_eq(screens.size(), 1, "the storage button opens a screen")
	if screens.size() == 1:
		assert_true(screens[0] is InventoryScreen, "the inventory screen")
		var grid: InventoryGrid = screens[0].get_node("%Grid") as InventoryGrid
		assert_eq(
			grid.get_child_count(), _robot().inventory.get_slot_count(), "with the robot's slots"
		)
	_storage_button().pressed.emit()
	assert_false(_ui_manager().is_modal_open(), "the same button closes it")
	_send_open_storage(true)
	await wait_process_frames(2)
	assert_true(_ui_manager().is_modal_open(), "the open_storage action opens it too")
	_send_open_storage(false)
	await wait_process_frames(2)
	assert_true(_ui_manager().is_modal_open(), "releasing the action does nothing")
	_send_open_storage(true)
	await wait_process_frames(2)
	assert_false(_ui_manager().is_modal_open(), "and the action closes it")


func test_r_005_24_storage_closes_loot_screen() -> void:
	await _go_to_first_box()
	_robot().request_interact()
	assert_true(_ui_manager().is_modal_open(), "the loot screen is open")
	_storage_button().pressed.emit()
	assert_false(_ui_manager().is_modal_open(), "storage closes the top screen")
	assert_eq(_open_screens().size(), 0, "and does not open the inventory on top")


func test_r_005_27_robot_still_battery_drains() -> void:
	var box: LootBox = await _go_to_first_box()
	var robot: Robot = _robot()
	var interact_button: Button = _hud().get_node("%InteractButton") as Button
	assert_true(interact_button.visible, "next to a box the interact button is offered")
	_storage_button().pressed.emit()
	assert_true(_ui_manager().is_modal_open(), "the inventory screen is open")
	assert_false(interact_button.visible, "the interact button hides while a screen is open")
	var start_position: Vector3 = robot.global_position
	var start_battery: float = robot.battery.get_current()
	Input.action_press(&"move_forward")
	Input.action_press(&"interact")
	await wait_physics_frames(10)
	interact_button.pressed.emit()
	assert_eq(robot.global_position, start_position, "the robot does not move")
	assert_false(box.is_opened(), "nor interact, by key or by HUD button")
	assert_lt(robot.battery.get_current(), start_battery, "the battery keeps draining")
	assert_false(get_tree().paused, "the game is not paused")
	Input.action_release(&"interact")
	_storage_button().pressed.emit()
	await wait_physics_frames(10)
	assert_ne(robot.global_position, start_position, "with the screen closed the robot moves again")


func test_r_005_29_game_over_closes_and_blocks_screens() -> void:
	_storage_button().pressed.emit()
	assert_true(_ui_manager().is_modal_open(), "the inventory screen is open")
	var robot: Robot = _robot()
	robot.battery.consume(robot.battery.get_current())
	assert_true(robot.battery.is_depleted(), "the battery is depleted")
	assert_false(_ui_manager().is_modal_open(), "game over closes every screen")
	_storage_button().pressed.emit()
	assert_false(_ui_manager().is_modal_open(), "and the storage button opens none")
	_send_open_storage(true)
	await wait_process_frames(2)
	assert_false(_ui_manager().is_modal_open(), "nor does the open_storage action")
