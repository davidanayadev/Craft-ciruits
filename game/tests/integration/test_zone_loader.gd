extends GutTest
## ZoneLoader (spec 009) on a hand-made World: one zone in the slot after every
## travel (R-009-02), the robot on the arrival point and zone_changed once
## (R-009-03), pooled entities back in their pools on unloading (R-009-04),
## battery, inventory and XP untouched by a travel (R-009-05, architecture §6),
## refused travels leave the zone (R-009-06), only exits, Main and tests travel
## (R-009-13), the visit counts on leaving a farm zone by its exit and never on
## entering (R-009-14, R-009-15), a farm zone loads its current visit
## (R-009-16), dropped items come back (R-009-17), no enemies in the base
## (R-009-18) and entering it does not recharge (R-009-21).

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const ZOMBIE_SCENE := preload("res://scenes/entities/zombie.tscn")
const SPARKS_SCENE := preload("res://scenes/effects/impact_sparks.tscn")
const ITEM_SCENE := preload("res://scenes/entities/dropped_item.tscn")
const DROPPED_CONFIG_PATH := "res://resources/config/dropped_items.tres"
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const GREEN_ZONE_ID := Vector2i(0, 0)
const UNKNOWN_ZONE_ID := Vector2i(42, 42)
const BROKEN_ZONE_ID := Vector2i(43, 43)
const TRAVEL_TIMEOUT_S := 10.0
const START_TIME := 1_000
const SCRIPT_DIRS: PackedStringArray = ["res://scenes", "res://scripts"]
const TRAVEL_CALLERS: PackedStringArray = [
	"res://scenes/zones/zone_loader.gd", "res://scenes/main.gd"
]

var _world: Node3D
var _slot: Node3D
var _players: Node3D
var _robot: Robot
var _zombie_pool: ObjectPool
var _impact_pool: ObjectPool
var _item_pool: ObjectPool
var _dropped: DroppedItemSpawner
var _structures: BaseStructures
var _loader: ZoneLoader
var _clock: FakeTimeService


func before_each() -> void:
	GameManager.clear_visit_counts()
	_clock = FakeTimeService.new()
	_clock.now = START_TIME
	_world = Node3D.new()
	add_child_autofree(_world)
	_slot = Node3D.new()
	_world.add_child(_slot)
	_zombie_pool = _new_pool(ZOMBIE_SCENE)
	_impact_pool = _new_pool(SPARKS_SCENE)
	_item_pool = _new_pool(ITEM_SCENE)
	_dropped = DroppedItemSpawner.new()
	_dropped.pool = _item_pool
	_dropped.config = load(DROPPED_CONFIG_PATH) as DroppedItemConfigData
	_dropped.time_service = _clock
	_world.add_child(_dropped)
	_structures = BaseStructures.new()
	_structures.grid_config = load(BASE_GRID_PATH) as BuildGridData
	_world.add_child(_structures)
	_players = Node3D.new()
	_world.add_child(_players)
	_robot = ROBOT_SCENE.instantiate() as Robot
	_players.add_child(_robot)
	_robot.set_physics_process(false)
	_loader = ZoneLoader.new()
	_loader.zone_slot = _slot
	_loader.players_root = _players
	_loader.zombie_pool = _zombie_pool
	_loader.impact_pool = _impact_pool
	_loader.dropped_item_pool = _item_pool
	_loader.dropped_items = _dropped
	_loader.base_structures = _structures
	add_child_autofree(_loader)


func after_each() -> void:
	GameManager.clear_visit_counts()


func _new_pool(scene: PackedScene) -> ObjectPool:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = scene
	_world.add_child(pool)
	return pool


func _base_id() -> Vector2i:
	return DataRegistry.get_base_zone().zone_id


## Starts a travel and waits for it to end; false when it did not start.
func _travel(zone_id: Vector2i) -> bool:
	if not _loader.travel_to(zone_id).ok:
		return false
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)
	return not _loader.is_travelling()


## Leaves through the exit point of the loaded zone, as a player does.
func _leave_by_exit() -> void:
	var exit: Node = _loader.get_current_zone().get_node("%ExitPoint")
	(exit.get_node("Interactable") as InteractableComponent).interact(_robot)
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)


func _farm() -> FarmZone:
	return _loader.get_current_zone() as FarmZone


func test_r_009_02_one_zone_in_slot_after_each_travel() -> void:
	assert_true(await _travel(_base_id()), "to the base")
	assert_eq(_slot.get_child_count(), 1, "one zone after the first travel")
	assert_true(_slot.get_child(0) is BaseZone, "the base")
	assert_true(await _travel(GREEN_ZONE_ID), "to the green zone")
	assert_eq(_slot.get_child_count(), 1, "still one zone")
	assert_true(_slot.get_child(0) is FarmZone, "the green zone")
	assert_same(_loader.get_current_zone(), _slot.get_child(0), "the loader knows it")
	assert_eq(GameManager.get_current_zone_id(), GREEN_ZONE_ID, "GameManager holds it (R-009-09)")


