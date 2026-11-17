extends GutTest
## DeathController (spec 008): the death reaction follows the fields of the
## ruleset (R-008-03), a death counts one visit of the zone (R-008-07),
## player_died comes once per death whatever emptied the battery (R-008-25),
## the inventory falls where the robot died (R-008-26), an empty one creates
## nothing (R-008-27), XP and slots stay with the NORMAL ruleset (R-008-28),
## respawn restores the battery and announces itself once (R-008-31), every
## death makes its own item (R-008-32), and the controller holds no player
## state (R-008-34).
## The robot's physics is switched off: its battery only moves when the test says.

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const ITEM_SCENE := preload("res://scenes/entities/dropped_item.tscn")
const CONFIG_PATH := "res://resources/config/dropped_items.tres"
const ZONE_ID := Vector2i(3, -2)
const OTHER_ZONE_ID := Vector2i(-1, 4)
const ZONE_ORIGIN := Vector3(10.0, 0.0, 5.0)
const DEATH_POSITION := Vector3(4.0, 0.0, -3.0)
const RESPAWN_POSITION := Vector3(7.0, 0.0, 2.0)
const START_TIME := 1_000_000
const LATER_SECONDS := 120
const SCRAP := &"scrap"
const IRON := &"iron"
const CABLES := &"cables"
const SCRAP_EXTRA := 5
const IRON_AMOUNT := 20
const CABLES_AMOUNT := 7
const XP_AMOUNT := 40
const CUSTOM_RATIO := 0.5
const EXPECTED_VARIABLES: PackedStringArray = ["dropped_items", "ruleset"]

var _robot: Robot
var _pool: ObjectPool
var _spawner: DroppedItemSpawner
var _controller: DeathController
var _clock: FakeTimeService
var _zone_root: Node3D
var _listener_saw_empty_inventory: bool = false
var _listener_saw_items: int = -1


func before_each() -> void:
	GameManager.clear_visit_counts()
	_clock = FakeTimeService.new()
	_clock.now = START_TIME
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_robot.global_position = DEATH_POSITION
	_zone_root = Node3D.new()
	add_child_autofree(_zone_root)
	_zone_root.global_position = ZONE_ORIGIN
	_pool = ObjectPool.new()
	_pool.scene = ITEM_SCENE
	add_child_autofree(_pool)
	_spawner = DroppedItemSpawner.new()
	_spawner.pool = _pool
	_spawner.config = load(CONFIG_PATH) as DroppedItemConfigData
	_spawner.time_service = _clock
	add_child_autofree(_spawner)
	_spawner.bind_zone(ZONE_ID, _zone_root)
	_controller = _new_controller(GameManager.get_ruleset())


func after_each() -> void:
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	GameManager.clear_visit_counts()


func _new_controller(ruleset: RulesetData) -> DeathController:
	var controller: DeathController = DeathController.new()
	controller.dropped_items = _spawner
	controller.ruleset = ruleset
	add_child_autofree(controller)
	controller.bind(_robot)
	return controller


func _ruleset(drops: bool, keeps_xp: bool, ratio: float) -> RulesetData:
	var ruleset: RulesetData = RulesetData.new()
	ruleset.id = &"test_mode"
	ruleset.drops_inventory = drops
	ruleset.keeps_xp = keeps_xp
	ruleset.respawn_battery_ratio = ratio
	return ruleset


func _fill_inventory() -> void:
	var scrap_max: int = DataRegistry.get_item(SCRAP).stack_max
	_robot.inventory.add(SCRAP, scrap_max + SCRAP_EXTRA)
	_robot.inventory.add(IRON, IRON_AMOUNT)
	_robot.inventory.add(CABLES, CABLES_AMOUNT)


func _kill_by_consume() -> void:
	_robot.battery.consume(_robot.battery.get_current())


func _on_player_died(_player_uid: String) -> void:
	_listener_saw_empty_inventory = _robot.inventory.is_empty()
	_listener_saw_items = _spawner.get_items().size()


