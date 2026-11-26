extends GutTest
## Saving and loading the World through the real main scene (spec 010,
## R-010-09, 10, 14, 19, 21, 23..26, 33..37, 55, 63). Every test uses a
## MemorySaveStore (SaveTestSupport), never the real saves.
## "Close and reopen" = free the first Main and instantiate a second one with
## the same store: the second one boots through SaveFlow as the game does.
## The arrival of the second Main (position in its zone, battery) is recorded
## by a listener connected before the instance enters the tree: the world is
## frozen until travel_finished and nothing moves before it is read.
## R-010-09 approach: the signals are watched from before the second Main
## enters the tree, so the loading of its _ready is covered, up to the end of
## its first travel; a second test calls SaveManager.load_game() on a running
## scene. The hand-made World comes from tests/fixtures/saves/world_v1.json
## (re-keyed to the Profile's uuid), whose box markers are valid for KNOWN_SEED.
## Spec 011 (R-011-10): a piece keeps its durability and uid in the inventory
## and on the ground across a close and reopen.
## Spec 012: a charge above the base maximum survives a reload (R-012-14),
## generators count while the app is closed (R-012-16), chests keep their
## contents (R-012-36) and the World holds both (R-012-39); the clock is a
## FakeTimeService.
## Spec 014: only the total XP is saved and the level is recomputed on load
## (R-014-15); Experience loads before the inventory, so stacks beyond the
## level-1 slots survive (R-014-16); loading never emits level_up (R-014-17);
## a new World starts at level 1 (R-014-18).
## Manual: nothing here (the real files and the window are M1..M4 of plan 010
## §5.3).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FIXTURE_WORLD_PATH := "res://tests/fixtures/saves/world_v1.json"
const BATTERY_CONFIG_PATH := "res://resources/battery/robot_battery.tres"
const CHASSIS_LEVELS_PATH := "res://resources/progression/chassis_levels.tres"
const GREEN_ZONE_ID := Vector2i(0, 0)
const UNKNOWN_ZONE_ID := Vector2i(77, 77)
const STATION_CELL := Vector2i(9, 2)
const TRAVEL_TIMEOUT_S := 10.0
const BIG_SEED := -8213372036854775807
const NEWER_VERSION := 99
const WEEK_S := 7 * 24 * 60 * 60
const POSITION_TOLERANCE := 0.01
const BATTERY_TOLERANCE := 0.05
const GREEN_LOCAL_POSITION := Vector3(6.5, 0.0, -4.5)
const SCRAP_DURABILITY := 40
const NO_DURABILITY := -1
const DERIVED_KEYS: Array[String] = [
	"maximum", "max", "slot_count", "slots_count", "capacity", "inventory_slots"
]
## Parts that move a little with physics or the drain; compared with a tolerance.
const TOLERANT_KEYS: Array[String] = ["battery", "location"]

var _store: MemorySaveStore
## Where the robot stood in its zone, and its battery, when the first travel of
## the last instantiated Main ended.
var _arrival_local: Vector3 = Vector3.INF
var _arrival_world: Vector3 = Vector3.INF
var _arrival_zone_id: Vector2i = Vector2i.MAX
var _arrival_battery: float = -1.0


func before_each() -> void:
	_store = SaveTestSupport.start_world()


func after_each() -> void:
	for action: StringName in [&"open_storage", &"pause", &"ui_cancel"]:
		Input.action_release(action)
	SaveTestSupport.reset()


# --- Helpers: store and documents --------------------------------------------


func _world_file() -> String:
	var ids: PackedStringArray = _store.list_world_ids()
	assert_eq(ids.size(), 1, "exactly one World in the store")
	return "world_" + ids[0] if not ids.is_empty() else ""


func _read_world() -> Dictionary:
	var decoded: Variant = SaveCodec.decode(_store.get_bytes(_world_file(), ISaveStore.Copy.MAIN))
	assert_true(decoded is Dictionary, "the World file holds a document")
	var document: Dictionary = decoded if decoded is Dictionary else {}
	return document


func _write_world(document: Dictionary) -> void:
	_store.put(_world_file(), ISaveStore.Copy.MAIN, SaveCodec.encode(document))


func _player_parts(document: Dictionary) -> Dictionary:
	var players: Dictionary = document[SaveDocuments.KEY_PLAYERS]
	var parts: Dictionary = players.get(SaveManager.get_player_uuid(), {})
	return parts


func _world_parts(document: Dictionary) -> Dictionary:
	var parts: Dictionary = document[SaveDocuments.KEY_WORLD]
	return parts


func _set_player_part(document: Dictionary, key: String, part: Dictionary) -> void:
	var players: Dictionary = document[SaveDocuments.KEY_PLAYERS]
	var uuid: String = SaveManager.get_player_uuid()
	var parts: Dictionary = players.get(uuid, {})
	parts[key] = part
	players[uuid] = parts


## The World of the fixture, as the Profile's player would have saved it.
func _fixture_document(battery_current: float) -> Dictionary:
	var decoded: Variant = SaveCodec.decode(FileAccess.get_file_as_bytes(FIXTURE_WORLD_PATH))
	assert_true(decoded is Dictionary, "the fixture decodes")
	var document: Dictionary = decoded if decoded is Dictionary else {}
	var players: Dictionary = document[SaveDocuments.KEY_PLAYERS]
	var fixture_uid: String = players.keys()[0]
	var parts: Dictionary = players[fixture_uid]
	players.erase(fixture_uid)
	players[SaveManager.get_player_uuid()] = parts
	parts["battery"] = {"current": battery_current}
	var current: Dictionary = _read_world()
	document[SaveDocuments.KEY_WORLD_ID] = current[SaveDocuments.KEY_WORLD_ID]
	return document


func _slot_entry(item_id: String, quantity: int, durability: int, uid: String) -> Dictionary:
	return {"item_id": item_id, "quantity": quantity, "durability": durability, "uid": uid}


func _has_key_deep(value: Variant, key: String) -> bool:
	if value is Dictionary:
		var fields: Dictionary = value
		for field: Variant in fields:
			if str(field) == key or _has_key_deep(fields[field], key):
				return true
	elif value is Array:
		for entry: Variant in value as Array:
			if _has_key_deep(entry, key):
				return true
	return false


# --- Helpers: Main ------------------------------------------------------------


## By name, so it works before the instance is in the tree.
func _child(parent: Node, node_name: String) -> Node:
	return parent.find_child(node_name, true, false)


func _robot_of(main: Node) -> Robot:
	return main.get_node("%Robot") as Robot


func _loader_of(main: Node) -> ZoneLoader:
	return main.get_node("%ZoneLoader") as ZoneLoader


func _ui_of(main: Node) -> UIManager:
	return main.get_node("%UIManager") as UIManager


func _structures_of(main: Node) -> BaseStructures:
	return main.get_node("%BaseStructures") as BaseStructures


func _spawner_of(main: Node) -> DroppedItemSpawner:
	return main.get_node("%DroppedItems") as DroppedItemSpawner


func _farm_of(main: Node) -> FarmZone:
	return _loader_of(main).get_current_zone() as FarmZone


## A Main that starts like the game: SaveFlow loads from the store in _ready.
## Returns once its first travel ended (there is none when the game is blocked).
func _open_main() -> Node:
	var main: Node = _instance_main()
	add_child_autofree(main)
	await _await_travel(main)
	return main


