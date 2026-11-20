extends GutTest
## Robot.use_consumable / request_use_consumable with the real robot scene and the
## real portable_battery of the catalog (spec 012). Covers R-012-23 (one unit
## leaves the chosen slot and its points go to the battery, capped at the
## maximum), R-012-24 (a full battery or no portable battery is refused with
## use_refused and nothing changes) and R-012-25 (the use_consumable action and
## the request path of the "Use" button). Points come from the .tres, never a
## literal.

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const BATTERY_ID := &"portable_battery"
const SCRAP_ID := &"scrap"
const DRAINED := 50.0
const TOLERANCE := 0.01
## A stack holds 5 batteries: 7 give slots [5, 2] after the scrap in slot 0.
const BATTERY_COUNT := 7

var _robot: Robot
var _points: float = 0.0


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	var item: ConsumableData = DataRegistry.get_item(BATTERY_ID) as ConsumableData
	assert_not_null(item, "the catalog has the portable battery as a ConsumableData")
	if item != null:
		_points = item.battery_points


func after_each() -> void:
	Input.action_release(&"use_consumable")


## Scrap in slot 0, batteries from slot 1.
func _fill_inventory() -> void:
	_robot.inventory.add(SCRAP_ID, 2)
	_robot.inventory.add(BATTERY_ID, BATTERY_COUNT)


func _quantity(slot: int) -> int:
	var stack: ItemStack = _robot.inventory.get_slots()[slot]
	return 0 if stack == null else stack.quantity


func _describe() -> Array[String]:
	var lines: Array[String] = []
	for stack: ItemStack in _robot.inventory.get_slots():
		lines.append("-" if stack == null else "%s x%d" % [stack.item.id, stack.quantity])
	return lines


func test_r_012_23_use_removes_one_and_adds_points() -> void:
	_fill_inventory()
	_robot.battery.consume(DRAINED)
	var before: float = _robot.battery.get_current()
	var other_slot: int = _quantity(1)
	watch_signals(_robot.inventory)
	watch_signals(_robot.battery)
	var result: ActionResult = _robot.use_consumable(2)
	assert_true(result.ok, "using a battery works")
	assert_eq(_quantity(2), 1, "one unit left THAT slot")
	assert_eq(_quantity(1), other_slot, "the other stack is untouched")
	assert_almost_eq(_robot.battery.get_current(), before + _points, TOLERANCE, "the battery gets its points")
	assert_signal_emit_count(_robot.inventory, "inventory_changed", 1, "one inventory change")
	assert_signal_emit_count(_robot.battery, "battery_changed", 1, "and one battery change")


func test_r_012_23_last_unit_empties_the_slot() -> void:
	_robot.inventory.add(BATTERY_ID, 1)
	_robot.battery.consume(DRAINED)
	assert_true(_robot.use_consumable(0).ok, "the last unit can be used")
	assert_null(_robot.inventory.get_slots()[0], "the slot is empty")


func test_r_012_23_capped_at_maximum() -> void:
	_fill_inventory()
	var missing: float = _points / 2.0
	_robot.battery.consume(missing)
	var result: ActionResult = _robot.use_consumable(1)
	assert_true(result.ok, "not full, so it is used")
	assert_almost_eq(
		_robot.battery.get_current(), _robot.battery.get_maximum(), TOLERANCE, "capped at the maximum"
	)
	assert_eq(_quantity(1), 4, "a whole unit is spent anyway")


func test_r_012_24_full_battery_refused() -> void:
	_fill_inventory()
	var before: Array[String] = _describe()
	watch_signals(_robot)
	watch_signals(_robot.inventory)
	watch_signals(_robot.battery)
	var result: ActionResult = _robot.use_consumable(1)
	assert_false(result.ok, "a full battery refuses")
	assert_eq(result.error_key, ConsumableRules.ERR_BATTERY_FULL)
	assert_signal_emitted_with_parameters(_robot, "use_refused", [ConsumableRules.ERR_BATTERY_FULL])
	assert_eq(_describe(), before, "no unit is spent")
	assert_signal_not_emitted(_robot.inventory, "inventory_changed")
	assert_signal_not_emitted(_robot.battery, "battery_changed")


func test_r_012_24_no_battery_refused() -> void:
	_robot.inventory.add(SCRAP_ID, 2)
	_robot.battery.consume(DRAINED)
	var before: Array[String] = _describe()
	var charge: float = _robot.battery.get_current()
	watch_signals(_robot)
	var on_material: ActionResult = _robot.use_consumable(0)
	assert_eq(on_material.error_key, ConsumableRules.ERR_NO_PORTABLE_BATTERY, "a material slot")
	var on_empty: ActionResult = _robot.use_consumable(1)
	assert_eq(on_empty.error_key, ConsumableRules.ERR_NO_PORTABLE_BATTERY, "an empty slot")
	assert_signal_emit_count(_robot, "use_refused", 2, "each refusal is announced")
	assert_signal_emitted_with_parameters(_robot, "use_refused", [ConsumableRules.ERR_NO_PORTABLE_BATTERY], 0)
	assert_eq(_describe(), before, "the inventory is unchanged")
	assert_eq(_robot.battery.get_current(), charge, "the battery is unchanged")