func test_r_008_03_reaction_follows_ruleset() -> void:
	var custom: RulesetData = _ruleset(false, false, CUSTOM_RATIO)
	_controller.ruleset = custom
	_fill_inventory()
	_robot.experience.add_xp(XP_AMOUNT)
	var scrap_before: int = _robot.inventory.count(SCRAP)
	_kill_by_consume()
	assert_eq(_robot.inventory.count(SCRAP), scrap_before, "the inventory stays")
	assert_eq(_robot.inventory.count(IRON), IRON_AMOUNT, "every item")
	assert_eq(_spawner.get_items().size(), 0, "nothing falls")
	assert_eq(_robot.experience.get_total(), 0, "the XP is lost")
	_controller.respawn(_robot, RESPAWN_POSITION)
	assert_almost_eq(
		_robot.battery.get_current(),
		_robot.battery.get_maximum() * CUSTOM_RATIO,
		0.001,
		"the battery follows the ratio of the ruleset"
	)


func test_r_008_07_death_counts_one_visit() -> void:
	assert_eq(GameManager.get_visit_count(ZONE_ID), ZonePopulation.FIRST_VISIT, "no visit yet")
	_kill_by_consume()
	assert_eq(GameManager.get_visit_count(ZONE_ID), ZonePopulation.FIRST_VISIT + 1, "one visit")
	assert_eq(
		GameManager.get_visit_count(OTHER_ZONE_ID), ZonePopulation.FIRST_VISIT, "other zones stay"
	)


func test_r_008_25_died_once_by_drain() -> void:
	watch_signals(EventBus)
	var gait: LocomotionSystem.Gait = LocomotionSystem.Gait.IDLE
	var rate: float = _robot.battery.drain_per_second(gait)
	var seconds: float = _robot.battery.get_maximum() / rate + 1.0
	_robot.battery.tick(seconds, gait)
	_robot.battery.tick(seconds, gait)
	assert_true(_robot.battery.is_depleted(), "the drain emptied the battery")
	assert_signal_emit_count(EventBus, "player_died", 1, "announced once")
	assert_signal_emitted_with_parameters(EventBus, "player_died", [_robot.player_uid])


func test_r_008_25_died_once_by_swing() -> void:
	var cost: float = _robot.melee.attack.battery_cost
	_robot.battery.consume(_robot.battery.get_current() - cost * 0.5)
	assert_false(_robot.battery.is_depleted(), "some battery left, less than a swing costs")
	watch_signals(EventBus)
	_robot.melee.tick(0.0, true, false, false)
	assert_true(_robot.battery.is_depleted(), "the swing emptied the battery")
	assert_signal_emit_count(EventBus, "player_died", 1, "announced once")
	assert_signal_emitted_with_parameters(EventBus, "player_died", [_robot.player_uid])


func test_r_008_25_died_once_by_hit() -> void:
	var attacker: Node3D = Node3D.new()
	add_child_autofree(attacker)
	watch_signals(EventBus)
	_robot.receive_hit(_robot.battery.get_current() + 10.0, attacker)
	_robot.receive_hit(10.0, attacker)
	assert_true(_robot.battery.is_depleted(), "the hit emptied the battery")
	assert_signal_emit_count(EventBus, "player_died", 1, "announced once")
	assert_signal_emitted_with_parameters(EventBus, "player_died", [_robot.player_uid])


func test_r_008_26_inventory_falls_where_it_died() -> void:
	_fill_inventory()
	var scrap_total: int = _robot.inventory.count(SCRAP)
	EventBus.player_died.connect(_on_player_died)
	_kill_by_consume()
	var items: Array[DroppedItem] = _spawner.get_items()
	assert_eq(items.size(), 1, "one dropped item")
	if items.size() != 1:
		return
	var contents: InventoryComponent = items[0].get_contents()
	assert_almost_eq(items[0].global_position, DEATH_POSITION, Vector3.ONE * 0.001, "where it died")
	assert_eq(contents.count(SCRAP), scrap_total, "all the scrap")
	assert_eq(contents.count(IRON), IRON_AMOUNT, "all the iron")
	assert_eq(contents.count(CABLES), CABLES_AMOUNT, "all the cables")
	assert_true(_robot.inventory.is_empty(), "the robot carries nothing")
	assert_true(_listener_saw_empty_inventory, "listeners of player_died see it already empty")
	assert_eq(_listener_saw_items, 1, "and the item already on the ground")


func test_r_008_27_empty_inventory_creates_nothing() -> void:
	watch_signals(EventBus)
	_kill_by_consume()
	assert_eq(_spawner.get_items().size(), 0, "no dropped item")
	assert_false(_spawner.is_checking_expiry(), "nothing to expire")
	assert_signal_emit_count(EventBus, "player_died", 1, "the death is still announced")