## An instance with the arrival recorder connected, not in the tree yet.
func _instance_main() -> Node:
	var main: Node = MAIN_SCENE.instantiate()
	var loader: ZoneLoader = _child(main, "ZoneLoader") as ZoneLoader
	var robot: Robot = _child(main, "Robot") as Robot
	var battery: BatteryComponent = _child(robot, "BatteryComponent") as BatteryComponent
	_arrival_local = Vector3.INF
	_arrival_world = Vector3.INF
	_arrival_zone_id = Vector2i.MAX
	_arrival_battery = -1.0
	var record: Callable = func(zone_id: Vector2i) -> void:
		_arrival_zone_id = zone_id
		_arrival_world = robot.global_position
		_arrival_local = loader.get_current_zone().to_local(robot.global_position)
		_arrival_battery = battery.get_current()
	loader.travel_finished.connect(record)
	return main


func _await_travel(main: Node) -> void:
	var loader: ZoneLoader = _loader_of(main)
	if loader.is_travelling():
		await wait_for_signal(loader.travel_finished, TRAVEL_TIMEOUT_S)


func _travel_to(main: Node, zone_id: Vector2i) -> void:
	await _await_travel(main)
	_loader_of(main).travel_to(zone_id)
	await wait_for_signal(_loader_of(main).travel_finished, TRAVEL_TIMEOUT_S)


func _close_main(main: Node) -> void:
	main.queue_free()
	await wait_process_frames(2)


func _open_box(main: Node, index: int) -> LootBox:
	var box: LootBox = _farm_of(main).get_boxes()[index]
	(box.get_node("%Interactable") as InteractableComponent).interact(_robot_of(main))
	_ui_of(main).close_all()
	return box


func _take_first_slot(main: Node, box: LootBox) -> void:
	var first: Array[int] = [0]
	_robot_of(main).inventory.take_from(box.get_contents(), first)


func _take_everything(main: Node, box: LootBox) -> void:
	var contents: InventoryComponent = box.get_contents()
	var slots: Array[int] = []
	for index: int in contents.get_slot_count():
		slots.append(index)
	_robot_of(main).inventory.take_from(contents, slots)


func _kill_first_zombie(main: Node) -> void:
	var zombie: Enemy = _farm_of(main).get_zombies()[0]
	zombie.get_hurtbox().receive_attack(zombie.get_data().hp_max, _robot_of(main).player_uid)
	await wait_process_frames(2)


## Gives the robot the scrap of the recipe and places the station; its uid.
func _place_station(main: Node) -> String:
	var robot: Robot = _robot_of(main)
	var structures: BaseStructures = _structures_of(main)
	var recipe: RecipeData = DataRegistry.get_recipe(&"charging_station")
	robot.inventory.add(&"scrap", CraftingSystem.cost_of(recipe)[&"scrap"])
	var placed: ActionResult = structures.place(robot, recipe, STATION_CELL)
	assert_true(placed.ok, "the station is placed")
	return structures.structure_at(STATION_CELL)


## What every owner of this Main and of GameManager would save, by save key.
func _snapshot(main: Node) -> Dictionary:
	var state: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(SaveDocuments.PERSISTENT_GROUP):
		if node != GameManager and not main.is_ancestor_of(node):
			continue
		var key: StringName = node.call(&"get_save_key")
		var data: Dictionary = node.call(&"to_save_data")
		state[String(key)] = data
	return state


## "item id -> quantity" of an inventory.
func _held(inventory: InventoryComponent) -> Dictionary[StringName, int]:
	var held: Dictionary[StringName, int] = {}
	for stack: ItemStack in inventory.get_slots():
		if stack != null:
			held[stack.item.id] = held.get(stack.item.id, 0) + stack.quantity
	return held


func _compare_snapshots(before: Dictionary, after: Dictionary) -> void:
	for key: String in before:
		if TOLERANT_KEYS.has(key):
			continue
		assert_true(after.has(key), "the owner '%s' is still there" % key)
		var saved: Dictionary = before[key]
		var loaded: Dictionary = after.get(key, {})
		assert_eq(loaded, saved, "owner '%s' has the state it was saved with" % key)


# --- R-010-09 -----------------------------------------------------------------


func test_r_010_09_load_emits_no_fact_signal() -> void:
	var config: BatteryConfigData = load(BATTERY_CONFIG_PATH) as BatteryConfigData
	var low: float = _starting_max_battery() * config.low_threshold_ratio * 0.5
	_write_world(_fixture_document(low))
	var main: Node = _instance_main()
	var robot: Robot = _child(main, "Robot") as Robot
	var battery: BatteryComponent = _child(robot, "BatteryComponent") as BatteryComponent
	var inventory: InventoryComponent = _child(robot, "InventoryComponent") as InventoryComponent
	var experience: ExperienceComponent = _child(robot, "Experience") as ExperienceComponent
	watch_signals(EventBus)
	watch_signals(GameManager)
	watch_signals(battery)
	watch_signals(inventory)
	watch_signals(experience)
	add_child_autofree(main)
	await _await_travel(main)
	assert_almost_eq(battery.get_current(), low, BATTERY_TOLERANCE, "the low battery was loaded")
	assert_signal_emitted(battery, "battery_changed")
	assert_signal_emitted(inventory, "inventory_changed")
	assert_signal_emitted(experience, "xp_changed")
	assert_signal_not_emitted(battery, "battery_low")
	assert_signal_not_emitted(battery, "battery_depleted")
	assert_signal_not_emitted(inventory, "overflowed")
	assert_signal_not_emitted(GameManager, "zone_visit_counted")
	assert_signal_emit_count(EventBus, "zone_changed", 1)
	for info: Dictionary in EventBus.get_signal_list():
		var signal_name: String = info["name"]
		if signal_name != "zone_changed":
			assert_signal_not_emitted(EventBus, signal_name, "loading emitted the fact '%s'" % signal_name)
	assert_false(_ui_of(main).is_modal_open(), "no box opened a screen")
	assert_eq(_spawner_of(main).get_items().size(), 1, "only the saved dropped item, no new drop")
	assert_eq(_farm_of(main).get_visit(), 2, "the saved visit")


func test_r_010_09_load_game_on_running_scene_emits_no_fact_signal() -> void:
	var main: Node = await _open_main()
	var config: BatteryConfigData = load(BATTERY_CONFIG_PATH) as BatteryConfigData
	var low: float = _starting_max_battery() * config.low_threshold_ratio * 0.5
	_write_world(_fixture_document(low))
	var robot: Robot = _robot_of(main)
	watch_signals(EventBus)
	watch_signals(GameManager)
	watch_signals(robot.battery)
	watch_signals(robot.inventory)
	watch_signals(robot.experience)
	var loaded: ActionResult = SaveManager.load_game()
	assert_true(loaded.ok, "the World loads")
	assert_almost_eq(robot.battery.get_current(), low, BATTERY_TOLERANCE, "the low battery was loaded")
	assert_signal_emitted(robot.battery, "battery_changed")
	assert_signal_emitted(robot.inventory, "inventory_changed")
	assert_signal_emitted(robot.experience, "xp_changed")
	assert_signal_not_emitted(robot.battery, "battery_low")
	assert_signal_not_emitted(robot.battery, "battery_depleted")
	assert_signal_not_emitted(robot.inventory, "overflowed")
	assert_signal_not_emitted(GameManager, "zone_visit_counted")
	for info: Dictionary in EventBus.get_signal_list():
		var signal_name: String = info["name"]
		assert_signal_not_emitted(EventBus, signal_name, "loading emitted the fact '%s'" % signal_name)
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), 2, "the saved visit counter")


