extends GutTest
## The example files of schema version 1 (spec 010, R-010-54): they were
## written once by hand, in plain JSON, and must load into the current version
## for as long as the game exists. A change of format that breaks them needs a
## migration (SaveMigrations), never an edit of these files.
## Each one is decoded, migrated, validated against the real catalog and then
## loaded through SaveManager in a running Main from a MemorySaveStore.
## The box marker of the World file is one that the green zone has for the seed
## of the file (KNOWN_SEED); its dropped item is dated in 2100, so the real
## clock never expires it.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_PATH := "res://tests/fixtures/saves/world_v1.json"
const PROFILE_PATH := "res://tests/fixtures/saves/profile_v1.json"
const PLAYER_UID := "a1b2c3d4e5f60718293a4b5c6d7e8f90"
const WORLD_ID := "0f1e2d3c4b5a69788796a5b4c3d2e1f0"
const DROPPED_UID := "b1c2d3e4f5061728394a5b6c7d8e9f01"
const STATION_UID := "c1d2e3f405162738495a6b7c8d9e0f12"
const STACK_UID := "d1e2f30415263748596a7b8c9d0e1f23"
const GREEN_ZONE_ID := Vector2i(0, 0)
const STATION_CELL := Vector2i(9, 2)
const LOCAL_POSITION := Vector3(3.5, 0.0, -2.0)
const TRAVEL_TIMEOUT_S := 10.0
const BATTERY_TOLERANCE := 0.05
const POSITION_TOLERANCE := 0.01


func after_each() -> void:
	SaveTestSupport.reset()


func _document(path: String) -> Dictionary:
	var decoded: Variant = SaveCodec.decode(FileAccess.get_file_as_bytes(path))
	assert_true(decoded is Dictionary, "%s is a JSON object" % path)
	var document: Dictionary = decoded if decoded is Dictionary else {}
	return document


func test_r_010_54_world_v1_loads() -> void:
	var document: Dictionary = _document(WORLD_PATH)
	var version: int = SaveFields.to_int(document.get(SaveMigrations.VERSION_KEY), 0)
	assert_eq(version, 1, "it is a version 1 file")
	var migrated: SaveMigrations.Result = SaveMigrations.migrate_world(document)
	assert_true(
		migrated.outcome == SaveMigrations.Outcome.CURRENT
		or migrated.outcome == SaveMigrations.Outcome.MIGRATED,
		"it migrates to the current version"
	)
	assert_eq(
		SaveDocuments.validate_world(migrated.document, DataRegistry.get_catalog()),
		PackedStringArray(),
		"and validates against the catalog"
	)
	var header: SaveDocuments.WorldHeader = SaveDocuments.read_header(migrated.document)
	assert_eq(header.world_id, WORLD_ID, "header: world id")
	assert_eq(header.world_seed, SaveTestSupport.KNOWN_SEED, "header: seed")
	assert_eq(header.ruleset_id, &"normal", "header: ruleset")
	var players: Dictionary[String, Dictionary] = SaveDocuments.read_players(migrated.document)
	assert_true(players.has(PLAYER_UID), "one player, by its uid")
	var world_parts: Dictionary[String, Dictionary] = SaveDocuments.read_world_parts(migrated.document)
	for key: StringName in [&"zone_visits", &"farm_visits", &"dropped_items", &"structures"]:
		assert_true(world_parts.has(String(key)), "the world part '%s'" % key)

	await _load_world_in_main()


