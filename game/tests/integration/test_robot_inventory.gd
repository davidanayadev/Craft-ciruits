extends GutTest
## Robot + InventoryComponent (spec 005): the robot owns exactly one inventory
## (R-005-10) and starts with the slots of chassis level 1, read from
## chassis_levels.tres (R-005-02).
## Spec 014: a level-up grows the inventory to the slots of the new level,
## keeping every stack in its slot (R-014-08); no threshold, no change
## (R-014-09); XP that goes down keeps the slots (R-014-11).

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const CHASSIS_LEVELS_PATH := "res://resources/progression/chassis_levels.tres"

var _robot: Robot


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)


func test_r_005_02_robot_starts_with_level_one_slots() -> void:
	assert_not_null(_robot.chassis_levels, "the robot has a chassis level table")
	if _robot.chassis_levels == null:
		return
	assert_eq(_robot.chassis_levels.resource_path, CHASSIS_LEVELS_PATH, "it is chassis_levels.tres")
	var level_one_slots: int = _robot.chassis_levels.get_inventory_slots(
		ChassisLevelData.FIRST_LEVEL
	)
	assert_gt(level_one_slots, 0, "level 1 has slots")
	assert_eq(_robot.inventory.get_slot_count(), level_one_slots, "slots of chassis level 1")
	assert_true(_robot.inventory.is_empty(), "the robot starts with nothing")


func test_r_005_10_robot_owns_one_inventory() -> void:
	assert_not_null(_robot.inventory, "the robot exposes its inventory")
	assert_same(InventoryComponent.find_in(_robot), _robot.inventory, "it is a child of the robot")
	var inventories: int = 0
	for child: Node in _robot.get_children():
		if child is InventoryComponent:
			inventories += 1
	assert_eq(inventories, 1, "exactly one InventoryComponent")


func test_r_005_10_inventory_uses_registry_catalog() -> void:
	assert_same(_robot.inventory.catalog, DataRegistry.get_catalog(), "ids come from DataRegistry")
	assert_true(_robot.inventory.add(&"scrap", 1).ok, "a catalog item can be added")


## Spec 008 (R-008-39): the robot only asks to throw; whoever owns the dropped
## items changes the inventory.
func test_r_008_39_request_throw_emits() -> void:
	_robot.set_physics_process(false)
	_robot.inventory.add(&"scrap", 7)
	watch_signals(_robot)
	_robot.request_throw(0, 3)
	assert_signal_emit_count(_robot, "throw_requested", 1, "one request")
	assert_signal_emitted_with_parameters(_robot, "throw_requested", [_robot, 0, 3])
	assert_eq(_robot.inventory.count(&"scrap"), 7, "the robot does not change its inventory by itself")
	_robot.battery.consume(_robot.battery.get_current())
	_robot.request_throw(0, 3)
	assert_signal_emit_count(_robot, "throw_requested", 1, "a depleted battery requests nothing")
	assert_eq(_robot.inventory.count(&"scrap"), 7, "and nothing changes")


# --- Spec 014: chassis level --------------------------------------------------

## First level whose slot count is above the previous level's, read from the table.
func _first_level_with_more_slots() -> int:
	var levels: ChassisLevelData = _robot.chassis_levels
	for level: int in range(ChassisLevelData.FIRST_LEVEL + 1, levels.get_level_count() + 1):
		if levels.get_inventory_slots(level) > levels.get_inventory_slots(level - 1):
			return level
	return ChassisLevelData.FIRST_LEVEL


func _raise_to(level: int) -> void:
	_robot.experience.add_xp(
		_robot.chassis_levels.get_xp_required(level) - _robot.experience.get_total()
	)


func _describe(slots: Array[ItemStack]) -> Array:
	var described: Array = []
	for stack: ItemStack in slots:
		if stack == null:
			described.append(null)
		else:
			described.append([stack.item.id, stack.quantity, stack.durability, stack.uid])
	return described


func test_r_014_08_slots_grow_keeping_stacks() -> void:
	var piece: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(&"basic_arms"))
	piece.durability = 40
	var offered: Array[ItemStack] = [piece]
	assert_true(_robot.inventory.add(&"scrap", 3).ok, "scrap in slot 0")
	assert_true(_robot.inventory.add_stacks(offered).ok, "a piece in slot 1")
	assert_true(_robot.inventory.add(&"iron", 2).ok, "iron in slot 2")
	var before: Array = _describe(_robot.inventory.get_slots())
	var level: int = _first_level_with_more_slots()
	assert_gt(level, ChassisLevelData.FIRST_LEVEL, "the table has a level that adds slots")
	_raise_to(level)
	assert_eq(_robot.experience.get_level(), level, "the robot reached that level")
	var expected: int = _robot.chassis_levels.get_inventory_slots(level)
	assert_eq(_robot.inventory.get_slot_count(), expected, "slots of level %d" % level)
	var after: Array = _describe(_robot.inventory.get_slots())
	assert_eq(after.slice(0, before.size()), before, "every stack stays in its slot, piece included")
	for index: int in range(before.size(), after.size()):
		assert_true(after[index] == null, "slot %d is new and empty" % index)


func test_r_014_08_same_slot_level_leaves_inventory() -> void:
	var level_two: int = ChassisLevelData.FIRST_LEVEL + 1
	var levels: ChassisLevelData = _robot.chassis_levels
	assert_eq(
		levels.get_inventory_slots(level_two),
		levels.get_inventory_slots(ChassisLevelData.FIRST_LEVEL),
		"BALANCE §6.1: levels 1 and 2 have the same slots"
	)
	watch_signals(_robot.inventory)
	_raise_to(level_two)
	assert_eq(_robot.experience.get_level(), level_two, "level 2")
	assert_signal_not_emitted(_robot.inventory, "inventory_changed", "the inventory does not change")
	assert_eq(_robot.inventory.get_slot_count(), levels.get_inventory_slots(level_two))


func test_r_014_09_below_threshold_same_slots() -> void:
	var level: int = _first_level_with_more_slots()
	var slots_before: int = _robot.inventory.get_slot_count()
	_robot.experience.add_xp(_robot.chassis_levels.get_xp_required(level) - 1)
	assert_eq(_robot.experience.get_level(), level - 1, "one XP short of the level")
	assert_eq(_robot.inventory.get_slot_count(), slots_before, "the slots stay")


func test_r_014_11_xp_down_keeps_slots() -> void:
	var level: int = _first_level_with_more_slots()
	_raise_to(level)
	var slots: int = _robot.inventory.get_slot_count()
	_robot.experience.reset()
	assert_push_error("goes down")
	assert_eq(_robot.experience.get_level(), level, "the level stays")
	assert_eq(_robot.inventory.get_slot_count(), slots, "and so do the slots")
