extends GutTest
## Main scene integration (R-002-01..03): isometric camera configured from
## camera.tres, rigid follow, one directional light with shadows and a sky,
## with the architecture §6 skeleton in place. The node paths asserted here
## are the executable spec of that skeleton. Spec 003 adds the HUD bound to the
## robot's battery (R-003-11); its provisional game over (R-003-12) is replaced
## by the death of spec 008.
## Spec 005: interacting with a box opens the loot screen (R-005-16), taking
## moves the loot to the robot (R-005-19, R-005-20), the storage button and
## action toggle the inventory screen (R-005-24), a screen blocks the robot
## without pausing the game (R-005-27) and a death closes them (R-005-29).
## Spec 006: the zombies of the first visit are in the zone from the start
## (R-006-26), taken from a prewarmed pool under World, and they keep acting
## while a screen is open (R-006-19).
## Spec 008 (the transfer is driven by advance(), never by real time): visit
## counter and repopulation (R-008-06, -09), dropped items of the zone
## (R-008-15, -16, -23, -24, -35, -39), the transfer screen and the respawn
## (R-008-29..31, -33) and the whole loop (R-008-44).
## Manual: the look of the transfer screen and the feel of the wait (plan 008 §5).
## Spec 009: the game starts in the base (R-009-08), so before_each travels to
## the green zone and waits for it (_travel_to_green_zone, plan 009 §7); a
## travel shows the loading screen with the world frozen (R-009-07), exits
## travel at no cost (R-009-11), and a death ends in the base (R-009-51..53).

const MAIN_SCENE := preload("res://scenes/main.tscn")
## Any fixed time: the tests move the fake clock from here.
const FAKE_NOW := 1_700_000_000
const MAIN_ZONE_SCENE := preload("res://scenes/farm_zone/farm_zone_green.tscn")
const CAMERA_PATH := "res://resources/config/camera.tres"
const OTHER_ZONE_ID := Vector2i(7, 7)
const GREEN_ZONE_ID := Vector2i(0, 0)
const TRAVEL_TIMEOUT_S := 10.0
## The robot respawns when the travel ends and the world runs again before the
## test reads its battery: a few frames of passive drain at most.
const RESPAWN_BATTERY_TOLERANCE := 0.05

var _main: Node
var _config: CameraConfigData


func before_each() -> void:
	# First: Main reads the visit counter of its zone in _ready.
	GameManager.clear_visit_counts()
	SaveTestSupport.start_world()
	_config = load(CAMERA_PATH) as CameraConfigData
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)
	await _travel_to_green_zone()


func after_each() -> void:
	for action: StringName in [&"move_forward", &"interact"]:
		Input.action_release(action)
	_send_open_storage(false)
	GameManager.clear_visit_counts()
	SaveTestSupport.reset()


func _loader() -> ZoneLoader:
	return _main.get_node("%ZoneLoader") as ZoneLoader


## Waits for the travel in progress (the start-up one goes to the base).
func _await_travel() -> void:
	if _loader().is_travelling():
		await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)


func _travel_to(zone_id: Vector2i) -> void:
	await _await_travel()
	_loader().travel_to(zone_id)
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)


func _travel_to_green_zone() -> void:
	await _travel_to(GREEN_ZONE_ID)


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


func _transfer() -> TransferScreen:
	return _main.get_node("UI/TransferScreen") as TransferScreen


func _world() -> Node:
	return _main.get_node("World")


func _spawner() -> DroppedItemSpawner:
	return _main.get_node("World/DroppedItems") as DroppedItemSpawner


## Empties the robot's battery and lets the deferred calls of Main run.
func _die() -> void:
	var robot: Robot = _robot()
	robot.battery.consume(robot.battery.get_current())
	await wait_process_frames(2)


## The path of the game: the robot's own physics tick empties the battery, so
## the repopulation and the freeze are queued from inside a physics step.
func test_r_008_29_death_inside_a_physics_step() -> void:
	var robot: Robot = _robot()
	var zone: FarmZone = _zone()
	robot.inventory.add(&"scrap", 2)
	var one_frame_drain: float = (
		robot.battery.drain_per_second(LocomotionSystem.Gait.IDLE) / Engine.physics_ticks_per_second
	)
	robot.battery.consume(robot.battery.get_current() - one_frame_drain / 2.0)
	assert_false(robot.battery.is_depleted(), "still alive before the next tick")
	await wait_physics_frames(3)
	assert_true(robot.battery.is_depleted(), "its own tick depleted the battery")
	assert_true(_transfer().is_playing(), "the transfer plays")
	assert_eq(_world().process_mode, Node.PROCESS_MODE_DISABLED, "the world is frozen")
	assert_eq(_spawner().get_items().size(), 1, "its inventory is on the ground")
	var expected: FarmZone = _reference_zone_of_visit(1)
	assert_eq(_describe_enemies(zone), _describe_enemies(expected), "the enemies of visit 1")
	for box: LootBox in zone.get_boxes():
		assert_false(box.is_opened(), "every box is closed")


## Ends the transfer and waits for the travel to the base it starts (R-009-51).
func _finish_transfer() -> void:
	var screen: TransferScreen = _transfer()
	screen.advance(screen.config.transfer_duration_s)
	await _await_travel()