# --- R-010-10, 14, 19, 21 -----------------------------------------------------


func test_r_010_10_missing_key_keeps_new_game() -> void:
	var document: Dictionary = _read_world()
	_set_player_part(document, "battery", {"current": 40.0})
	_set_player_part(document, "experience", {"total": 9})
	var world_parts: Dictionary = _world_parts(document)
	world_parts["zone_visits"] = {"zones": [{"zone_id": [0, 0], "visit": 3}]}
	_write_world(document)
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	assert_true(robot.inventory.is_empty(), "no saved inventory: the new-game inventory")
	var chassis: ChassisLevelData = load(CHASSIS_LEVELS_PATH) as ChassisLevelData
	assert_eq(
		robot.inventory.get_slot_count(),
		chassis.get_inventory_slots(ChassisLevelData.FIRST_LEVEL),
		"with its slots"
	)
	var structures_part: Dictionary = _structures_of(main).to_save_data()
	var placed: Array = structures_part["placed"]
	assert_eq(placed.size(), 0, "no saved structures: none placed")
	assert_almost_eq(_arrival_battery, 40.0, BATTERY_TOLERANCE, "the rest loads: battery")
	assert_eq(robot.experience.get_total(), 9, "the rest loads: XP")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), 3, "the rest loads: visits")
	var base: BaseZone = _loader_of(main).get_current_zone() as BaseZone
	assert_not_null(base, "no saved location: the game starts in the base")
	if base != null:
		assert_lt(
			_arrival_world.distance_to(base.get_spawn_position()), POSITION_TOLERANCE, "on its spawn"
		)


func test_r_010_14_robot_takes_profile_uuid() -> void:
	var main: Node = await _open_main()
	var uuid: String = SaveManager.get_player_uuid()
	assert_false(uuid.is_empty(), "the Profile has a uuid")
	var robot: Robot = _robot_of(main)
	assert_eq(robot.player_uid, uuid, "the robot is the Profile's player")
	assert_eq(robot.melee.attacker_uid, uuid, "and its kills are credited to it")
	await _close_main(main)
	var again: Node = await _open_main()
	assert_eq(_robot_of(again).player_uid, uuid, "the same uuid after reopening")
	assert_eq(_robot_of(again).melee.attacker_uid, uuid, "also in the melee")


func test_r_010_19_new_world() -> void:
	_store = SaveTestSupport.reset()
	assert_eq(_store.list_world_ids().size(), 0, "no World to load")
	var main: Node = await _open_main()
	assert_eq(_store.list_world_ids().size(), 1, "a World was written at once")
	var document: Dictionary = _read_world()
	assert_eq(
		SaveDocuments.validate_world(document, DataRegistry.get_catalog()),
		PackedStringArray(),
		"a complete, valid document"
	)
	var world_id: String = document[SaveDocuments.KEY_WORLD_ID]
	assert_eq(world_id, GameManager.get_world_id(), "the header's id is the game's")
	assert_eq(world_id.length(), 32, "a uid")
	var seed_text: String = document[SaveDocuments.KEY_SEED]
	assert_eq(seed_text, str(GameManager.get_world_seed()), "the seed, written as text")
	var ruleset_id: String = document[SaveDocuments.KEY_RULESET_ID]
	assert_eq(ruleset_id, "normal", "the NORMAL ruleset")
	assert_eq(GameManager.get_ruleset(), DataRegistry.get_ruleset(&"normal"), "GameManager plays it")
	var version: int = SaveFields.to_int(document[SaveDocuments.KEY_SCHEMA_VERSION], 0)
	assert_eq(version, SaveMigrations.WORLD_VERSION, "its own version")
	var saved_at: int = SaveFields.to_int(document[SaveDocuments.KEY_SAVED_AT], 0)
	assert_gt(saved_at, 0, "with the time of the save")
	assert_true(_store.has_copy("profile", ISaveStore.Copy.MAIN), "and the Profile too")
	var base: BaseZone = _loader_of(main).get_current_zone() as BaseZone
	assert_not_null(base, "the robot starts in the base")
	if base != null:
		assert_lt(
			_arrival_world.distance_to(base.get_spawn_position()), POSITION_TOLERANCE, "on its spawn"
		)


func test_r_010_21_seed_never_changes() -> void:
	_store = SaveTestSupport.reset()
	SaveManager.load_profile()
	SaveManager.create_world(BIG_SEED)
	var main: Node = await _open_main()
	var world_id: String = GameManager.get_world_id()
	assert_eq(GameManager.get_world_seed(), BIG_SEED, "the seed given at creation")
	for cycle: int in 3:
		assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "save %d" % cycle)
		assert_true(SaveManager.load_game().ok, "load %d" % cycle)
		assert_eq(GameManager.get_world_seed(), BIG_SEED, "the seed after cycle %d" % cycle)
		var document: Dictionary = _read_world()
		var seed_text: String = document[SaveDocuments.KEY_SEED]
		assert_eq(seed_text, str(BIG_SEED), "the saved seed after cycle %d" % cycle)
		assert_eq(GameManager.get_world_id(), world_id, "the same World after cycle %d" % cycle)
	await _close_main(main)
	await _open_main()
	assert_eq(GameManager.get_world_seed(), BIG_SEED, "the seed after reopening")
	assert_eq(GameManager.get_world_id(), world_id, "the same World after reopening")


# --- R-010-23, 24, 25, 26 -----------------------------------------------------


func test_r_010_23_player_state_saved() -> void:
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	# A material stack with a durability and a uid only comes from a save, so
	# it is loaded into its slot (stacking keeps both since spec 011).
	var scrap_uid: String = Uid.generate()
	robot.inventory.from_save_data({"slots": [_slot_entry("scrap", 12, SCRAP_DURABILITY, scrap_uid)]})
	robot.battery.consume(36.5)
	robot.experience.add_xp(25)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var parts: Dictionary = _player_parts(_read_world())
	assert_false(parts.is_empty(), "the player is saved under its uid")
	var battery_part: Dictionary = parts["battery"]
	var current: float = battery_part["current"]
	assert_almost_eq(current, robot.battery.get_current(), 0.0001, "current battery")
	var inventory_part: Dictionary = parts["inventory"]
	var slots: Array = inventory_part["slots"]
	assert_eq(slots.size(), robot.inventory.get_slot_count(), "one entry per slot")
	var first: Dictionary = slots[0]
	var item_id: String = first["item_id"]
	var saved_uid: String = first["uid"]
	assert_eq(item_id, "scrap", "item id")
	assert_eq(SaveFields.to_int(first.get("quantity"), -1), 12, "quantity")
	assert_eq(SaveFields.to_int(first.get("durability"), -2), SCRAP_DURABILITY, "durability")
	assert_eq(saved_uid, scrap_uid, "uid")
	assert_true(slots[1] == null, "an empty slot is null")
	var experience_part: Dictionary = parts["experience"]
	assert_eq(SaveFields.to_int(experience_part.get("total"), -1), 25, "total XP")
	var location_part: Dictionary = parts["location"]
	var zone_id: Variant = SaveFields.to_vector2i(location_part.get("zone_id"))
	var local_position: Variant = SaveFields.to_vector3(location_part.get("position"))
	assert_true(zone_id is Vector2i, "a zone id")
	assert_true(local_position is Vector3, "a local position")
	var base: BaseZone = _loader_of(main).get_current_zone() as BaseZone
	assert_eq(zone_id as Vector2i, DataRegistry.get_base_zone().zone_id, "in the base")
	var expected_position: Vector3 = base.to_local(robot.global_position)
	assert_lt(
		(local_position as Vector3).distance_to(expected_position), POSITION_TOLERANCE, "local position"
	)


