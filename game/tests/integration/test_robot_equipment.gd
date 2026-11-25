extends GutTest
## The robot with real equipment (spec 015): its stats come from the equipped
## pieces only (R-015-05, R-015-13) and movement, attack and battery follow them
## (R-015-14 to R-015-19, R-015-44); a hit wears the first piece before taking
## battery (R-015-21, R-015-54), never on a depleted robot (R-015-22), and a
## broken piece takes its slot back to the no-piece stats (R-015-23).
## Values come from the real .tres files (BALANCE §1.1, §4.1, §4.2).

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const BASIC_ARMS_PATH := "res://resources/pieces/basic_arms.tres"
const BASIC_LEGS_PATH := "res://resources/pieces/basic_legs.tres"
const BASIC_CORE_PATH := "res://resources/pieces/basic_core.tres"
const BASE_STATS_PATH := "res://resources/robot/robot_base_stats.tres"
const ARMS := PieceData.SlotType.ARMS
const LEGS := PieceData.SlotType.LEGS
const CORE := PieceData.SlotType.CORE
const TOLERANCE := 0.0001
## Far from the origin, where the other tests put their robots.
const FAR := Vector3(80.0, 0.0, -80.0)
## A hit of a made-up size: the battery damage of a hit is not what is tested.
const HIT := 4.0
const ACTIONS: Array[StringName] = [&"move_forward", &"run"]

var _robot: Robot
var _base: RobotBaseStatsData


func before_each() -> void:
	_base = load(BASE_STATS_PATH) as RobotBaseStatsData
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.global_position = FAR


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _piece(path: String) -> PieceData:
	return load(path) as PieceData


## Puts a new piece in the inventory and returns its slot.
func _give(path: String) -> int:
	var stack: ItemStack = CraftingSystem.create_result(_piece(path))
	var added: InventoryAddResult = _robot.inventory.add_stacks([stack])
	assert_true(added.ok, "the piece entered the inventory")
	return InventoryRules.index_of_uid(_robot.inventory.get_slots(), stack.uid)


func _equip_new(path: String) -> void:
	var result: ActionResult = _robot.equip(_give(path))
	assert_true(result.ok, "equipped %s" % path)


func _stat(path: String, stat: StringName) -> float:
	for modifier: StatModifier in _piece(path).modifiers:
		if modifier.stat == stat:
			return modifier.value
	fail_test("%s does not set %s" % [path, stat])
	return 0.0


func test_r_015_41_robot_starts_with_core_and_legs() -> void:
	assert_eq(_robot.equipment.get_piece(CORE).item.id, &"basic_core", "basic Core equipped (BALANCE §4.2)")
	assert_eq(_robot.equipment.get_piece(LEGS).item.id, &"basic_legs", "basic legs equipped")
	assert_null(_robot.equipment.get_piece(ARMS), "one arm")
	assert_eq(_robot.battery.get_current(), _robot.battery.get_maximum(), "a new robot starts full")
	assert_true(_robot.inventory.is_empty(), "the starting equipment is not in the inventory")


func test_r_015_05_piece_in_inventory_changes_nothing() -> void:
	var damage: float = _robot.stats.get_stat(StatIds.ATTACK_DAMAGE)
	var _slot: int = _give(BASIC_ARMS_PATH)
	assert_eq(_robot.stats.get_stat(StatIds.ATTACK_DAMAGE), damage, "arms in the inventory do nothing")
	assert_eq(_robot.melee.attack.damage, roundi(_base.attack_damage), "still one arm")


func test_r_015_06_modifier_changes_wear() -> void:
	var modifier: StatModifier = StatModifier.new()
	modifier.stat = StatIds.DURABILITY_PER_HIT
	modifier.op = StatModifier.Op.SET
	modifier.value = 2.0
	var modifiers: Array[StatModifier] = _robot.equipment.get_modifiers()
	modifiers.append(modifier)
	_robot.stats.recompute(modifiers)
	_robot.receive_hit(HIT, null)
	assert_eq(_robot.equipment.get_piece(LEGS).durability, 98, "the wear is the stat a modifier set")


func test_r_015_12_depleted_robot_cannot_equip_or_unequip() -> void:
	var slot: int = _give(BASIC_ARMS_PATH)
	_robot.battery.consume(_robot.battery.get_current())
	watch_signals(_robot.equipment)
	var equipped: ActionResult = _robot.equip(slot)
	assert_false(equipped.ok, "a dead robot does not equip")
	assert_eq(equipped.error_key, ActionResult.ERR_INVALID_REQUEST, "reason")
	var removed: ActionResult = _robot.unequip(LEGS)
	assert_false(removed.ok, "nor unequip")
	assert_signal_not_emitted(_robot.equipment, "equipment_changed", "nothing changed")
	assert_not_null(_robot.inventory.get_slots()[slot], "the arms stay in the inventory")