func test_r_008_33_no_game_over_and_no_reload() -> void:
	assert_null(_main.get_node_or_null("UI/GameOverScreen"), "there is no game over screen")
	await _die()
	assert_true(_robot().battery.is_depleted(), "the robot is dead")
	assert_true(is_instance_valid(_main), "Main was not freed")
	assert_true(_main.is_inside_tree(), "nor taken out of the tree")
	assert_null(_main.get_node_or_null("UI/GameOverScreen"), "still no game over screen")
	assert_true(_transfer().is_playing(), "the transfer screen is what plays")
	assert_true(_transfer().visible, "and it is visible")


func test_r_008_30_robot_frozen_during_transfer() -> void:
	await _go_to_first_box()
	var robot: Robot = _robot()
	await _die()
	assert_true(_transfer().is_playing(), "the transfer is playing")
	assert_eq(_world().process_mode, Node.PROCESS_MODE_DISABLED, "the world stops processing")
	watch_signals(robot.melee)
	watch_signals(robot)
	var frozen_position: Vector3 = robot.global_position
	var battery_before: float = robot.battery.get_current()
	Input.action_press(&"move_forward")
	_hud().attack_held_changed.emit(true)
	await wait_physics_frames(10)
	Input.action_release(&"move_forward")
	_hud().attack_held_changed.emit(false)
	assert_eq(robot.global_position, frozen_position, "the robot does not move")
	assert_signal_not_emitted(robot.melee, "swing_started", "nor swing")
	robot.request_interact()
	# The box it stood next to was replaced by the repopulation.
	for box: LootBox in _zone().get_boxes():
		assert_false(box.is_opened(), "nor interact")
	assert_false(_ui_manager().is_modal_open(), "no screen opens")
	robot.receive_hit(5.0, robot)
	assert_signal_not_emitted(robot, "hit_received", "nor take hits")
	assert_eq(robot.battery.get_current(), battery_before, "the battery does not change")


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


## Replaces test_r_004_05_green_zone_loaded: the green zone is no longer in
## ZoneSlot from the start (R-009-08 replaces R-004-05).
func test_r_009_08_green_zone_loaded_after_travel() -> void:
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
		"its boxes were generated"
	)


func test_r_004_05_zone_generated_from_world_seed() -> void:
	var zone: FarmZone = _zone()
	var reference: FarmZone = (
		load("res://scenes/farm_zone/farm_zone_green.tscn") as PackedScene
	).instantiate() as FarmZone
	add_child_autofree(reference)
	reference.generate(GameManager.get_world_seed(), ZonePopulation.FIRST_VISIT)
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


func test_r_004_16_no_interaction_during_transfer() -> void:
	var button: Button = _main.get_node("UI/Hud").get_node("%InteractButton") as Button
	await _go_to_first_box()
	await _die()
	assert_true(_transfer().is_playing(), "the transfer is playing")
	button.pressed.emit()
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	for box: LootBox in _zone().get_boxes():
		assert_false(box.is_opened(), "a dead robot opens no box")
	assert_false(_ui_manager().is_modal_open(), "and no screen opens")


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


func test_r_005_29_death_closes_and_blocks_screens_during_transfer() -> void:
	_storage_button().pressed.emit()
	assert_true(_ui_manager().is_modal_open(), "the inventory screen is open")
	var robot: Robot = _robot()
	robot.battery.consume(robot.battery.get_current())
	assert_true(robot.battery.is_depleted(), "the battery is depleted")
	assert_false(_ui_manager().is_modal_open(), "death closes every screen")
	await wait_process_frames(2)
	assert_true(_transfer().is_playing(), "the transfer is playing")
	_storage_button().pressed.emit()
	assert_false(_ui_manager().is_modal_open(), "and the storage button opens none")
	_send_open_storage(true)
	await wait_process_frames(2)
	assert_false(_ui_manager().is_modal_open(), "nor does the open_storage action")


func _zombie_pool() -> ObjectPool:
	return _main.get_node("World/ZombiePool") as ObjectPool


func _describe_enemies(zone: FarmZone) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for zombie: Zombie in zone.get_enemies():
		lines.append("%s @ %s" % [zombie.get_data().id, zombie.global_position])
	return lines


func test_r_006_26_main_passes_first_visit() -> void:
	var zone: FarmZone = _zone()
	var pool: ObjectPool = _zombie_pool()
	assert_not_null(pool, "the zombie pool lives under World, outside the zone")
	if pool == null:
		return
	var zombies: Array[Zombie] = zone.get_enemies()
	assert_between(
		zombies.size(), zone.data.enemy_count_min, zone.data.enemy_count_max, "zombies at start"
	)
	assert_eq(
		pool.get_free_count(),
		zone.data.enemy_count_max - zombies.size(),
		"the pool was prewarmed with the maximum of the zone"
	)
	var expected: FarmZone = MAIN_ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(expected)
	var expected_pool: ObjectPool = ObjectPool.new()
	expected_pool.scene = pool.scene
	add_child_autofree(expected_pool)
	expected.spawn_enemies(GameManager.get_world_seed(), ZonePopulation.FIRST_VISIT, expected_pool)
	assert_eq(_describe_enemies(zone), _describe_enemies(expected), "world seed and visit 0")


func test_r_006_23_no_zombie_sees_the_robot_at_start() -> void:
	var zone: FarmZone = _zone()
	await wait_physics_frames(10)
	# Zombies must enter the scene on their markers: one that enters on top of
	# the robot and jumps away drags it along.
	assert_eq(_robot().global_position, zone.get_spawn_position(), "the robot stays on its spawn")
	for zombie: Zombie in zone.get_enemies():
		assert_eq(zombie.get_state(), EnemyBrain.State.IDLE, "zombie at %s is idle at start" % zombie.global_position)