func test_r_010_24_derived_values_not_saved() -> void:
	var main: Node = await _open_main()
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var document: Dictionary = _read_world()
	var parts: Dictionary = _player_parts(document)
	var battery_part: Dictionary = parts["battery"]
	assert_eq(battery_part.keys(), ["current"], "the battery saves its charge only")
	var inventory_part: Dictionary = parts["inventory"]
	assert_eq(inventory_part.keys(), ["slots"], "the inventory saves its slots only")
	for key: String in DERIVED_KEYS:
		assert_false(_has_key_deep(document, key), "the document has no '%s'" % key)
	await _close_main(main)
	# A list shorter than the chassis gives, and a charge: the limits come from the .tres.
	_set_player_part(document, "battery", {"current": 55.0})
	_set_player_part(document, "inventory", {"slots": [_slot_entry("scrap", 3, NO_DURABILITY, ""), null]})
	_write_world(document)
	var again: Node = await _open_main()
	var robot: Robot = _robot_of(again)
	var chassis: ChassisLevelData = load(CHASSIS_LEVELS_PATH) as ChassisLevelData
	assert_eq(robot.battery.get_maximum(), robot.stats.get_stat(StatIds.MAX_BATTERY), "maximum from the stats")
	assert_almost_eq(_arrival_battery, 55.0, BATTERY_TOLERANCE, "the saved charge")
	assert_eq(
		robot.inventory.get_slot_count(),
		chassis.get_inventory_slots(ChassisLevelData.FIRST_LEVEL),
		"slots from chassis_levels.tres"
	)
	assert_eq(robot.inventory.count(&"scrap"), 3, "the saved stack")


func test_r_010_25_new_owner_needs_no_change() -> void:
	var main: Node = await _open_main()
	var fake: FakePersistentOwner = FakePersistentOwner.new()
	fake.value = 7
	fake.add_to_group(SaveDocuments.PERSISTENT_GROUP)
	(main.get_node("%World") as Node).add_child(fake)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var saved_part: Dictionary = _world_parts(_read_world()).get(String(FakePersistentOwner.SAVE_KEY), {})
	assert_eq(SaveFields.to_int(saved_part.get("value"), -1), 7, "saved under its key, in the world")
	fake.value = 0
	assert_true(SaveManager.load_game().ok, "loaded")
	assert_eq(fake.value, 7, "and given back to its owner")


func test_r_010_25_new_player_owner_needs_no_change() -> void:
	var main: Node = await _open_main()
	var fake: FakePersistentOwner = FakePersistentOwner.new()
	fake.value = 11
	fake.add_to_group(SaveDocuments.PERSISTENT_GROUP)
	_robot_of(main).add_child(fake)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var saved_part: Dictionary = _player_parts(_read_world()).get(String(FakePersistentOwner.SAVE_KEY), {})
	assert_eq(SaveFields.to_int(saved_part.get("value"), -1), 11, "saved under its key, under the player")
	fake.value = 0
	assert_true(SaveManager.load_game().ok, "loaded")
	assert_eq(fake.value, 11, "and given back to its owner")


func test_r_010_26_visit_counters() -> void:
	var main: Node = await _open_main()
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT + 2, "two visits counted")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	GameManager.clear_visit_counts()
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT, "cleared")
	watch_signals(GameManager)
	assert_true(SaveManager.load_game().ok, "loaded")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT + 2, "the saved counter is back")
	assert_signal_not_emitted(GameManager, "zone_visit_counted", "loading counts no visit")
	await _close_main(main)
	var again: Node = _instance_main()
	watch_signals(GameManager)
	add_child_autofree(again)
	await _await_travel(again)
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), ZonePopulation.FIRST_VISIT + 2, "the saved counter on reopening")
	assert_signal_not_emitted(GameManager, "zone_visit_counted", "reopening counts no visit")


# --- R-010-33, 34, 35, 36 -----------------------------------------------------


func test_r_010_33_no_elapsed_time() -> void:
	var a: Node = await _open_main()
	await _travel_to(a, GREEN_ZONE_ID)
	var robot: Robot = _robot_of(a)
	robot.battery.consume(38.5)
	_take_first_slot(a, _open_box(a, 0))
	await _kill_first_zombie(a)
	var battery: float = robot.battery.get_current()
	var visit_state: Dictionary = _farm_of(a).get_visit_state()
	var enemy_count: int = _farm_of(a).get_zombies().size()
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	# The clock of the game is the real one: the time that "passes" is a World
	# saved a week ago.
	var document: Dictionary = _read_world()
	document[SaveDocuments.KEY_SAVED_AT] = SaveFields.to_int(document[SaveDocuments.KEY_SAVED_AT], 0) - WEEK_S
	_write_world(document)
	await _close_main(a)
	var b: Node = await _open_main()
	assert_almost_eq(_arrival_battery, battery, BATTERY_TOLERANCE, "the battery is as saved")
	var farm: FarmZone = _farm_of(b)
	assert_not_null(farm, "back in the green zone")
	if farm == null:
		return
	assert_eq(farm.get_visit_state(), visit_state, "boxes and dead enemies as saved")
	assert_eq(farm.get_zombies().size(), enemy_count, "the living enemies are the same")


func test_r_010_34_loads_saved_zone_and_position() -> void:
	var a: Node = await _open_main()
	await _travel_to(a, GREEN_ZONE_ID)
	_robot_of(a).global_position = _farm_of(a).to_global(GREEN_LOCAL_POSITION)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved inside the green zone")
	await _close_main(a)
	var b: Node = await _open_main()
	var farm: FarmZone = _farm_of(b)
	assert_not_null(farm, "the green zone is loaded")
	assert_eq(_arrival_zone_id, GREEN_ZONE_ID, "the first travel went there")
	assert_lt(
		_arrival_local.distance_to(GREEN_LOCAL_POSITION), POSITION_TOLERANCE, "at the same local position"
	)
	if farm != null:
		assert_gt(farm.get_boxes().size(), 0, "populated")