func test_r_015_13_each_change_recomputes_once() -> void:
	watch_signals(_robot.stats)
	var slot: int = _give(BASIC_ARMS_PATH)
	assert_true(_robot.equip(slot).ok, "equip")
	assert_signal_emit_count(_robot.stats, "stats_changed", 1, "equip")
	assert_true(_robot.unequip(ARMS).ok, "unequip")
	assert_signal_emit_count(_robot.stats, "stats_changed", 2, "unequip")
	var spare: int = _give(BASIC_LEGS_PATH)
	assert_true(_robot.equip(spare).ok, "swap legs")
	assert_signal_emit_count(_robot.stats, "stats_changed", 3, "swap")
	var hits: int = ceili(float(_piece(BASIC_LEGS_PATH).durability_max) / _base.durability_per_hit)
	for i: int in hits:
		_robot.receive_hit(0.0, null)
	assert_null(_robot.equipment.get_piece(LEGS), "the legs broke")
	assert_signal_emit_count(_robot.stats, "stats_changed", 4, "break: only the hit that broke it")
	var _taken: Array[ItemStack] = _robot.equipment.take_slots([CORE])
	assert_signal_emit_count(_robot.stats, "stats_changed", 5, "death")
	_robot.equipment.from_save_data(_robot.equipment.to_save_data())
	assert_signal_emit_count(_robot.stats, "stats_changed", 6, "load")


func test_r_015_14_consumers_follow_stats() -> void:
	_equip_new(BASIC_ARMS_PATH)
	assert_eq(_robot.melee.attack.damage, roundi(_stat(BASIC_ARMS_PATH, StatIds.ATTACK_DAMAGE)), "attack")
	assert_true(_robot.unequip(LEGS).ok, "legs off")
	assert_almost_eq(
		_robot.battery.drain_per_second(LocomotionSystem.Gait.WALK),
		_robot.stats.get_stat(StatIds.PASSIVE_DRAIN) + _base.walk_drain, TOLERANCE, "battery"
	)


func test_r_015_15_legs_walk_run_and_drain() -> void:
	var walk: float = _stat(BASIC_LEGS_PATH, StatIds.WALK_SPEED)
	var run: float = _stat(BASIC_LEGS_PATH, StatIds.RUN_SPEED)
	Input.action_press(&"move_forward")
	await wait_physics_frames(3)
	assert_almost_eq(_robot.velocity.length(), walk, 0.01, "walks at the legs' speed")
	Input.action_press(&"run")
	await wait_physics_frames(3)
	assert_almost_eq(_robot.velocity.length(), run, 0.01, "runs at the legs' speed")
	var passive: float = _stat(BASIC_CORE_PATH, StatIds.PASSIVE_DRAIN)
	assert_almost_eq(
		_robot.battery.drain_per_second(LocomotionSystem.Gait.WALK),
		passive + _stat(BASIC_LEGS_PATH, StatIds.WALK_DRAIN), TOLERANCE, "walking drain of the legs"
	)
	assert_almost_eq(
		_robot.battery.drain_per_second(LocomotionSystem.Gait.RUN), passive + _base.run_drain, TOLERANCE,
		"running drain of BALANCE §1.1"
	)


func test_r_015_15_no_legs_slow_never_runs() -> void:
	assert_true(_robot.unequip(LEGS).ok, "legs off")
	Input.action_press(&"move_forward")
	Input.action_press(&"run")
	await wait_physics_frames(3)
	assert_almost_eq(_robot.velocity.length(), _base.walk_speed, 0.01, "no-legs speed, whatever the run input")
	assert_almost_eq(
		_robot.battery.drain_per_second(LocomotionSystem.Gait.WALK),
		_robot.stats.get_stat(StatIds.PASSIVE_DRAIN) + _base.walk_drain, TOLERANCE, "no-legs walking drain"
	)


func test_r_015_16_arms_damage_and_cost() -> void:
	_equip_new(BASIC_ARMS_PATH)
	assert_eq(_robot.melee.attack.damage, roundi(_stat(BASIC_ARMS_PATH, StatIds.ATTACK_DAMAGE)), "damage")
	assert_eq(_robot.melee.attack.attacks_per_second, _stat(BASIC_ARMS_PATH, StatIds.ATTACKS_PER_SECOND), "rate")
	assert_eq(_robot.melee.attack.battery_cost, _stat(BASIC_ARMS_PATH, StatIds.BATTERY_PER_SWING), "cost")