func test_r_006_19_zombies_act_with_screen_open() -> void:
	var zone: FarmZone = _zone()
	var robot: Robot = _robot()
	var zombie: Zombie = zone.get_enemies()[0]
	# The navigation map needs a few physics frames before it gives paths.
	await wait_physics_frames(10)
	_storage_button().pressed.emit()
	assert_true(_ui_manager().is_modal_open(), "the inventory screen is open")
	var start: Vector3 = zombie.global_position
	var vision: float = zombie.get_data().ai.vision_radius
	# Towards the centre of the zone, inside the zombie's vision.
	robot.global_position = start - start.normalized() * (vision * 0.75)
	var battery_before: float = robot.battery.get_current()
	await wait_physics_frames(60)
	assert_true(_ui_manager().is_modal_open(), "the screen is still open")
	assert_false(get_tree().paused, "the game is not paused")
	assert_ne(zombie.get_state(), EnemyBrain.State.IDLE, "the zombie saw the robot")
	assert_gt(zombie.global_position.distance_to(start), 0.5, "and walked towards it")
	assert_lt(
		zombie.global_position.distance_to(robot.global_position),
		start.distance_to(robot.global_position),
		"getting closer"
	)
	assert_lt(robot.battery.get_current(), battery_before, "the battery keeps draining")


func test_r_007_28_main_wires_combat() -> void:
	var robot: Robot = _robot()
	var hud: Hud = _hud()
	var feedback: CombatFeedback = _main.get_node("CombatFeedback") as CombatFeedback
	var impact_pool: ObjectPool = _main.get_node("World/ImpactPool") as ObjectPool
	var debug_hud: DebugHud = _main.get_node("UI/DebugHud") as DebugHud
	assert_not_null(feedback, "CombatFeedback exists under Main")
	assert_not_null(impact_pool, "the impact pool lives under World")
	assert_not_null(debug_hud, "DebugHud exists under UI")
	if feedback == null or impact_pool == null or debug_hud == null:
		return
	var zone: FarmZone = _zone()
	assert_eq(impact_pool.get_free_count(), zone.data.enemy_count_max, "prewarmed for every enemy")
	assert_same(feedback.impact_pool, impact_pool, "the feedback uses that pool")
	assert_same(feedback.effects_root, _main.get_node("World"), "and plays its sparks under World")
	# The HUD attack button reaches the robot's input.
	hud.attack_held_changed.emit(true)
	assert_true(robot.player_input.poll_attack(), "the attack button reaches PlayerInput")
	hud.attack_held_changed.emit(false)
	# Feedback bound to the local robot.
	robot.hit_received.emit(1.0, robot)
	assert_true(_rig().is_shaking(), "a hit on the robot shakes the camera")
	assert_true((hud.get_node("%DamageFlash") as DamageFlash).visible, "and flashes the screen edges")
	# Debug XP bound to the local robot.
	robot.experience.add_xp(3)
	assert_eq((debug_hud.get_node("%XpLabel") as Label).text, "XP: 3", "the debug HUD shows its XP")


func test_r_007_28_robot_kills_a_zone_zombie() -> void:
	var robot: Robot = _robot()
	var zone: FarmZone = _zone()
	var zombie: Zombie = zone.get_enemies()[0]
	var enemy: EnemyData = zombie.get_data()
	var enemies_before: int = zone.get_enemies().size()
	# In front of the zombie, facing it, inside the reach of the swing.
	robot.global_position = zombie.global_position + Vector3(0.0, 0.0, enemy.ai.attack_range * 0.9)
	await wait_physics_frames(4)
	var hits_to_kill: int = ceili(float(enemy.hp_max) / float(robot.melee.attack.damage))
	var seconds: float = CombatSystem.swing_interval(robot.melee.attack) * hits_to_kill
	_hud().attack_held_changed.emit(true)
	await wait_physics_frames(ceili(seconds * Engine.physics_ticks_per_second))
	_hud().attack_held_changed.emit(false)
	assert_eq(robot.experience.get_total(), enemy.xp_reward, "the kill gave its XP")
	await wait_physics_frames(2)
	assert_eq(zone.get_enemies().size(), enemies_before - 1, "and the zombie left the zone")
	assert_false(robot.battery.is_depleted(), "the robot survived the fight")


# --- Spec 008 -----------------------------------------------------------------


## "item id → quantity" of every dropped item of the zone, summed.
func _held_on_ground() -> Dictionary[StringName, int]:
	var held: Dictionary[StringName, int] = {}
	for dropped: DroppedItem in _spawner().get_items():
		var contents: Dictionary[StringName, int] = _held(dropped.get_contents())
		for id: StringName in contents:
			held[id] = held.get(id, 0) + contents[id]
	return held


func _slot_of(inventory: InventoryComponent, item_id: StringName) -> int:
	var slots: Array[ItemStack] = inventory.get_slots()
	for index: int in slots.size():
		if slots[index] != null and slots[index].item.id == item_id:
			return index
	return -1


func _stack(item_id: StringName, quantity: int) -> Array[ItemStack]:
	var stacks: Array[ItemStack] = [ItemStack.new(DataRegistry.get_item(item_id), quantity)]
	return stacks


## Puts a fake clock on the spawner, set at the real time (Main repopulation
## reads the real one).
func _use_fake_clock() -> FakeTimeService:
	var fake: FakeTimeService = FakeTimeService.new()
	fake.now = FAKE_NOW
	_spawner().time_service = fake
	return fake