func test_r_010_35_same_boxes_same_visit() -> void:
	var a: Node = await _open_main()
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	await _travel_to(a, GREEN_ZONE_ID)
	var farm_a: FarmZone = _farm_of(a)
	var positions: Array[Vector3] = []
	for box: LootBox in farm_a.get_boxes():
		positions.append(farm_a.to_local(box.global_position))
	assert_gte(positions.size(), 2, "the zone has boxes")
	var first: LootBox = _open_box(a, 0)
	_take_first_slot(a, first)
	var first_left: Dictionary = first.get_contents().to_save_data()
	var visit: int = farm_a.get_visit()
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	# Opened after the save: what the closed box would have held in that visit.
	var second_rolled: Dictionary = _open_box(a, 1).get_contents().to_save_data()
	await _close_main(a)
	var b: Node = await _open_main()
	var farm_b: FarmZone = _farm_of(b)
	assert_eq(farm_b.get_visit(), visit, "the saved visit")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), visit, "and its counter")
	assert_eq(farm_b.get_boxes().size(), positions.size(), "the same number of boxes")
	for index: int in mini(farm_b.get_boxes().size(), positions.size()):
		var box_position: Vector3 = farm_b.to_local(farm_b.get_boxes()[index].global_position)
		assert_lt(
			box_position.distance_to(positions[index]), POSITION_TOLERANCE, "box %d on its place" % index
		)
	var reopened: LootBox = farm_b.get_boxes()[0]
	assert_true(reopened.is_opened(), "the opened box stays open")
	assert_eq(reopened.get_contents().to_save_data(), first_left, "with what was left inside")
	var closed: LootBox = farm_b.get_boxes()[1]
	assert_false(closed.is_opened(), "the other one is still closed")
	var rolled: Dictionary = _open_box(b, 1).get_contents().to_save_data()
	assert_eq(rolled, second_rolled, "and rolls the contents of the same visit")


func test_r_010_36_bad_location_goes_to_base() -> void:
	var location: Dictionary = {
		"zone_id": [UNKNOWN_ZONE_ID.x, UNKNOWN_ZONE_ID.y], "position": [1.0, 0.0, 1.0]
	}
	await _check_location_goes_to_base(location)


func test_r_010_36_position_outside_zone_goes_to_base() -> void:
	var zone: ZoneData = DataRegistry.get_zone(GREEN_ZONE_ID)
	var outside: float = zone.size_m.x
	var location: Dictionary = {
		"zone_id": [GREEN_ZONE_ID.x, GREEN_ZONE_ID.y], "position": [outside, 0.0, 0.0]
	}
	await _check_location_goes_to_base(location)


## The location cannot be used: the base spawn point, one reported error, and
## the rest of the World loads.
func _check_location_goes_to_base(location: Dictionary) -> void:
	var document: Dictionary = _read_world()
	_set_player_part(document, "location", location)
	_set_player_part(document, "battery", {"current": 55.0})
	_set_player_part(
		document, "inventory", {"slots": [_slot_entry("scrap", 7, NO_DURABILITY, ""), null, null, null, null]}
	)
	_write_world(document)
	var main: Node = await _open_main()
	assert_push_error_count(1, "the unusable location is reported once")
	var base: BaseZone = _loader_of(main).get_current_zone() as BaseZone
	assert_not_null(base, "the base is loaded")
	if base != null:
		assert_lt(
			_arrival_world.distance_to(base.get_spawn_position()), POSITION_TOLERANCE, "on its spawn point"
		)
	assert_eq(_robot_of(main).inventory.count(&"scrap"), 7, "the rest loads: inventory")
	assert_almost_eq(_arrival_battery, 55.0, BATTERY_TOLERANCE, "the rest loads: battery")


# --- R-010-37 -----------------------------------------------------------------


func test_r_010_37_save_load_same_state() -> void:
	var a: Node = await _open_main()
	var robot: Robot = _robot_of(a)
	# A material stack with a durability and a uid only comes from a save, so
	# it is loaded into its slot (stacking keeps both since spec 011).
	robot.inventory.from_save_data(
		{"slots": [_slot_entry("scrap", 14, SCRAP_DURABILITY, Uid.generate())]}
	)
	robot.inventory.add(&"iron", 3)
	_place_station(a)
	robot.battery.consume(36.5)
	robot.experience.add_xp(17)
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	await _travel_to(a, GREEN_ZONE_ID)
	_take_first_slot(a, _open_box(a, 0))
	_open_box(a, 1)
	await _kill_first_zombie(a)
	robot.request_throw(0, 3)
	var farm: FarmZone = _farm_of(a)
	robot.global_position = farm.to_global(GREEN_LOCAL_POSITION)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var before: Dictionary = _snapshot(a)
	var battery: float = robot.battery.get_current()
	var visit_state: Dictionary = farm.get_visit_state()
	var dead_enemies: Array = visit_state["dead_enemies"]
	assert_gt(dead_enemies.size(), 0, "an enemy is dead")
	assert_gt(_spawner_of(a).get_items().size(), 0, "something is on the ground")
	await _close_main(a)
	var b: Node = await _open_main()
	var after: Dictionary = _snapshot(b)
	assert_eq(after.keys().size(), before.keys().size(), "the same owners")
	_compare_snapshots(before, after)
	assert_almost_eq(_arrival_battery, battery, BATTERY_TOLERANCE, "battery")
	assert_lt(_arrival_local.distance_to(GREEN_LOCAL_POSITION), POSITION_TOLERANCE, "position in the zone")
	assert_eq(_arrival_zone_id, GREEN_ZONE_ID, "zone")


# --- R-010-55 -----------------------------------------------------------------


func _send_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func test_r_010_55_notice_and_no_game() -> void:
	var document: Dictionary = _read_world()
	document[SaveDocuments.KEY_SCHEMA_VERSION] = NEWER_VERSION
	_write_world(document)
	var bytes_before: PackedByteArray = _store.get_bytes(_world_file(), ISaveStore.Copy.MAIN)
	var main: Node = _instance_main()
	add_child_autofree(main)
	await wait_process_frames(3)
	assert_push_error("newer version", "SaveManager reports the newer file")
	var ui: UIManager = _ui_of(main)
	var loader: ZoneLoader = _loader_of(main)
	assert_true(ui.is_open(NoticeScreen.SCREEN_ID), "the notice is open")
	assert_false(loader.is_travelling(), "no travel started")
	assert_true(loader.get_current_zone() == null, "no zone loaded")
	assert_eq((main.get_node("%World") as Node).process_mode, Node.PROCESS_MODE_DISABLED, "World frozen")
	assert_true((main.get_node("%SaveFlow") as SaveFlow).is_game_blocked(), "SaveFlow reports it")
	# The storage action and button, and "back" (pause, ui_cancel), do not close it.
	_send_action(&"open_storage", true)
	await wait_process_frames(2)
	_send_action(&"open_storage", false)
	(main.get_node("%Hud") as Hud).storage_pressed.emit()
	for action: StringName in [&"pause", &"ui_cancel"]:
		_send_action(action, true)
		await wait_process_frames(2)
		_send_action(action, false)
	assert_true(ui.is_open(NoticeScreen.SCREEN_ID), "the notice stays open")
	assert_false(ui.is_open(InventoryScreen.SCREEN_ID), "the inventory did not open")
	assert_false(loader.is_travelling(), "still no travel")
	assert_eq(_store.get_bytes(_world_file(), ISaveStore.Copy.MAIN), bytes_before, "the file was not overwritten")


# --- R-010-63 -----------------------------------------------------------------


func _collect_scrap(main: Node, needed: int) -> void:
	for box: LootBox in _farm_of(main).get_boxes():
		if _robot_of(main).inventory.count(&"scrap") >= needed:
			return
		_open_box(main, _farm_of(main).get_boxes().find(box))
		_take_everything(main, box)