func test_r_009_03_robot_on_arrival_point() -> void:
	_robot.global_position = Vector3(30.0, 0.0, 30.0)
	_robot.velocity = Vector3(3.0, 0.0, 0.0)
	assert_true(await _travel(GREEN_ZONE_ID))
	var spawn: Vector3 = _loader.get_current_zone().get_spawn_position()
	assert_lt(_robot.global_position.distance_to(spawn), 0.01, "on the spawn point")
	assert_eq(_robot.velocity, Vector3.ZERO, "standing still")


func test_r_009_03_zone_changed_once() -> void:
	watch_signals(EventBus)
	watch_signals(_loader)
	assert_true(await _travel(_base_id()))
	assert_signal_emit_count(EventBus, "zone_changed", 1, "once per travel")
	assert_signal_emitted_with_parameters(EventBus, "zone_changed", [_base_id()])
	assert_signal_emit_count(_loader, "travel_started", 1)
	assert_signal_emit_count(_loader, "zone_loaded", 1)


func test_r_009_04_enemies_back_in_pool() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	var enemies: int = _farm().get_enemies().size()
	assert_gt(enemies, 0, "the green zone has zombies")
	var free_before: int = _zombie_pool.get_free_count()
	assert_true(await _travel(_base_id()))
	assert_eq(_zombie_pool.get_free_count(), free_before + enemies, "every zombie went back")
	await wait_process_frames(2)
	assert_eq(_zombie_pool.get_free_count(), free_before + enemies, "and none was freed with the zone")


func test_r_009_04_dropped_items_back_in_pool() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	_dropped.drop_stacks(
		[ItemStack.new(DataRegistry.get_item(&"scrap"), 3)] as Array[ItemStack], Vector3(2.0, 0.0, 2.0)
	)
	var free_before: int = _item_pool.get_free_count()
	assert_true(await _travel(_base_id()))
	assert_eq(_item_pool.get_free_count(), free_before + 1, "the dropped item went back")


func test_r_009_05_round_trip_keeps_battery_inventory_xp() -> void:
	assert_true(await _travel(_base_id()))
	_robot.battery.consume(37.0)
	_robot.inventory.add(&"scrap", 7)
	_robot.experience.add_xp(15)
	var battery: float = _robot.battery.get_current()
	assert_true(await _travel(GREEN_ZONE_ID))
	assert_true(await _travel(_base_id()))
	assert_eq(_robot.battery.get_current(), battery, "same battery")
	assert_eq(_robot.inventory.count(&"scrap"), 7, "same inventory")
	assert_eq(_robot.experience.get_total(), 15, "same XP")


func test_r_009_06_unknown_zone_id() -> void:
	assert_true(await _travel(_base_id()))
	var zone: Zone = _loader.get_current_zone()
	var result: ActionResult = _loader.travel_to(UNKNOWN_ZONE_ID)
	assert_false(result.ok, "refused")
	assert_push_error("unknown zone")
	assert_false(_loader.is_travelling(), "no travel started")
	assert_same(_loader.get_current_zone(), zone, "the zone stays")


func test_r_009_06_travel_in_progress() -> void:
	assert_true(_loader.travel_to(_base_id()).ok, "a travel starts")
	var second: ActionResult = _loader.travel_to(GREEN_ZONE_ID)
	assert_false(second.ok, "a second travel is refused")
	assert_push_error("already in progress")
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)
	assert_true(_loader.get_current_zone() is BaseZone, "the first travel ends where it went")


func test_r_009_06_load_failure_keeps_zone_and_visit() -> void:
	var broken: ZoneData = ZoneData.new()
	broken.zone_id = BROKEN_ZONE_ID
	broken.kind = ZoneData.Kind.FARM
	broken.scene_path = "res://scenes/zone_loader_test_missing.tscn"
	var catalog: DataCatalog = DataRegistry.get_catalog()
	catalog.zones.append(broken)
	catalog.build_index()
	assert_true(await _travel(GREEN_ZONE_ID))
	var zone: Zone = _loader.get_current_zone()
	watch_signals(_loader)
	_loader.travel_to(BROKEN_ZONE_ID)
	await wait_for_signal(_loader.travel_failed, TRAVEL_TIMEOUT_S)
	catalog.zones.erase(broken)
	catalog.build_index()
	assert_signal_emitted(_loader, "travel_failed", "the failure is reported")
	assert_push_error("travel to (43, 43) failed")
	assert_engine_error("Cannot open file")
	assert_engine_error("Failed loading resource")
	assert_false(_loader.is_travelling(), "the travel is over")
	assert_same(_loader.get_current_zone(), zone, "the zone stays")
	assert_eq(_slot.get_child_count(), 1, "alone in the slot")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT, "no visit counted")
	assert_gt(_farm().get_enemies().size(), 0, "its zombies are still there")