func _reference_zone_of_visit(visit: int) -> FarmZone:
	var expected: FarmZone = MAIN_ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(expected)
	var expected_pool: ObjectPool = ObjectPool.new()
	expected_pool.scene = _zombie_pool().scene
	add_child_autofree(expected_pool)
	expected.spawn_enemies(GameManager.get_world_seed(), visit, expected_pool)
	return expected


func test_r_008_06_generating_does_not_count_a_visit() -> void:
	var zone: FarmZone = _zone()
	assert_eq(GameManager.get_visit_count(zone.data.zone_id), 0, "Main generated the zone: no visit")
	var reference: FarmZone = MAIN_ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(reference)
	reference.generate(GameManager.get_world_seed(), ZonePopulation.FIRST_VISIT)
	assert_eq(GameManager.get_visit_count(zone.data.zone_id), 0, "generating another one neither")


func test_r_008_09_visit_change_repopulates_loaded_zone() -> void:
	var zone: FarmZone = _zone()
	await _go_to_first_box()
	_robot().request_interact()
	_ui_manager().close_all()
	assert_true(zone.get_boxes()[0].is_opened(), "test setup: a box was opened")
	GameManager.increment_visit_count(zone.data.zone_id)
	await wait_process_frames(2)
	var expected: FarmZone = _reference_zone_of_visit(1)
	assert_eq(_describe_enemies(zone), _describe_enemies(expected), "the enemies of visit 1")
	assert_gt(zone.get_boxes().size(), 0, "the zone still has its boxes")
	for box: LootBox in zone.get_boxes():
		assert_false(box.is_opened(), "every box is closed again")


func test_r_008_09_other_zone_visit_does_nothing() -> void:
	var zone: FarmZone = _zone()
	var boxes: Array[LootBox] = zone.get_boxes().duplicate()
	var enemies: Array[Zombie] = zone.get_enemies().duplicate()
	GameManager.increment_visit_count(OTHER_ZONE_ID)
	await wait_process_frames(2)
	assert_eq(zone.get_boxes(), boxes, "the same boxes")
	assert_eq(zone.get_enemies(), enemies, "the same enemies")


func test_r_008_15_full_inventory_shows_notice() -> void:
	_fill_robot_inventory()
	var robot: Robot = _robot()
	var fake: FakeTimeService = _use_fake_clock()
	var dropped: DroppedItem = _spawner().drop_stacks(_stack(&"scrap", 3), robot.global_position)
	assert_not_null(dropped, "test setup: the item fell")
	if dropped == null:
		return
	var dropped_at: int = dropped.dropped_at_unix
	fake.now += 10
	await wait_physics_frames(4)
	robot.request_interact()
	var message: Label = _hud().get_node("%MessageLabel") as Label
	assert_true(message.visible, "the HUD says the inventory is full")
	assert_eq(message.text, String(InventoryComponent.MSG_INVENTORY_FULL), "with its key")
	await wait_process_frames(2)
	var expected: Dictionary[StringName, int] = {&"scrap": 3}
	assert_eq(_held_on_ground(), expected, "what did not fit stays on the ground")
	assert_eq(_spawner().get_items().size(), 1, "in the same dropped item")
	assert_eq(dropped.dropped_at_unix, dropped_at, "with its original drop time")


func test_r_008_16_dropped_items_survive_repopulation() -> void:
	var zone: FarmZone = _zone()
	var dropped: DroppedItem = _spawner().drop_stacks(
		_stack(&"scrap", 4), zone.get_spawn_position() + Vector3(2.0, 0.0, 0.0)
	)
	GameManager.increment_visit_count(zone.data.zone_id)
	await wait_process_frames(2)
	GameManager.increment_visit_count(zone.data.zone_id)
	await wait_process_frames(2)
	var items: Array[DroppedItem] = [dropped]
	assert_eq(_spawner().get_items(), items, "the dropped item is still there")
	var expected: Dictionary[StringName, int] = {&"scrap": 4}
	assert_eq(_held_on_ground(), expected, "with its stacks")


func test_r_008_23_repopulation_discards_expired() -> void:
	var zone: FarmZone = _zone()
	var fake: FakeTimeService = _use_fake_clock()
	var lifetime: int = _spawner().config.lifetime_s
	var at: Vector3 = zone.get_spawn_position() + Vector3(2.0, 0.0, 0.0)
	_spawner().drop_stacks(_stack(&"scrap", 1), at)
	fake.now += lifetime
	var fresh: DroppedItem = _spawner().drop_stacks(_stack(&"iron", 1), at)
	GameManager.increment_visit_count(zone.data.zone_id)
	await wait_process_frames(2)
	var items: Array[DroppedItem] = [fresh]
	assert_eq(_spawner().get_items(), items, "only the expired one is gone")