func test_r_010_63_close_and_reopen_keeps_progress() -> void:
	var a: Node = await _open_main()
	var robot: Robot = _robot_of(a)
	await _travel_to(a, GREEN_ZONE_ID)
	await _kill_first_zombie(a)
	var recipe: RecipeData = DataRegistry.get_recipe(&"charging_station")
	var cost: int = CraftingSystem.cost_of(recipe)[&"scrap"]
	_collect_scrap(a, cost)
	assert_gte(robot.inventory.count(&"scrap"), cost, "enough scrap collected")
	# Leaving by the exit point counts the visit.
	_farm_of(a).exit_requested.emit(DataRegistry.get_base_zone(), robot)
	await wait_for_signal(_loader_of(a).travel_finished, TRAVEL_TIMEOUT_S)
	var base: BaseZone = _loader_of(a).get_current_zone() as BaseZone
	assert_not_null(base, "back in the base")
	if base == null:
		return
	var placed: ActionResult = _structures_of(a).place(robot, recipe, STATION_CELL)
	assert_true(placed.ok, "the station is placed")
	var station_uid: String = _structures_of(a).structure_at(STATION_CELL)
	robot.battery.consume(30.0)
	var station: Node = base.get_structures_root().get_child(0)
	(station.get_node("%Interactable") as InteractableComponent).interact(robot)
	assert_eq(robot.battery.get_current(), robot.battery.get_maximum(), "recharged to 100 %")
	robot.battery.consume(12.5)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var battery: float = robot.battery.get_current()
	var held: Dictionary[StringName, int] = _held(robot.inventory)
	var xp: int = robot.experience.get_total()
	var visit: int = GameManager.get_visit_count(GREEN_ZONE_ID)
	assert_gt(xp, 0, "the kill gave XP")
	assert_eq(visit, ZonePopulation.FIRST_VISIT + 1, "the exit counted a visit")
	await _close_main(a)
	var b: Node = await _open_main()
	var again: Robot = _robot_of(b)
	assert_almost_eq(_arrival_battery, battery, BATTERY_TOLERANCE, "same battery")
	assert_eq(_held(again.inventory), held, "same inventory")
	assert_eq(again.experience.get_total(), xp, "same XP")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), visit, "same visit number")
	assert_eq(_structures_of(b).structure_at(STATION_CELL), station_uid, "the station is on its cell")
	var base_again: BaseZone = _loader_of(b).get_current_zone() as BaseZone
	assert_not_null(base_again, "the robot is back in the base")
	if base_again != null:
		assert_eq(base_again.get_structures_root().get_child_count(), 1, "and the station stands there")


# --- R-011-10 -----------------------------------------------------------------


## A crafted piece at durability, put in robot's inventory.
func _give_piece(robot: Robot, piece_id: StringName, durability: int) -> ItemStack:
	var piece: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(piece_id))
	piece.durability = durability
	var offered: Array[ItemStack] = [piece]
	assert_true(robot.inventory.add_stacks(offered).ok, "the piece is in the inventory")
	return piece


## The stack holding piece_uid in inventory; null when none.
func _piece_in(inventory: InventoryComponent, piece_uid: String) -> ItemStack:
	var index: int = InventoryRules.index_of_uid(inventory.get_slots(), piece_uid)
	return null if index < 0 else inventory.get_slots()[index]


func test_r_011_10_piece_survives_close_and_reopen() -> void:
	var a: Node = await _open_main()
	var robot: Robot = _robot_of(a)
	var carried: ItemStack = _give_piece(robot, &"basic_arms", 40)
	var thrown: ItemStack = _give_piece(robot, &"basic_core", 70)
	robot.request_throw(InventoryRules.index_of_uid(robot.inventory.get_slots(), thrown.uid), 1)
	assert_null(_piece_in(robot.inventory, thrown.uid), "the core was thrown")
	assert_eq(_spawner_of(a).get_items().size(), 1, "it lies on the ground")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	await _close_main(a)
	var b: Node = await _open_main()
	var loaded: ItemStack = _piece_in(_robot_of(b).inventory, carried.uid)
	assert_not_null(loaded, "the carried piece is back with its uid")
	if loaded != null:
		assert_eq(loaded.item.id, &"basic_arms", "the same piece")
		assert_eq(loaded.durability, 40, "with its durability")
	var items: Array[DroppedItem] = _spawner_of(b).get_items()
	assert_eq(items.size(), 1, "the dropped item is back")
	if items.size() != 1:
		return
	var on_ground: ItemStack = _piece_in(items[0].get_contents(), thrown.uid)
	assert_not_null(on_ground, "the thrown piece is back on the ground with its uid")
	if on_ground != null:
		assert_eq(on_ground.durability, 70, "with its durability")


# --- Spec 012: generators and chests (R-012-14, 16, 36, 39) -------------------

const GENERATOR_RECIPE_PATH := "res://resources/recipes/wind_generator.tres"
const CHEST_RECIPE_PATH := "res://resources/recipes/storage_chest.tres"
const GENERATOR_CELL := Vector2i(1, 2)
const CHEST_CELL := Vector2i(0, 5)
const CLOCK_START := 1_700_000_000
const CHEST_IRON := 3


func _open_main_with_clock(clock: FakeTimeService) -> Node:
	var main: Node = _instance_main()
	(_child(main, "BaseStructures") as BaseStructures).time_service = clock
	add_child_autofree(main)
	await _await_travel(main)
	return main


## Gives the robot the cost of the recipe and places it; the uid.
func _build_at(main: Node, recipe_path: String, cell: Vector2i) -> String:
	var recipe: RecipeData = load(recipe_path) as RecipeData
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	for item_id: StringName in cost:
		_robot_of(main).inventory.add(item_id, cost[item_id])
	var placed: ActionResult = _structures_of(main).place(_robot_of(main), recipe, cell)
	assert_true(placed.ok, "%s is placed" % recipe.id)
	return _structures_of(main).structure_at(cell)


## The maximum battery of a new robot: the stat with its starting equipment
## (the basic Core, spec 015).
func _starting_max_battery() -> float:
	var base: RobotBaseStatsData = load("res://resources/robot/robot_base_stats.tres") as RobotBaseStatsData
	var core: PieceData = load("res://resources/pieces/basic_core.tres") as PieceData
	return StatsCalculator.compute(base.to_stats(), core.modifiers)[StatIds.MAX_BATTERY]


func _generator_data() -> WindGeneratorData:
	var recipe: RecipeData = load(GENERATOR_RECIPE_PATH) as RecipeData
	return recipe.result_structure as WindGeneratorData


func test_r_012_14_charge_above_base_maximum_survives_reload() -> void:
	var clock: FakeTimeService = FakeTimeService.new()
	clock.now = CLOCK_START
	var a: Node = await _open_main_with_clock(clock)
	var robot: Robot = _robot_of(a)
	var maximum: float = _starting_max_battery()
	var generator: WindGeneratorData = _generator_data()
	var _uid: String = _build_at(a, GENERATOR_RECIPE_PATH, GENERATOR_CELL)
	assert_eq(robot.battery.get_maximum(), maximum + generator.max_battery_bonus, "the bonus is applied")
	robot.battery.add(generator.max_battery_bonus / 2.0)
	var charge: float = robot.battery.get_current()
	assert_gt(charge, maximum, "the charge is above the base maximum")
	assert_lte(charge, maximum + generator.max_battery_bonus, "and within the new one")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	await _close_main(a)
	var b: Node = await _open_main_with_clock(clock)
	var again: Robot = _robot_of(b)
	assert_eq(again.battery.get_maximum(), maximum + generator.max_battery_bonus, "the bonus is back")
	assert_almost_eq(again.battery.get_current(), charge, BATTERY_TOLERANCE, "the charge above 100 is kept")
	assert_gt(again.battery.get_current(), maximum, "still above the base maximum")