func test_r_012_24_depleted_robot_does_nothing() -> void:
	_fill_inventory()
	_robot.battery.consume(_robot.battery.get_maximum())
	assert_true(_robot.battery.is_depleted(), "the battery is at 0")
	var before: Array[String] = _describe()
	watch_signals(_robot)
	var result: ActionResult = _robot.use_consumable(1)
	assert_false(result.ok, "a depleted robot cannot use anything")
	assert_eq(result.error_key, ActionResult.ERR_INVALID_REQUEST)
	assert_eq(_describe(), before, "the inventory is unchanged")
	assert_eq(_robot.battery.get_current(), 0.0, "the battery is unchanged")
	assert_signal_not_emitted(_robot, "use_refused", "it is not a refusal to show")


func test_r_012_25_use_consumable_action() -> void:
	_fill_inventory()
	_robot.battery.consume(DRAINED)
	var before: float = _robot.battery.get_current()
	_robot.request_use_consumable()
	assert_eq(_quantity(1), 4, "NO_SLOT uses the first consumable slot")
	assert_eq(_quantity(2), 2, "and no other")
	assert_almost_eq(_robot.battery.get_current(), before + _points, TOLERANCE, "the battery rises")


func test_r_012_25_request_with_slot_uses_that_slot() -> void:
	_fill_inventory()
	_robot.battery.consume(DRAINED)
	_robot.request_use_consumable(2)
	assert_eq(_quantity(2), 1, "the given slot is used")
	assert_eq(_quantity(1), 5, "not the first one")


func test_r_012_25_request_without_battery_is_refused() -> void:
	_robot.inventory.add(SCRAP_ID, 2)
	watch_signals(_robot)
	_robot.request_use_consumable()
	assert_signal_emitted_with_parameters(_robot, "use_refused", [ConsumableRules.ERR_NO_PORTABLE_BATTERY])


func test_r_012_25_request_when_full_is_refused() -> void:
	_fill_inventory()
	watch_signals(_robot)
	_robot.request_use_consumable()
	assert_signal_emitted_with_parameters(_robot, "use_refused", [ConsumableRules.ERR_BATTERY_FULL])
	assert_eq(_quantity(1), 5, "nothing is spent")


func test_r_012_25_request_while_depleted_does_nothing() -> void:
	_fill_inventory()
	_robot.battery.consume(_robot.battery.get_maximum())
	var before: Array[String] = _describe()
	watch_signals(_robot)
	_robot.request_use_consumable()
	assert_eq(_describe(), before, "nothing changes")
	assert_signal_not_emitted(_robot, "use_refused")


func test_r_012_25_request_works_while_a_screen_blocks_input() -> void:
	# The "Use" button lives in a screen, which blocks the robot's input (R-005-27).
	_fill_inventory()
	_robot.battery.consume(DRAINED)
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_SCREEN)
	_robot.request_use_consumable(1)
	assert_eq(_quantity(1), 4, "the button path is not the blocked action path")


func test_r_012_25_action_polled_in_physics() -> void:
	_fill_inventory()
	_robot.battery.consume(DRAINED)
	_robot.set_physics_process(true)
	Input.action_press(&"use_consumable")
	await wait_physics_frames(2)
	Input.action_release(&"use_consumable")
	await wait_physics_frames(2)
	assert_eq(_quantity(1), 4, "the use_consumable action uses one battery")


func test_r_012_25_holding_the_action_uses_one() -> void:
	_fill_inventory()
	_robot.battery.consume(DRAINED)
	_robot.set_physics_process(true)
	Input.action_press(&"use_consumable")
	await wait_physics_frames(20)
	assert_eq(_quantity(1), 4, "holding the key is one use")


func test_r_012_25_action_ignored_while_blocked() -> void:
	_fill_inventory()
	_robot.battery.consume(DRAINED)
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_SCREEN)
	_robot.set_physics_process(true)
	Input.action_press(&"use_consumable")
	await wait_physics_frames(2)
	assert_false(_robot.player_input.is_use_consumable_just_pressed(), "false while blocked")
	Input.action_release(&"use_consumable")
	await wait_physics_frames(2)
	assert_eq(_quantity(1), 5, "a blocked robot uses nothing")