func test_r_008_24_expires_with_screen_open_and_after_new_visit() -> void:
	var zone: FarmZone = _zone()
	var fake: FakeTimeService = _use_fake_clock()
	var lifetime: int = _spawner().config.lifetime_s
	var at: Vector3 = zone.get_spawn_position() + Vector3(2.0, 0.0, 0.0)
	var with_screen: DroppedItem = _spawner().drop_stacks(_stack(&"scrap", 1), at)
	_storage_button().pressed.emit()
	assert_true(_ui_manager().is_modal_open(), "the inventory screen is open")
	_spawner().discard_expired(fake.now + lifetime - 1)
	var first: Array[DroppedItem] = [with_screen]
	assert_eq(_spawner().get_items(), first, "before its lifetime it stays")
	_spawner().discard_expired(fake.now + lifetime)
	assert_eq(_spawner().get_items().size(), 0, "with the screen open it still expires")
	_ui_manager().close_all()
	var after_visit: DroppedItem = _spawner().drop_stacks(_stack(&"scrap", 1), at)
	GameManager.increment_visit_count(zone.data.zone_id)
	await wait_process_frames(2)
	_spawner().discard_expired(fake.now + lifetime - 1)
	var second: Array[DroppedItem] = [after_visit]
	assert_eq(_spawner().get_items(), second, "a new visit does not age it")
	_spawner().discard_expired(fake.now + lifetime)
	assert_eq(_spawner().get_items().size(), 0, "nor keep it past its lifetime")


func test_r_008_29_death_closes_screens_and_shows_transfer() -> void:
	_storage_button().pressed.emit()
	assert_true(_ui_manager().is_modal_open(), "the inventory screen is open")
	await _die()
	assert_false(_ui_manager().is_modal_open(), "no modal is open")
	assert_true(_transfer().is_playing(), "the transfer plays")
	assert_true(_transfer().visible, "and is visible")
	assert_true(_robot().player_input.is_input_blocked(), "the robot input is blocked")


## The respawn point of spec 008 is the base's spawn point now (R-009-51).
func test_r_008_31_robot_back_at_spawn_with_input() -> void:
	var robot: Robot = _robot()
	await _go_to_first_box()
	await _die()
	watch_signals(EventBus)
	await _finish_transfer()
	assert_false(_transfer().is_playing(), "the transfer ended")
	var base: BaseZone = _loader().get_current_zone() as BaseZone
	assert_not_null(base, "the robot is in the base")
	if base == null:
		return
	assert_lt(robot.global_position.distance_to(base.get_spawn_position()), 0.01, "at the spawn point")
	var expected_battery: float = (
		robot.battery.get_maximum() * GameManager.get_ruleset().respawn_battery_ratio
	)
	assert_almost_eq(
		robot.battery.get_current(), expected_battery, RESPAWN_BATTERY_TOLERANCE, "with the ruleset battery"
	)
	assert_false(robot.player_input.is_input_blocked(), "input unblocked")
	assert_eq(_world().process_mode, Node.PROCESS_MODE_INHERIT, "the world processes again")
	assert_signal_emit_count(EventBus, "player_respawned", 1, "respawned once")
	assert_signal_emitted_with_parameters(EventBus, "player_respawned", [robot.player_uid])


func test_r_008_35_loot_becomes_dropped_item_where_it_died() -> void:
	var zone: FarmZone = _zone()
	var at: Vector3 = zone.get_spawn_position() + Vector3(3.0, 0.0, 1.0)
	zone.enemy_loot_dropped.emit(_stack(&"scrap", 2), at)
	var items: Array[DroppedItem] = _spawner().get_items()
	assert_eq(items.size(), 1, "one dropped item appeared")
	if items.size() != 1:
		return
	assert_lt(items[0].global_position.distance_to(at), 0.01, "where the enemy died")
	var expected: Dictionary[StringName, int] = {&"scrap": 2}
	assert_eq(_held(items[0].get_contents()), expected, "holding the loot")


func test_r_008_39_throw_whole_stack() -> void:
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 5)
	var slot: int = _slot_of(robot.inventory, &"scrap")
	robot.request_throw(slot, 5)
	assert_null(robot.inventory.get_slots()[slot], "the slot is empty")
	var items: Array[DroppedItem] = _spawner().get_items()
	assert_eq(items.size(), 1, "a dropped item appeared")
	if items.size() != 1:
		return
	assert_lt(items[0].global_position.distance_to(robot.global_position), 0.01, "at the robot")
	var thrown: Dictionary[StringName, int] = {&"scrap": 5}
	assert_eq(_held(items[0].get_contents()), thrown, "holding what was thrown")
	await wait_physics_frames(4)
	robot.request_interact()
	assert_eq(_held(robot.inventory), thrown, "picking it up restores the total")
	await wait_process_frames(2)
	assert_eq(_spawner().get_items().size(), 0, "and the dropped item is gone")


func test_r_008_39_throw_part_keeps_rest() -> void:
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 5)
	var slot: int = _slot_of(robot.inventory, &"scrap")
	robot.request_throw(slot, 2)
	var stack: ItemStack = robot.inventory.get_slots()[slot]
	assert_not_null(stack, "the rest stays in the slot")
	if stack != null:
		assert_eq(stack.quantity, 3, "exactly 3 stay")
	var items: Array[DroppedItem] = _spawner().get_items()
	assert_eq(items.size(), 1, "a dropped item appeared")
	if items.size() != 1:
		return
	assert_lt(items[0].global_position.distance_to(robot.global_position), 0.01, "at the robot")
	var thrown: Dictionary[StringName, int] = {&"scrap": 2}
	assert_eq(_held(items[0].get_contents()), thrown, "holding the thrown 2")
	await wait_physics_frames(4)
	robot.request_interact()
	var total: Dictionary[StringName, int] = {&"scrap": 5}
	assert_eq(_held(robot.inventory), total, "picking it up restores the total")


func test_r_008_39_invalid_throw_creates_nothing() -> void:
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 5)
	var slot: int = _slot_of(robot.inventory, &"scrap")
	robot.request_throw(slot, 6)
	assert_push_error("could not throw")
	assert_eq(_spawner().get_items().size(), 0, "no dropped item")
	var total: Dictionary[StringName, int] = {&"scrap": 5}
	assert_eq(_held(robot.inventory), total, "and the inventory is untouched")