func test_r_012_16_counts_while_app_closed() -> void:
	var clock: FakeTimeService = FakeTimeService.new()
	clock.now = CLOCK_START
	var a: Node = await _open_main_with_clock(clock)
	var generator: WindGeneratorData = _generator_data()
	var uid: String = _build_at(a, GENERATOR_RECIPE_PATH, GENERATOR_CELL)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	await _close_main(a)
	var closed_periods: int = mini(2, generator.max_stored)
	assert_gt(closed_periods, 0, "the generator can hold batteries")
	clock.now = CLOCK_START + generator.seconds_per_battery * closed_periods + generator.seconds_per_battery / 2
	var b: Node = await _open_main_with_clock(clock)
	assert_eq(_structures_of(b).structure_at(GENERATOR_CELL), uid, "the generator is back")
	var robot: Robot = _robot_of(b)
	assert_true(_structures_of(b).collect_batteries(robot, uid).ok, "batteries were made while closed")
	assert_eq(robot.inventory.count(generator.battery_item.id), closed_periods, "one per full period, no more")


func test_r_012_36_chest_survives_close_and_reopen() -> void:
	var a: Node = await _open_main()
	var uid: String = _build_at(a, CHEST_RECIPE_PATH, CHEST_CELL)
	assert_true(_structures_of(a).get_chest_contents(uid).add(&"iron", CHEST_IRON).ok, "iron left in the chest")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	await _close_main(a)
	var b: Node = await _open_main()
	assert_eq(_structures_of(b).structure_at(CHEST_CELL), uid, "the chest is on its cell")
	var contents: InventoryComponent = _structures_of(b).get_chest_contents(uid)
	assert_not_null(contents, "the chest has contents")
	if contents != null:
		assert_eq(contents.count(&"iron"), CHEST_IRON, "with what was left in it")


func test_r_012_39_world_holds_chests_and_generators() -> void:
	var clock: FakeTimeService = FakeTimeService.new()
	clock.now = CLOCK_START
	var a: Node = await _open_main_with_clock(clock)
	var chest_uid: String = _build_at(a, CHEST_RECIPE_PATH, CHEST_CELL)
	var generator_uid: String = _build_at(a, GENERATOR_RECIPE_PATH, GENERATOR_CELL)
	assert_true(_structures_of(a).get_chest_contents(chest_uid).add(&"iron", CHEST_IRON).ok, "iron in the chest")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var part: Dictionary = _world_parts(_read_world()).get(String(BaseStructures.SAVE_KEY), {})
	var chests: Dictionary = part.get("chests", {})
	var generators: Dictionary = part.get("generators", {})
	assert_eq(chests.keys(), [chest_uid], "one chest, by its uid")
	assert_eq(generators.keys(), [generator_uid], "one generator, by its uid")
	var chest: Dictionary = chests.get(chest_uid, {})
	var slots: Array = chest.get("slots", [])
	var chest_data: StorageChestData = (load(CHEST_RECIPE_PATH) as RecipeData).result_structure as StorageChestData
	assert_eq(slots.size(), chest_data.container.slot_count, "one entry per slot")
	var first: Dictionary = slots[0] if not slots.is_empty() and slots[0] is Dictionary else {}
	assert_eq(str(first.get("item_id", "")), "iron", "the iron is in the first slot")
	assert_eq(SaveFields.to_int(first.get("quantity"), -1), CHEST_IRON, "with its quantity")
	var saved_generator: Dictionary = generators.get(generator_uid, {})
	assert_eq(SaveFields.to_int(saved_generator.get("stored"), -1), 0, "starts empty")
	assert_eq(SaveFields.to_int(saved_generator.get("since_unix"), -1), CLOCK_START, "counting from its building")


# --- Spec 014: chassis level --------------------------------------------------


func _chassis() -> ChassisLevelData:
	return load(CHASSIS_LEVELS_PATH) as ChassisLevelData


## The current World with the robot's total XP set to the threshold of level.
func _document_at_level(level: int) -> Dictionary:
	var document: Dictionary = _read_world()
	_set_player_part(
		document, String(ExperienceComponent.SAVE_KEY), {"total": _chassis().get_xp_required(level)}
	)
	return document


func test_r_014_15_level_recomputed_on_load() -> void:
	var level: int = _chassis().get_level_count()
	_write_world(_document_at_level(level))
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	assert_eq(robot.experience.get_level(), level, "the level comes from the saved XP")
	assert_eq(robot.inventory.get_slot_count(), _chassis().get_inventory_slots(level), "and so do the slots")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var part: Dictionary = _player_parts(_read_world()).get(String(ExperienceComponent.SAVE_KEY), {})
	assert_eq(part.keys(), ["total"], "the experience saves its total only")
	var version: int = SaveFields.to_int(_read_world()[SaveDocuments.KEY_SCHEMA_VERSION], 0)
	assert_eq(version, SaveMigrations.WORLD_VERSION, "with no new schema version")


func test_r_014_16_saved_stacks_beyond_level_one_load() -> void:
	var level: int = _chassis().get_level_count()
	var slot_count: int = _chassis().get_inventory_slots(level)
	assert_gt(slot_count, _chassis().get_inventory_slots(ChassisLevelData.FIRST_LEVEL), "more than level 1")
	var document: Dictionary = _document_at_level(level)
	var slots: Array = []
	for index: int in slot_count:
		slots.append(_slot_entry("scrap", index + 1, NO_DURABILITY, ""))
	_set_player_part(document, "inventory", {"slots": slots})
	_write_world(document)
	var main: Node = await _open_main()
	var loaded: Array[ItemStack] = _robot_of(main).inventory.get_slots()
	assert_eq(loaded.size(), slot_count, "every slot of the level")
	for index: int in mini(loaded.size(), slot_count):
		var stack: ItemStack = loaded[index]
		assert_not_null(stack, "slot %d was loaded" % index)
		if stack != null:
			assert_eq(stack.quantity, index + 1, "slot %d keeps its stack" % index)
	assert_push_error_count(0)


func test_r_014_16_experience_loads_before_inventory() -> void:
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	var persistent: Array[Node] = get_tree().get_nodes_in_group(&"persistent")
	var experience_index: int = persistent.find(robot.experience)
	var inventory_index: int = persistent.find(robot.inventory)
	assert_gt(experience_index, -1, "Experience is persistent")
	assert_gt(inventory_index, -1, "InventoryComponent is persistent")
	assert_lt(experience_index, inventory_index, "SaveManager applies Experience first")


func test_r_014_17_load_never_emits_level_up() -> void:
	var level: int = _chassis().get_level_count()
	_write_world(_document_at_level(level))
	var main: Node = _instance_main()
	var experience: ExperienceComponent = _child(_child(main, "Robot"), "Experience") as ExperienceComponent
	watch_signals(experience)
	add_child_autofree(main)
	await _await_travel(main)
	assert_eq(experience.get_level(), level, "the saved level")
	assert_signal_emitted(experience, "xp_changed")
	assert_signal_emitted_with_parameters(experience, "level_changed", [level])
	assert_signal_not_emitted(experience, "level_up", "loading is not a level-up")
	watch_signals(experience)
	assert_true(SaveManager.load_game().ok, "loads again on the running scene")
	assert_signal_not_emitted(experience, "level_up", "not on a second load either")