func test_r_009_13_travel_to_callers() -> void:
	var callers: PackedStringArray = PackedStringArray()
	for directory: String in SCRIPT_DIRS:
		_collect_callers(directory, "travel_to(", callers)
	callers.sort()
	var expected: PackedStringArray = TRAVEL_CALLERS.duplicate()
	expected.sort()
	assert_eq(callers, expected, "only the loader (exits) and Main (start-up, death) travel")


func _collect_callers(directory: String, needle: String, callers: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(directory):
		_collect_callers(directory.path_join(sub), needle, callers)
	for file: String in DirAccess.get_files_at(directory):
		var path: String = directory.path_join(file)
		if file.ends_with(".gd") and FileAccess.get_file_as_string(path).contains(needle):
			callers.append(path)


func test_r_009_14_leaving_farm_counts_one_visit() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	watch_signals(GameManager)
	await _leave_by_exit()
	assert_true(_loader.get_current_zone() is BaseZone, "the exit leads to the base")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT + 1, "one visit")
	assert_signal_emit_count(GameManager, "zone_visit_counted", 1, "counted once")


func test_r_009_15_entering_counts_nothing() -> void:
	assert_true(await _travel(_base_id()))
	await _leave_by_exit()
	assert_true(_loader.get_current_zone() is FarmZone, "the base leads to the green zone")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT, "entering counts no visit")


func test_r_009_15_leaving_base_counts_nothing() -> void:
	assert_true(await _travel(_base_id()))
	await _leave_by_exit()
	assert_eq(GameManager.get_visit_count(_base_id()), ZonePopulation.FIRST_VISIT, "the base counts no visit")


func test_r_009_15_travel_without_exit_counts_nothing() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	assert_true(await _travel(_base_id()))
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT, "only an exit counts")


func test_r_009_16_farm_populated_with_current_visit() -> void:
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	assert_true(await _travel(GREEN_ZONE_ID))
	var reference: FarmZone = (
		load("res://scenes/farm_zone/farm_zone_green.tscn") as PackedScene
	).instantiate() as FarmZone
	add_child_autofree(reference)
	var reference_pool: ObjectPool = ObjectPool.new()
	reference_pool.scene = ZOMBIE_SCENE
	add_child_autofree(reference_pool)
	reference.generate(GameManager.get_world_seed(), 2)
	reference.spawn_enemies(GameManager.get_world_seed(), 2, reference_pool)
	assert_eq(_describe_enemies(_farm()), _describe_enemies(reference), "the zombies of visit 2")
	var loaded_boxes: Array[LootBox] = _farm().get_boxes()
	var reference_boxes: Array[LootBox] = reference.get_boxes()
	assert_eq(loaded_boxes.size(), reference_boxes.size(), "the boxes of the zone")
	reference.despawn_enemies()


func _describe_enemies(zone: FarmZone) -> PackedStringArray:
	var described: PackedStringArray = PackedStringArray()
	for zombie: Zombie in zone.get_enemies():
		described.append("%s @ %s" % [zombie.get_data().id, zone.to_local(zombie.global_position)])
	described.sort()
	return described


func test_r_009_16_no_repopulation_while_travelling() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	var farm: FarmZone = _farm()
	var before: PackedStringArray = _describe_enemies(farm)
	assert_true(_loader.travel_to(_base_id()).ok)
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	assert_eq(_describe_enemies(farm), before, "the zone about to leave is not repopulated")
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)


func test_r_009_17_items_back_after_round_trip() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	_dropped.drop_stacks(
		[ItemStack.new(DataRegistry.get_item(&"iron"), 2)] as Array[ItemStack], Vector3(3.0, 0.0, -2.0)
	)
	var before: Array[Dictionary] = _dropped.to_data()
	assert_true(await _travel(_base_id()))
	assert_eq(_dropped.get_items().size(), 0, "not in the base")
	assert_true(await _travel(GREEN_ZONE_ID))
	assert_eq(_dropped.to_data(), before, "back in place in its zone")


func test_r_009_18_no_enemies_in_base() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	assert_true(await _travel(_base_id()))
	assert_eq(_loader.get_current_zone().find_children("*", "CharacterBody3D", true, false).size(), 0, "no enemy")
	var active: int = 0
	for node: Node in _world.find_children("*", "CharacterBody3D", true, false):
		if node is Zombie:
			active += 1
	assert_eq(active, 0, "no zombie anywhere in the world")


func test_r_009_21_entering_base_does_not_recharge() -> void:
	assert_true(await _travel(GREEN_ZONE_ID))
	_robot.battery.consume(40.0)
	var battery: float = _robot.battery.get_current()
	assert_true(await _travel(_base_id()))
	assert_eq(_robot.battery.get_current(), battery, "entering the base does not recharge")