func test_r_008_44_die_respawn_and_recover() -> void:
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 3)
	robot.inventory.add(&"cables", 4)
	robot.inventory.add(&"iron", 2)
	robot.experience.add_xp(7)
	var carried: Dictionary[StringName, int] = _held(robot.inventory)
	var slot_count: int = robot.inventory.get_slot_count()
	await _go_to_first_box()
	var death_position: Vector3 = robot.global_position
	await _die()
	await _finish_transfer()
	var ruleset: RulesetData = GameManager.get_ruleset()
	assert_almost_eq(
		robot.battery.get_current(),
		robot.battery.get_maximum() * ruleset.respawn_battery_ratio,
		RESPAWN_BATTERY_TOLERANCE,
		"battery as the ruleset says"
	)
	assert_true(robot.inventory.is_empty(), "the inventory is empty")
	assert_eq(robot.inventory.get_slot_count(), slot_count, "with the same slots")
	assert_eq(robot.experience.get_total(), 7, "and the same XP")
	assert_true(_loader().get_current_zone() is BaseZone, "it came back in the base (R-009-51)")
	# Back to the zone where it died (spec 009): the visit after the death.
	await _travel_to_green_zone()
	var zone: FarmZone = _zone()
	var expected: FarmZone = _reference_zone_of_visit(1)
	assert_eq(_describe_enemies(zone), _describe_enemies(expected), "the enemies of visit 1")
	var items: Array[DroppedItem] = _spawner().get_items()
	assert_eq(items.size(), 1, "one dropped item")
	if items.size() != 1:
		return
	assert_lt(items[0].global_position.distance_to(death_position), 0.01, "where it died")
	assert_eq(_held(items[0].get_contents()), carried, "holding what it carried")
	robot.global_position = death_position
	await wait_physics_frames(4)
	robot.request_interact()
	assert_eq(_held(robot.inventory), carried, "the same stacks are back")
	await wait_process_frames(2)
	assert_eq(_spawner().get_items().size(), 0, "and the dropped item is gone")


# --- Spec 009: start in the base, travel, death with a base, building --------

const BASE_ZONE_PATH := "res://resources/zones/base.tres"
const RECIPE_PATH := "res://resources/recipes/charging_station.tres"
const PLACE_CELL := Vector2i(9, 2)


func _loading() -> LoadingScreen:
	return _main.get_node("UI/LoadingScreen") as LoadingScreen


func _structures() -> BaseStructures:
	return _main.get_node("World/BaseStructures") as BaseStructures


func _base() -> BaseZone:
	return _loader().get_current_zone() as BaseZone


func _travel_to_base() -> void:
	await _travel_to(DataRegistry.get_base_zone().zone_id)


## Interacts with the exit point of the loaded zone, as the player does.
func _use_exit() -> void:
	var exit: Node3D = _loader().get_current_zone().get_node("%ExitPoint") as Node3D
	_robot().global_position = exit.global_position + Vector3(0.0, 0.0, 1.0)
	await wait_physics_frames(4)
	_robot().request_interact()
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)


func _open_placement() -> PlacementScreen:
	var recipe: RecipeData = load(RECIPE_PATH) as RecipeData
	_robot().request_build(recipe)
	for child: Node in _ui_manager().get_children():
		var screen: PlacementScreen = child as PlacementScreen
		if screen != null and not screen.is_queued_for_deletion():
			return screen
	return null


func test_r_009_08_zone_slot_empty_in_scene() -> void:
	var state: SceneState = MAIN_SCENE.get_state()
	for index: int in state.get_node_count():
		var path: String = String(state.get_node_path(index))
		assert_false(path.begins_with("./World/ZoneSlot/"), "no zone placed in ZoneSlot: %s" % path)


func test_r_009_08_starts_in_base_spawn() -> void:
	# Spec 010: a new World in a new store, and one Main at a time (a save
	# collects every persistent node of the tree, and before_each's Main has
	# already saved its robot in the green zone).
	_main.queue_free()
	await wait_process_frames(1)
	SaveTestSupport.start_world()
	var fresh: Node = MAIN_SCENE.instantiate()
	add_child_autofree(fresh)
	var loader: ZoneLoader = fresh.get_node("%ZoneLoader") as ZoneLoader
	var robot: Robot = fresh.get_node("World/Players/Robot") as Robot
	# Read when the travel ends: this second Main shares the physics space with
	# the one of before_each, whose zombies may push its robot afterwards.
	var arrival: Array[Vector3] = []
	var record: Callable = func(_zone_id: Vector2i) -> void: arrival.append(robot.global_position)
	loader.travel_finished.connect(record)
	assert_true(loader.is_travelling(), "the game starts by travelling")
	await wait_for_signal(loader.travel_finished, TRAVEL_TIMEOUT_S)
	var base: BaseZone = loader.get_current_zone() as BaseZone
	assert_not_null(base, "to the base")
	if base == null or arrival.is_empty():
		return
	assert_lt(arrival[0].distance_to(base.get_spawn_position()), 0.01, "on its spawn point")
	assert_eq(base.get_structures_root().get_child_count(), 0, "a new world has no structures")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT, "no visit yet")


func test_r_009_07_loading_screen_while_travelling() -> void:
	assert_false(_loading().is_showing(), "hidden while playing")
	_loader().travel_to(DataRegistry.get_base_zone().zone_id)
	assert_true(_loading().is_showing(), "shown as soon as the travel starts")
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)
	assert_false(_loading().is_showing(), "hidden when it ends")