func test_r_014_18_new_world_level_one() -> void:
	_store = SaveTestSupport.reset()
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	assert_eq(robot.experience.get_total(), 0, "no XP")
	assert_eq(robot.experience.get_level(), ChassisLevelData.FIRST_LEVEL, "level 1")
	assert_eq(
		robot.inventory.get_slot_count(),
		_chassis().get_inventory_slots(ChassisLevelData.FIRST_LEVEL),
		"with the slots of level 1"
	)


# --- Spec 015: equipment ------------------------------------------------------


## An equipment part entry for a new piece of item_id at durability.
func _piece_entry(item_id: String, durability: int) -> Dictionary:
	return {"item_id": item_id, "durability": durability, "uid": Uid.generate()}


func _equipment_part(arms: Variant, legs: Variant, core: Variant) -> Dictionary:
	return {"slots": {"arms": arms, "legs": legs, "core": core}}


func test_r_015_37_equipment_saved_and_reloaded() -> void:
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	robot.receive_hit(0.0, null)
	var legs: ItemStack = robot.equipment.get_piece(PieceData.SlotType.LEGS)
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved")
	var parts: Dictionary = _player_parts(_read_world())
	assert_true(parts.has("equipment"), "the equipment part is saved")
	assert_false(_has_key_deep(parts.get("equipment"), "stats"), "no stats in it")
	await _close_main(main)
	var again: Node = await _open_main()
	var loaded: ItemStack = _robot_of(again).equipment.get_piece(PieceData.SlotType.LEGS)
	assert_not_null(loaded, "the legs are back")
	if loaded != null:
		assert_eq(loaded.uid, legs.uid, "same uid")
		assert_eq(loaded.durability, legs.durability, "same durability")


func test_r_015_38_equipment_loads_before_battery() -> void:
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	var persistent: Array[Node] = get_tree().get_nodes_in_group(&"persistent")
	var equipment_index: int = persistent.find(robot.equipment)
	var battery_index: int = persistent.find(robot.battery)
	assert_gt(equipment_index, -1, "Equipment is persistent")
	assert_gt(battery_index, -1, "BatteryComponent is persistent")
	assert_lt(equipment_index, battery_index, "SaveManager applies the equipment first")
	for child: Node in robot.get_children():
		if child.is_in_group(&"persistent"):
			assert_eq(child, robot.equipment, "Equipment is the first persistent node of the robot")
			break


func test_r_015_38_saved_charge_up_to_core_maximum_kept() -> void:
	var document: Dictionary = _read_world()
	_set_player_part(document, "equipment", _equipment_part(null, null, _piece_entry("basic_core", 80)))
	_set_player_part(document, "battery", {"current": 99.5})
	_write_world(document)
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	assert_null(robot.equipment.get_piece(PieceData.SlotType.LEGS), "the saved equipment, not the starting one")
	assert_eq(robot.equipment.get_piece(PieceData.SlotType.CORE).durability, 80, "the saved Core")
	assert_almost_eq(_arrival_battery, 99.5, BATTERY_TOLERANCE, "the saved charge is not lowered")
	assert_push_error_count(0)


func test_r_015_39_load_emits_equipment_and_stats() -> void:
	var document: Dictionary = _read_world()
	_set_player_part(
		document, "equipment", _equipment_part(_piece_entry("basic_arms", 3), null, _piece_entry("basic_core", 1))
	)
	_write_world(document)
	var main: Node = _instance_main()
	var robot: Robot = _child(main, "Robot") as Robot
	var equipment: EquipmentComponent = _child(robot, "Equipment") as EquipmentComponent
	var stats: StatsComponent = _child(robot, "Stats") as StatsComponent
	watch_signals(equipment)
	watch_signals(stats)
	add_child_autofree(main)
	await _await_travel(main)
	assert_signal_emitted(equipment, "equipment_changed", "state on load")
	assert_signal_emitted(stats, "stats_changed", "the stats follow")
	assert_signal_not_emitted(equipment, "piece_broken", "loading breaks nothing")
	assert_eq(robot.stats.get_stat(StatIds.ATTACK_DAMAGE), 10.0, "the loaded arms count (BALANCE §4.2)")
	clear_signal_watcher()
	watch_signals(equipment)
	watch_signals(stats)
	assert_true(SaveManager.load_game().ok, "loads again on the running scene")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "once")
	assert_signal_emit_count(stats, "stats_changed", 1, "once")
	assert_signal_not_emitted(equipment, "piece_broken", "not on a second load either")


func test_r_015_40_rest_of_world_loads() -> void:
	var document: Dictionary = _read_world()
	_set_player_part(
		document, "equipment", _equipment_part(null, _piece_entry("no_such_piece", 50), _piece_entry("basic_arms", 50))
	)
	_set_player_part(document, "inventory", {"slots": [_slot_entry("scrap", 7, NO_DURABILITY, "")]})
	_set_player_part(document, "battery", {"current": 60.0})
	_write_world(document)
	var main: Node = await _open_main()
	assert_push_error_count(2, "each bad slot is reported")
	var robot: Robot = _robot_of(main)
	assert_null(robot.equipment.get_piece(PieceData.SlotType.LEGS), "an unknown id loads empty")
	assert_null(robot.equipment.get_piece(PieceData.SlotType.CORE), "arms in the Core slot load empty")
	assert_eq(robot.inventory.count(&"scrap"), 7, "the inventory loads")
	assert_almost_eq(_arrival_battery, 60.0, BATTERY_TOLERANCE, "the battery loads")


func test_r_015_41_new_world_starting_equipment() -> void:
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	var core: ItemStack = robot.equipment.get_piece(PieceData.SlotType.CORE)
	var legs: ItemStack = robot.equipment.get_piece(PieceData.SlotType.LEGS)
	assert_null(robot.equipment.get_piece(PieceData.SlotType.ARMS), "one arm (BALANCE §4.2)")
	assert_not_null(core, "a basic Core")
	assert_not_null(legs, "basic legs")
	if core == null or legs == null:
		return
	assert_eq(core.item.id, &"basic_core", "the basic Core")
	assert_eq(legs.item.id, &"basic_legs", "the basic legs")
	assert_eq(core.durability, (core.item as PieceData).durability_max, "new Core")
	assert_eq(legs.durability, (legs.item as PieceData).durability_max, "new legs")
	assert_false(core.uid.is_empty() or legs.uid.is_empty(), "with uids")
	assert_ne(core.uid, legs.uid, "different uids")


func test_r_015_42_world_without_equipment_part() -> void:
	var document: Dictionary = _fixture_document(63.5)
	assert_false(_player_parts(document).has("equipment"), "the fixture is from before spec 015")
	_write_world(document)
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	assert_not_null(robot.equipment.get_piece(PieceData.SlotType.CORE), "the starting Core")
	assert_not_null(robot.equipment.get_piece(PieceData.SlotType.LEGS), "the starting legs")
	assert_eq(SaveMigrations.WORLD_VERSION, 1, "no new schema_version")
	assert_push_error_count(0)


func test_r_015_42_empty_slots_load_empty() -> void:
	var document: Dictionary = _read_world()
	_set_player_part(document, "equipment", _equipment_part(null, null, null))
	_write_world(document)
	var main: Node = await _open_main()
	var robot: Robot = _robot_of(main)
	for slot: int in PieceData.SlotType.size():
		assert_null(robot.equipment.get_piece(slot as PieceData.SlotType), "slot %d loads empty" % slot)
	assert_push_error_count(0)