func test_r_008_28_xp_and_slots_unchanged() -> void:
	_fill_inventory()
	_robot.experience.add_xp(XP_AMOUNT)
	var slots: int = _robot.inventory.get_slot_count()
	_kill_by_consume()
	assert_eq(_robot.experience.get_total(), XP_AMOUNT, "the XP stays")
	assert_eq(_robot.inventory.get_slot_count(), slots, "the slots stay")
	_controller.respawn(_robot, RESPAWN_POSITION)
	assert_eq(_robot.experience.get_total(), XP_AMOUNT, "also after the respawn")
	assert_eq(_robot.inventory.get_slot_count(), slots, "and its slots")


func test_r_008_31_respawn_restores_battery_and_emits_once() -> void:
	var custom: RulesetData = _ruleset(true, true, CUSTOM_RATIO)
	_controller.ruleset = custom
	_kill_by_consume()
	_robot.velocity = Vector3(3.0, 0.0, 3.0)
	watch_signals(EventBus)
	_controller.respawn(_robot, RESPAWN_POSITION)
	assert_almost_eq(_robot.global_position, RESPAWN_POSITION, Vector3.ONE * 0.001, "at the point")
	assert_eq(_robot.velocity, Vector3.ZERO, "standing still")
	assert_almost_eq(
		_robot.battery.get_current(),
		_robot.battery.get_maximum() * CUSTOM_RATIO,
		0.001,
		"battery = maximum x ratio"
	)
	assert_signal_emit_count(EventBus, "player_respawned", 1, "announced once")
	assert_signal_emitted_with_parameters(EventBus, "player_respawned", [_robot.player_uid])


func test_r_008_31_respawn_of_living_robot_reports_error() -> void:
	_robot.battery.consume(10.0)
	var battery_before: float = _robot.battery.get_current()
	watch_signals(EventBus)
	_controller.respawn(_robot, RESPAWN_POSITION)
	assert_push_error("DeathController")
	assert_almost_eq(_robot.global_position, DEATH_POSITION, Vector3.ONE * 0.001, "not moved")
	assert_eq(_robot.battery.get_current(), battery_before, "battery unchanged")
	assert_signal_not_emitted(EventBus, "player_respawned")


func test_r_008_32_second_death_makes_its_own_item() -> void:
	_fill_inventory()
	_kill_by_consume()
	_controller.respawn(_robot, RESPAWN_POSITION)
	_robot.inventory.add(IRON, CABLES_AMOUNT)
	_clock.now += LATER_SECONDS
	_kill_by_consume()
	var items: Array[DroppedItem] = _spawner.get_items()
	assert_eq(items.size(), 2, "one item per death")
	if items.size() != 2:
		return
	assert_ne(items[0].uid, items[1].uid, "different uid")
	assert_eq(items[0].dropped_at_unix, START_TIME, "the first keeps its time")
	assert_eq(items[1].dropped_at_unix, START_TIME + LATER_SECONDS, "the second has its own")
	assert_eq(items[0].get_contents().count(IRON), IRON_AMOUNT, "the first is untouched")
	assert_eq(items[1].get_contents().count(IRON), CABLES_AMOUNT, "the second holds the new items")
	assert_eq(items[1].get_contents().count(SCRAP), 0, "and nothing of the first")


func test_r_008_34_controller_holds_no_player_state() -> void:
	var script: Script = _controller.get_script() as Script
	assert_not_null(script, "the controller has a script")
	if script == null:
		return
	var variables: PackedStringArray = PackedStringArray()
	for property: Dictionary in script.get_script_property_list():
		var usage: int = property["usage"]
		var property_name: String = property["name"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			variables.append(property_name)
	variables.sort()
	var expected: PackedStringArray = EXPECTED_VARIABLES.duplicate()
	expected.sort()
	assert_eq(variables, expected, "only the spawner and the ruleset")


func test_r_008_pending_impact_cancelled_at_death() -> void:
	_robot.melee.tick(0.0, true, false, false)
	assert_true(_robot.melee.is_impact_pending(), "mid-swing")
	_kill_by_consume()
	assert_false(_robot.melee.is_impact_pending(), "a dead robot does not hit")


func test_r_008_controller_without_ruleset_reports_error() -> void:
	_controller.ruleset = null
	_fill_inventory()
	watch_signals(EventBus)
	_kill_by_consume()
	assert_push_error("DeathController")
	assert_signal_not_emitted(EventBus, "player_died")
	assert_eq(_spawner.get_items().size(), 0, "nothing was dropped")