func test_r_015_16_no_arms_one_arm_values() -> void:
	_equip_new(BASIC_ARMS_PATH)
	assert_true(_robot.unequip(ARMS).ok, "arms off")
	assert_eq(_robot.melee.attack.damage, roundi(_base.attack_damage), "one arm damage")
	assert_eq(_robot.melee.attack.attacks_per_second, _base.attacks_per_second, "one arm rate")
	assert_eq(_robot.melee.attack.battery_cost, _base.battery_per_swing, "one arm cost")
	assert_true(CombatSystem.is_valid_attack(_robot.melee.attack), "never without an attack")


func test_r_015_18_core_and_generator_bonus() -> void:
	var core_maximum: float = _stat(BASIC_CORE_PATH, StatIds.MAX_BATTERY)
	assert_eq(_robot.battery.get_maximum(), core_maximum, "the Core's maximum")
	_robot.battery.set_maximum_bonus(20.0)
	assert_eq(_robot.battery.get_maximum(), core_maximum + 20.0, "plus the generator")
	assert_true(_robot.unequip(CORE).ok, "Core off")
	assert_eq(_robot.battery.get_maximum(), _base.max_battery + 20.0, "the no-Core value plus the generator")


func test_r_015_19_removing_basic_core_keeps_charge() -> void:
	_robot.battery.consume(10.0)
	var charge: float = _robot.battery.get_current()
	watch_signals(_robot.battery)
	assert_true(_robot.unequip(CORE).ok, "Core off")
	assert_eq(_robot.battery.get_current(), charge, "the charge stays (BALANCE §4.2: the maximum does not drop)")
	assert_signal_not_emitted(_robot.battery, "battery_low")
	assert_signal_not_emitted(_robot.battery, "battery_depleted")


func test_r_015_44_no_core_double_drain() -> void:
	var with_core: float = _robot.battery.drain_per_second(LocomotionSystem.Gait.IDLE)
	assert_almost_eq(with_core, _stat(BASIC_CORE_PATH, StatIds.PASSIVE_DRAIN), TOLERANCE, "the Core's rate")
	assert_true(_robot.unequip(CORE).ok, "Core off")
	assert_almost_eq(
		_robot.battery.drain_per_second(LocomotionSystem.Gait.IDLE), _base.passive_drain, TOLERANCE, "no-Core rate"
	)
	assert_true(_robot.equip(0).ok, "Core on again, from the slot it went to")
	assert_almost_eq(_robot.battery.drain_per_second(LocomotionSystem.Gait.IDLE), with_core, TOLERANCE, "back")


func test_r_015_22_depleted_robot_does_not_wear() -> void:
	_robot.battery.consume(_robot.battery.get_current())
	var legs: int = _robot.equipment.get_piece(LEGS).durability
	_robot.receive_hit(HIT, null)
	assert_eq(_robot.equipment.get_piece(LEGS).durability, legs, "a hit the robot does not take wears nothing")


func test_r_015_23_broken_arms_back_to_one_arm() -> void:
	_equip_new(BASIC_ARMS_PATH)
	watch_signals(_robot.equipment)
	var hits: int = ceili(float(_piece(BASIC_ARMS_PATH).durability_max) / _base.durability_per_hit)
	for i: int in hits:
		_robot.receive_hit(0.0, null)
	assert_signal_emit_count(_robot.equipment, "piece_broken", 1, "the arms broke")
	assert_null(_robot.equipment.get_piece(ARMS), "the slot is empty")
	assert_eq(_robot.melee.attack.damage, roundi(_base.attack_damage), "one arm again")
	assert_eq(_robot.equipment.get_piece(LEGS).durability, _piece(BASIC_LEGS_PATH).durability_max, "the legs are next")
	_robot.receive_hit(0.0, null)
	assert_lt(_robot.equipment.get_piece(LEGS).durability, _piece(BASIC_LEGS_PATH).durability_max, "now the legs wear")


func test_r_015_54_wear_before_battery() -> void:
	_equip_new(BASIC_ARMS_PATH)
	var seen: Array[int] = []
	_robot.battery.battery_changed.connect(
		func(_current: float, _maximum: float) -> void: seen.append(_robot.equipment.get_piece(ARMS).durability)
	)
	_robot.receive_hit(HIT, null)
	var expected: int = _piece(BASIC_ARMS_PATH).durability_max - roundi(_base.durability_per_hit)
	assert_eq(seen, [expected] as Array[int], "the arms were already worn when the battery changed")
