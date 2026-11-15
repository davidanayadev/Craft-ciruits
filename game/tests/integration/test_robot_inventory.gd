extends GutTest
## Robot + InventoryComponent (spec 005): the robot owns exactly one inventory
## (R-005-10) and starts with the slots of chassis level 1, read from
## chassis_levels.tres (R-005-02).

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