## The file goes through SaveManager, as the game would load it.
func _load_world_in_main() -> void:
	var store: MemorySaveStore = SaveTestSupport.reset()
	store.put("profile", ISaveStore.Copy.MAIN, FileAccess.get_file_as_bytes(PROFILE_PATH))
	store.put("world_" + WORLD_ID, ISaveStore.Copy.MAIN, FileAccess.get_file_as_bytes(WORLD_PATH))
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var loader: ZoneLoader = main.get_node("%ZoneLoader") as ZoneLoader
	var robot: Robot = main.get_node("%Robot") as Robot
	var arrival: Array[Vector3] = []
	var record: Callable = func(_zone_id: Vector2i) -> void:
		arrival.append(loader.get_current_zone().to_local(robot.global_position))
	loader.travel_finished.connect(record)
	if loader.is_travelling():
		await wait_for_signal(loader.travel_finished, TRAVEL_TIMEOUT_S)
	assert_eq(robot.player_uid, PLAYER_UID, "the robot is the player of the file")
	assert_eq(GameManager.get_world_id(), WORLD_ID, "the World of the file")
	assert_eq(GameManager.get_world_seed(), SaveTestSupport.KNOWN_SEED, "with its seed")
	assert_almost_eq(robot.battery.get_current(), 63.5, BATTERY_TOLERANCE, "battery")
	assert_eq(robot.experience.get_total(), 25, "XP")
	assert_eq(robot.inventory.count(&"scrap"), 12, "the scrap stack")
	var stack: ItemStack = robot.inventory.get_slots()[0]
	assert_eq(stack.durability, 40, "with its durability")
	assert_eq(stack.uid, STACK_UID, "and its uid")
	assert_eq(GameManager.get_visit_count(GREEN_ZONE_ID), 2, "visit counter")
	var farm: FarmZone = loader.get_current_zone() as FarmZone
	assert_not_null(farm, "the player's zone is the green zone")
	if farm != null and not arrival.is_empty():
		assert_lt(arrival[0].distance_to(LOCAL_POSITION), POSITION_TOLERANCE, "at its local position")
		assert_eq(farm.get_visit(), 2, "populated for the saved visit")
		var state: Dictionary = farm.get_visit_state()
		var boxes: Array = state["boxes"]
		var dead: Array = state["dead_enemies"]
		assert_eq(boxes.size(), 1, "one opened box")
		assert_eq(dead.size(), 1, "one dead enemy")
		var opened: Dictionary = boxes[0]
		assert_eq(SaveFields.to_int(opened.get("marker"), -1), 0, "on marker 0")
	var dropped: Array[DroppedItem] = (main.get_node("%DroppedItems") as DroppedItemSpawner).get_items()
	assert_eq(dropped.size(), 1, "one dropped item")
	if dropped.size() == 1:
		assert_eq(dropped[0].uid, DROPPED_UID, "the one of the file")
	var structures: BaseStructures = main.get_node("%BaseStructures") as BaseStructures
	assert_eq(structures.structure_at(STATION_CELL), STATION_UID, "the station on its cell")


func test_r_010_54_profile_v1_loads() -> void:
	var document: Dictionary = _document(PROFILE_PATH)
	var version: int = SaveFields.to_int(document.get(SaveMigrations.VERSION_KEY), 0)
	assert_eq(version, 1, "it is a version 1 file")
	var migrated: SaveMigrations.Result = SaveMigrations.migrate_profile(document)
	assert_true(
		migrated.outcome == SaveMigrations.Outcome.CURRENT
		or migrated.outcome == SaveMigrations.Outcome.MIGRATED,
		"it migrates to the current version"
	)
	assert_eq(SaveDocuments.validate_profile(migrated.document), PackedStringArray(), "and validates")
	var profile: ProfileData = SaveDocuments.read_profile(migrated.document)
	assert_eq(profile.player_uuid, PLAYER_UID, "the uuid of the file")
	assert_eq(profile.entitlements.size(), 0, "no entitlements in the MVP")
	assert_eq(profile.hall_of_fame.size(), 0, "no hall of fame in the MVP")
	assert_eq(profile.cosmetics.size(), 0, "no cosmetics in the MVP")
	assert_eq(profile.blueprints.size(), 0, "no blueprints in the MVP")
	var store: MemorySaveStore = SaveTestSupport.reset()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PROFILE_PATH)
	store.put("profile", ISaveStore.Copy.MAIN, bytes)
	var loaded: ActionResult = SaveManager.load_profile()
	assert_true(loaded.ok, "SaveManager loads it")
	assert_eq(SaveManager.get_player_uuid(), PLAYER_UID, "its uuid is the player's")
	assert_eq(store.write_count, 0, "a valid Profile is not rewritten on load")