func test_r_009_07_world_frozen_and_input_blocked() -> void:
	var robot: Robot = _robot()
	var seen: Dictionary[String, bool] = {}
	var record: Callable = func(_zone: Zone) -> void:
		seen["frozen"] = _world().process_mode == Node.PROCESS_MODE_DISABLED
		seen["blocked"] = robot.player_input.is_input_blocked()
	_loader().zone_loaded.connect(record)
	_loader().travel_to(DataRegistry.get_base_zone().zone_id)
	assert_true(robot.player_input.is_input_blocked(), "input blocked at once")
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)
	_loader().zone_loaded.disconnect(record)
	var was_frozen: bool = seen.get("frozen", false)
	var was_blocked: bool = seen.get("blocked", false)
	assert_true(was_frozen, "the world was frozen while the zone loaded")
	assert_true(was_blocked, "and the input blocked")
	assert_eq(_world().process_mode, Node.PROCESS_MODE_INHERIT, "the world runs again")
	assert_false(robot.player_input.is_input_blocked(), "input back")


func test_r_009_11_exit_travels_without_battery_cost() -> void:
	await _use_exit()
	assert_not_null(_base(), "the green zone's exit leads to the base")
	var robot: Robot = _robot()
	var before: float = robot.battery.get_current()
	var exit: Node3D = _base().get_node("%ExitPoint") as Node3D
	robot.global_position = exit.global_position + Vector3(0.0, 0.0, 1.0)
	await wait_physics_frames(4)
	var at_exit: float = robot.battery.get_current()
	robot.request_interact()
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)
	assert_true(_loader().get_current_zone() is FarmZone, "back in the green zone")
	assert_almost_eq(robot.battery.get_current(), at_exit, 0.01, "the travel costs no battery")
	assert_lte(robot.battery.get_current(), before, "only the usual drain")


func test_r_009_11_two_round_trips_in_a_row() -> void:
	for trip: int in 2:
		await _use_exit()
		assert_true(_loader().get_current_zone() is BaseZone, "trip %d: in the base" % trip)
		await _use_exit()
		assert_true(_loader().get_current_zone() is FarmZone, "trip %d: in the green zone" % trip)
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), 2, "each exit from the farm counted once")


func test_r_009_51_death_in_zone_respawns_in_base() -> void:
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 2)
	await _go_to_first_box()
	await _die()
	await _finish_transfer()
	var base: BaseZone = _base()
	assert_not_null(base, "the robot came back in the base")
	if base == null:
		return
	assert_lt(robot.global_position.distance_to(base.get_spawn_position()), 0.01, "on its spawn point")
	assert_almost_eq(
		robot.battery.get_current(),
		robot.battery.get_maximum() * GameManager.get_ruleset().respawn_battery_ratio,
		RESPAWN_BATTERY_TOLERANCE,
		"with the battery of BALANCE §1.1"
	)
	assert_false(robot.player_input.is_input_blocked(), "and its input")
	assert_eq(_world().process_mode, Node.PROCESS_MODE_INHERIT, "the world runs")


func test_r_009_52_death_in_base() -> void:
	await _travel_to_base()
	var robot: Robot = _robot()
	robot.inventory.add(&"iron", 3)
	robot.global_position = _base().get_spawn_position() + Vector3(2.0, 0.0, -3.0)
	await wait_physics_frames(2)
	var death_position: Vector3 = robot.global_position
	await _die()
	assert_eq(GameManager.get_visit_count(DataRegistry.get_base_zone().zone_id), 0, "no visit counted")
	await _finish_transfer()
	var base: BaseZone = _base()
	assert_not_null(base, "back in the base")
	if base == null:
		return
	assert_lt(robot.global_position.distance_to(base.get_spawn_position()), 0.01, "on its spawn point")
	var items: Array[DroppedItem] = _spawner().get_items()
	assert_eq(items.size(), 1, "the dropped item stays in the base after reloading it")
	if items.size() == 1:
		assert_lt(items[0].global_position.distance_to(death_position), 0.01, "where it died")


func test_r_009_53_death_while_placing_cancels() -> void:
	await _travel_to_base()
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 4)
	var screen: PlacementScreen = _open_placement()
	assert_not_null(screen, "placement is open")
	if screen == null:
		return
	screen.select_cell(PLACE_CELL)
	var scrap_before: int = robot.inventory.count(&"scrap")
	await _die()
	assert_false(_ui_manager().is_modal_open(), "the death closed placement")
	assert_eq(_structures().to_data().size(), 0, "nothing placed")
	assert_eq(_spawner().get_items().size(), 1, "what it carried fell, uncharged")
	if _spawner().get_items().size() == 1:
		var dropped: Dictionary[StringName, int] = _held(_spawner().get_items()[0].get_contents())
		var dropped_scrap: int = dropped.get(&"scrap", 0)
		assert_eq(dropped_scrap, scrap_before, "all the scrap is there")


