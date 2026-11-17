extends GutTest
## Robot + InteractorComponent + LootBox with real physics (spec 004): the
## interact action opens the box in range (R-004-14) and a robot with a
## depleted battery does not interact (R-004-16). A box stops being offered
## once it is emptied, not when it is opened (R-005-21). Input goes through the
## InputMap action, the same path the game uses. The HUD button path is tested
## in test_main_scene.gd, where Main wires it.

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const LOOT_BOX_SCENE := preload("res://scenes/entities/loot_box.tscn")
## Area overlaps are reported one or two physics frames after a move.
const SETTLE_FRAMES := 4
const LOOT_SEED := 77
## In range of the robot at the origin, without touching it.
const BOX_POSITION := Vector3(1.6, 0.0, 0.0)

var _robot: Robot
var _box: LootBox


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_box = LOOT_BOX_SCENE.instantiate() as LootBox
	add_child_autofree(_box)
	_box.global_position = BOX_POSITION
	_box.setup(LOOT_SEED)
	watch_signals(_box)
	await wait_physics_frames(SETTLE_FRAMES)


func after_each() -> void:
	Input.action_release(&"interact")


func _tap_interact() -> void:
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	await wait_physics_frames(2)


func test_r_004_12_robot_targets_box_in_range() -> void:
	var target: InteractableComponent = _robot.interactor.get_target()
	assert_not_null(target, "the robot has a target next to a box")
	assert_same(target, _box.get_node("%Interactable"), "the target is the box")


func test_r_004_14_interact_action_opens_box() -> void:
	await _tap_interact()
	assert_true(_box.is_opened(), "the interact action opens the box in range")
	assert_signal_emit_count(_box, "loot_generated", 1)
	var parameters: Array = get_signal_parameters(_box, "loot_generated")
	var opener: Node3D = parameters[1]
	assert_same(opener, _robot, "the robot is passed as the opener")


func test_r_004_14_holding_interact_opens_once() -> void:
	Input.action_press(&"interact")
	await wait_physics_frames(20)
	assert_signal_emit_count(_box, "loot_generated", 1, "holding the key is one interaction")


func test_r_004_14_request_interact_opens_box() -> void:
	_robot.request_interact()
	assert_true(_box.is_opened(), "request_interact() is the path of the HUD button")


func test_r_004_14_nothing_in_range_does_nothing() -> void:
	_robot.global_position = Vector3(50.0, 0.0, 0.0)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_interact()
	assert_false(_box.is_opened(), "a box out of range stays closed")


func test_r_005_21_emptied_box_is_no_longer_offered() -> void:
	await _tap_interact()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_not_null(_robot.interactor.get_target(), "an opened box with loot is still a target")
	var contents: InventoryComponent = _box.get_contents()
	var every_slot: Array[int] = []
	every_slot.assign(range(contents.get_slot_count()))
	assert_true(_robot.inventory.take_from(contents, every_slot).ok, "the robot takes everything")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_null(_robot.interactor.get_target(), "the emptied box is not a target any more")


func test_r_004_16_depleted_robot_does_not_interact() -> void:
	_robot.battery.consume(_robot.battery.get_current())
	assert_true(_robot.battery.is_depleted(), "the battery is depleted")
	await _tap_interact()
	_robot.request_interact()
	assert_false(_box.is_opened(), "a depleted robot opens nothing")
	assert_signal_not_emitted(_box, "loot_generated")


func test_r_005_27_blocked_input_does_not_interact() -> void:
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_SCREEN)
	await _tap_interact()
	_robot.request_interact()
	assert_false(_box.is_opened(), "a robot with blocked input opens nothing")
	_robot.player_input.set_input_blocked(false, PlayerInput.REASON_SCREEN)
	_robot.request_interact()
	assert_true(_box.is_opened(), "unblocked, it interacts again")