func test_r_009_53_death_while_moving_keeps_cells() -> void:
	await _travel_to_base()
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 4)
	var recipe: RecipeData = load(RECIPE_PATH) as RecipeData
	assert_true(_structures().place(robot, recipe, PLACE_CELL).ok, "test setup: a station")
	var before: Array[Dictionary] = _structures().to_data()
	_hud().get_node("%EditBaseButton").emit_signal(&"pressed")
	var screen: PlacementScreen = null
	for child: Node in _ui_manager().get_children():
		if child is PlacementScreen:
			screen = child as PlacementScreen
	assert_not_null(screen, "edit mode is open")
	if screen == null:
		return
	screen.select_cell(PLACE_CELL)
	screen.select_cell(Vector2i(1, 1))
	await _die()
	assert_false(_ui_manager().is_modal_open(), "the death closed edit mode")
	assert_eq(_structures().to_data(), before, "the station stayed on its cell")


func test_r_009_57_robot_still_and_draining_while_placing() -> void:
	await _travel_to_base()
	var robot: Robot = _robot()
	robot.inventory.add(&"scrap", 4)
	assert_not_null(_open_placement(), "placement is open")
	var position: Vector3 = robot.global_position
	var battery: float = robot.battery.get_current()
	Input.action_press(&"move_forward")
	await wait_physics_frames(20)
	Input.action_release(&"move_forward")
	assert_eq(robot.global_position, position, "the robot does not move")
	assert_lt(robot.battery.get_current(), battery, "the battery keeps draining")


func test_r_009_59_edit_button_toggles() -> void:
	var button: Button = _hud().get_node("%EditBaseButton") as Button
	assert_false(button.visible, "hidden in the green zone")
	await _travel_to_base()
	assert_true(button.visible, "shown in the base")
	button.pressed.emit()
	assert_true(_ui_manager().is_open(PlacementScreen.SCREEN_ID), "edit mode opens")
	assert_true(_robot().player_input.is_input_blocked(), "the robot waits")
	button.pressed.emit()
	assert_false(_ui_manager().is_modal_open(), "and closes")
	assert_false(_robot().player_input.is_input_blocked(), "the robot moves again")


func test_r_009_64_bench_opens_build_screen() -> void:
	await _travel_to_base()
	var bench: Node3D = _base().get_node("%RepairBench") as Node3D
	_robot().global_position = bench.global_position + Vector3(0.0, 0.0, 1.5)
	await wait_physics_frames(4)
	_robot().request_interact()
	assert_true(_ui_manager().is_open(BenchScreen.SCREEN_ID), "the bench opens the bench screen")


func test_r_009_06_respawn_travel_failure_respawns_in_place() -> void:
	var robot: Robot = _robot()
	var catalog: DataCatalog = DataRegistry.get_catalog()
	var base: ZoneData = DataRegistry.get_base_zone()
	var real_path: String = base.scene_path
	await _die()
	base.scene_path = "res://scenes/main_test_missing_base.tscn"
	_transfer().advance(_transfer().config.transfer_duration_s)
	await wait_for_signal(_loader().travel_failed, TRAVEL_TIMEOUT_S)
	base.scene_path = real_path
	assert_push_error("failed")
	assert_engine_error("Cannot open file")
	assert_engine_error("Failed loading resource")
	assert_true(_loader().get_current_zone() is FarmZone, "the zone stays loaded")
	assert_false(robot.battery.is_depleted(), "the robot came back anyway")
	assert_lt(
		robot.global_position.distance_to(_zone().get_spawn_position()), 0.01, "on the zone's spawn point"
	)
	assert_false(robot.player_input.is_input_blocked(), "with its input")
	assert_not_null(catalog, "the catalog is still there")


## Uses the exit and dies in the same step, as when the robot's own physics
## step interacts and then drains the last battery (architecture review 009).
func _exit_and_die() -> void:
	var robot: Robot = _robot()
	var exit: Node3D = _zone().get_node("%ExitPoint") as Node3D
	robot.global_position = exit.global_position + Vector3(0.0, 0.0, 1.0)
	await wait_physics_frames(4)
	robot.request_interact()
	robot.battery.consume(robot.battery.get_current())


func test_r_009_51_death_in_exit_step_waits_for_base() -> void:
	var robot: Robot = _robot()
	await _exit_and_die()
	assert_true(_loader().is_travelling(), "the exit started a travel")
	assert_true(_transfer().is_playing(), "and the death its transfer")
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)
	await wait_process_frames(2)
	assert_eq(_world().process_mode, Node.PROCESS_MODE_DISABLED, "a dead robot keeps the world frozen")
	assert_true(robot.player_input.is_input_blocked(), "and its input blocked")
	await _finish_transfer()
	var base: BaseZone = _base()
	assert_not_null(base, "it comes back in the base")
	if base == null:
		return
	assert_lt(robot.global_position.distance_to(base.get_spawn_position()), 0.01, "on its spawn point")
	assert_false(robot.battery.is_depleted(), "alive")
	assert_eq(_world().process_mode, Node.PROCESS_MODE_INHERIT, "the world runs again")
	assert_false(robot.player_input.is_input_blocked(), "with its input")


func test_r_009_51_transfer_ends_during_exit_travel() -> void:
	var robot: Robot = _robot()
	await _exit_and_die()
	_transfer().advance(_transfer().config.transfer_duration_s)
	assert_true(_loader().is_travelling(), "the exit travel is still loading")
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)
	await _await_travel()
	var base: BaseZone = _base()
	assert_not_null(base, "the robot waited for the base")
	if base == null:
		return
	assert_lt(robot.global_position.distance_to(base.get_spawn_position()), 0.01, "on its spawn point")
	assert_false(robot.battery.is_depleted(), "alive")
	assert_eq(_world().process_mode, Node.PROCESS_MODE_INHERIT, "the world runs again")
	assert_false(robot.player_input.is_input_blocked(), "with its input")
