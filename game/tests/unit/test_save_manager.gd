extends GutTest
## Spec 010, task T-010-07: the SaveManager autoload (Profile and World in a
## store, grouped saves, holds, close and background). Covers R-010-02, 03, 04,
## 13, 14, 17, 18, 40, 41, 43, 44, 45, 48, 49, 50, 53, 55, 57 and 65.
## Every test runs on a MemorySaveStore; no file or real time is involved.

const WORLD_ID := "w1"
const OTHER_SEED := 987654321012

var _store: MemorySaveStore
var _quit_writes: Array[int] = []


func before_each() -> void:
	_quit_writes.clear()
	_store = SaveTestSupport.reset()


func after_each() -> void:
	SaveTestSupport.reset()
	GameManager.begin_world(Uid.generate(), "", 20261115, DataRegistry.get_ruleset(&"normal"))


func _record_quit() -> void:
	_quit_writes.append(_store.write_count)


## A valid World document of schema version 1, ruleset "normal".
func _world_doc(world_id: String, world_seed: int, visit: int) -> Dictionary:
	var header: SaveDocuments.WorldHeader = SaveDocuments.WorldHeader.new()
	header.world_id = world_id
	header.world_seed = world_seed
	header.ruleset_id = &"normal"
	header.saved_at_unix = 1
	var players: Dictionary[String, Dictionary] = {}
	var world: Dictionary[String, Dictionary] = {}
	world["zone_visits"] = {"zones": [{"zone_id": [0, 0], "visit": visit}]}
	return SaveDocuments.build_world(header, players, world)


func _put_world(
	document: Dictionary, copy: ISaveStore.Copy = ISaveStore.Copy.MAIN, world_id: String = WORLD_ID
) -> void:
	_store.put("world_" + world_id, copy, SaveCodec.encode(document))


func _profile_doc(uuid: String) -> Dictionary:
	var profile: ProfileData = ProfileData.new()
	profile.player_uuid = uuid
	return SaveDocuments.build_profile(profile)


func _world_bytes(copy: ISaveStore.Copy = ISaveStore.Copy.MAIN) -> PackedByteArray:
	return _store.get_bytes("world_" + GameManager.get_world_id(), copy)


func _decode(bytes: PackedByteArray) -> Dictionary:
	var decoded: Variant = SaveCodec.decode(bytes)
	assert_true(decoded is Dictionary, "the store holds plain JSON")
	var document: Dictionary = {}
	if decoded is Dictionary:
		document = decoded
	return document


func _base_zone_id() -> Vector2i:
	return DataRegistry.get_base_zone().zone_id


# --- R-010-02, R-010-03, R-010-50 (code shape) ---


func test_r_010_02_public_methods() -> void:
	for method: String in ["save_game", "load_game", "delete_save", "save_profile", "load_profile"]:
		assert_true(SaveManager.has_method(method), "SaveManager has %s" % method)


func test_r_010_02_only_save_manager_uses_a_store() -> void:
	var offenders: PackedStringArray = _scripts_containing(["LocalSaveStore", "ISaveStore", "use_store("])
	assert_eq(offenders.size(), 0, "only SaveManager and the services touch a save store: %s" % offenders)


func test_r_010_50_backup_is_named_only_by_save_manager() -> void:
	var offenders: PackedStringArray = _scripts_containing(["Copy.BACKUP"])
	assert_eq(offenders.size(), 0, "nothing else reads the BACKUP: %s" % offenders)


func test_r_010_03_variable_whitelist() -> void:
	var script: GDScript = SaveManager.get_script()
	var variables: PackedStringArray = PackedStringArray()
	for property: Dictionary in script.get_script_property_list():
		var usage: int = property["usage"]
		var property_name: String = property["name"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			variables.append(property_name)
	variables.sort()
	var expected: PackedStringArray = PackedStringArray([
		"quit_action", "_store", "_profile", "_has_world", "_blocked", "_holds", "_pending",
		"_flush_queued", "_quit_pending", "_world_version", "_world_steps",
	])
	expected.sort()
	assert_eq(Array(variables), Array(expected), "SaveManager keeps no player state in variables")


## .gd files under res://scenes and res://scripts, except SaveManager and the
## services, that contain any of the needles.
func _scripts_containing(needles: Array[String]) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for root: String in ["res://scenes", "res://scripts"]:
		for path: String in _gd_files(root):
			if path == "res://scripts/autoload/save_manager.gd" or path.begins_with("res://scripts/services/"):
				continue
			var text: String = FileAccess.get_file_as_string(path)
			for needle: String in needles:
				if text.contains(needle):
					found.append("%s (%s)" % [path, needle])
	return found


func _gd_files(directory: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return files
	for sub: String in dir.get_directories():
		files.append_array(_gd_files(directory.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			files.append(directory.path_join(file))
	return files


# --- Profile: R-010-13, R-010-14, R-010-48, R-010-49, R-010-55 ---


func test_r_010_14_uuid_empty_before_load() -> void:
	assert_eq(SaveManager.get_player_uuid(), "", "no uuid before load_profile")


func test_r_010_13_first_start_creates_and_writes_the_profile() -> void:
	var result: ActionResult = SaveManager.load_profile()
	assert_true(result.ok, "a missing profile is created")
	assert_ne(SaveManager.get_player_uuid(), "", "with a uuid")
	assert_eq(_store.write_count, 1, "written at once")
	var document: Dictionary = _decode(_store.get_bytes("profile", ISaveStore.Copy.MAIN))
	var uuid: String = document.get(SaveDocuments.KEY_PLAYER_UUID, "")
	assert_eq(uuid, SaveManager.get_player_uuid(), "the stored uuid is the one in memory")


func test_r_010_14_uuid_is_stable_across_loads() -> void:
	SaveManager.load_profile()
	var first: String = SaveManager.get_player_uuid()
	var result: ActionResult = SaveManager.load_profile()
	assert_true(result.ok)
	assert_eq(SaveManager.get_player_uuid(), first, "the same profile is read again")


func test_r_010_14_get_profile_is_a_copy() -> void:
	SaveManager.load_profile()
	var first: String = SaveManager.get_player_uuid()
	var copy: ProfileData = SaveManager.get_profile()
	copy.player_uuid = "changed"
	assert_eq(SaveManager.get_player_uuid(), first, "editing the copy changes nothing")


func test_r_010_14_loads_a_stored_profile() -> void:
	_store.put("profile", ISaveStore.Copy.MAIN, SaveCodec.encode(_profile_doc("stored-uuid")))
	var result: ActionResult = SaveManager.load_profile()
	assert_true(result.ok)
	assert_eq(SaveManager.get_player_uuid(), "stored-uuid")
	assert_eq(_store.write_count, 0, "an existing profile is not rewritten")


func test_r_010_48_profile_backup_replaces_a_damaged_main() -> void:
	_store.put("profile", ISaveStore.Copy.MAIN, "{broken".to_utf8_buffer())
	_store.put("profile", ISaveStore.Copy.BACKUP, SaveCodec.encode(_profile_doc("from-backup")))
	var result: ActionResult = SaveManager.load_profile()
	assert_true(result.ok)
	assert_eq(SaveManager.get_player_uuid(), "from-backup")
	assert_push_error_count(1)


func test_r_010_49_profile_both_damaged_is_set_aside() -> void:
	_store.put("profile", ISaveStore.Copy.MAIN, "{broken".to_utf8_buffer())
	_store.put("profile", ISaveStore.Copy.BACKUP, "also broken".to_utf8_buffer())
	watch_signals(SaveManager)
	var result: ActionResult = SaveManager.load_profile()
	assert_true(result.ok, "a new profile is started")
	assert_eq(_store.get_set_aside("profile").size(), 1, "the damaged files are kept")
	assert_ne(SaveManager.get_player_uuid(), "")
	assert_signal_emitted_with_parameters(SaveManager, "save_notice", [SaveManager.MSG_PROFILE_DAMAGED])
	assert_push_error_count(1)


## Review of spec 010: a damaged file that cannot be set aside is never
## written over; the session goes on with a new one in memory.
func test_r_010_49_profile_not_set_aside_is_not_overwritten() -> void:
	var broken: PackedByteArray = "{broken".to_utf8_buffer()
	_store.put("profile", ISaveStore.Copy.MAIN, broken)
	_store.put("profile", ISaveStore.Copy.BACKUP, "also broken".to_utf8_buffer())
	_store.fail_set_aside = true
	watch_signals(SaveManager)
	var result: ActionResult = SaveManager.load_profile()
	assert_false(result.ok, "reported as a failure")
	assert_eq(result.error_key, SaveManager.ERR_SAVE_FAILED)
	assert_eq(_store.get_bytes("profile", ISaveStore.Copy.MAIN), broken, "the damaged file stays")
	assert_eq(_store.write_count, 0, "nothing written")
	assert_ne(SaveManager.get_player_uuid(), "", "a Profile in memory")
	assert_signal_emitted_with_parameters(SaveManager, "save_notice", [SaveManager.ERR_SAVE_FAILED])
	assert_push_error_count(1)


func test_r_010_49_world_not_set_aside_is_not_overwritten() -> void:
	var broken: PackedByteArray = "{broken".to_utf8_buffer()
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.MAIN, broken)
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.BACKUP, "also broken".to_utf8_buffer())
	SaveManager.load_profile()
	var writes: int = _store.write_count
	_store.fail_set_aside = true
	watch_signals(SaveManager)
	var result: ActionResult = SaveManager.load_game()
	assert_false(result.ok, "reported as a failure")
	assert_eq(result.error_key, SaveManager.ERR_SAVE_FAILED)
	assert_eq(_store.get_bytes("world_" + WORLD_ID, ISaveStore.Copy.MAIN), broken, "the damaged file stays")
	assert_eq(_store.write_count, writes, "nothing written")
	assert_false(SaveManager.has_world(), "nothing will be saved this session")
	assert_ne(GameManager.get_world_id(), WORLD_ID, "a new World in memory")
	assert_not_null(GameManager.get_ruleset(), "with a ruleset to play")
	assert_signal_emitted_with_parameters(SaveManager, "save_notice", [SaveManager.ERR_SAVE_FAILED])
	assert_push_error_count(1)


## Review of spec 010: a header naming another World would save to a second file.
func test_r_010_18_header_of_another_world_is_not_valid() -> void:
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.MAIN, SaveCodec.encode(_world_doc("w2", OTHER_SEED, 1)))
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.BACKUP, SaveCodec.encode(_world_doc(WORLD_ID, OTHER_SEED, 1)))
	SaveManager.load_profile()
	var result: ActionResult = SaveManager.load_game()
	assert_true(result.ok, "the backup loads")
	assert_eq(GameManager.get_world_id(), WORLD_ID, "the World of the file")
	assert_push_error_count(1)


func test_r_010_55_newer_profile_blocks_and_is_not_written() -> void:
	var document: Dictionary = _profile_doc("future")
	document[SaveMigrations.VERSION_KEY] = SaveMigrations.PROFILE_VERSION + 1
	var bytes: PackedByteArray = SaveCodec.encode(document)
	_store.put("profile", ISaveStore.Copy.MAIN, bytes)
	var result: ActionResult = SaveManager.load_profile()
	assert_false(result.ok)
	assert_eq(result.error_key, SaveManager.MSG_SAVE_NEWER_VERSION)
	assert_eq(_store.write_count, 0, "nothing written")
	assert_eq(_store.get_bytes("profile", ISaveStore.Copy.MAIN), bytes, "bytes unchanged")
	assert_push_error_count(1)


func test_r_010_55_newer_profile_refuses_later_saves() -> void:
	var document: Dictionary = _profile_doc("future")
	document[SaveMigrations.VERSION_KEY] = SaveMigrations.PROFILE_VERSION + 1
	var bytes: PackedByteArray = SaveCodec.encode(document)
	_store.put("profile", ISaveStore.Copy.MAIN, bytes)
	SaveManager.load_profile()
	var result: ActionResult = SaveManager.save_game(SaveManager.REASON_CLOSE)
	assert_false(result.ok, "no save while the profile is blocked")
	assert_eq(_store.write_count, 0)
	assert_eq(_store.get_bytes("profile", ISaveStore.Copy.MAIN), bytes, "bytes unchanged")
	assert_push_error_count(2)


# --- World: load, create, R-010-18, R-010-48, R-010-49, R-010-55, R-010-53 ---


func test_r_010_18_loads_the_only_world() -> void:
	_put_world(_world_doc(WORLD_ID, OTHER_SEED, 1))
	SaveManager.load_profile()
	var result: ActionResult = SaveManager.load_game()
	assert_true(result.ok)
	assert_eq(GameManager.get_world_id(), WORLD_ID)
	assert_eq(GameManager.get_world_seed(), OTHER_SEED)
	assert_same(GameManager.get_ruleset(), DataRegistry.get_ruleset(&"normal"))
	assert_true(SaveManager.has_world())


func test_r_010_18_no_world_creates_one_with_a_random_seed() -> void:
	SaveManager.load_profile()
	var result: ActionResult = SaveManager.load_game()
	assert_true(result.ok)
	assert_true(SaveManager.has_world())
	assert_eq(_store.list_world_ids().size(), 1, "the new World is on the store")
	assert_eq(_store.list_world_ids()[0], GameManager.get_world_id())


func test_r_010_53_before_any_owner_reads() -> void:
	_put_world(_world_doc(WORLD_ID, OTHER_SEED, 1))
	var step: Callable = func(document: Dictionary) -> Dictionary:
		var world: Dictionary = document["world"]
		var part: Dictionary = world["zone_visits"]
		var zones: Array = part["zones"]
		var zone: Dictionary = zones[0]
		zone["visit"] = 5
		return document
	var steps: Array[Callable] = [step]
	SaveManager.use_world_migrations(2, steps)
	SaveManager.load_profile()
	var result: ActionResult = SaveManager.load_game()
	assert_true(result.ok)
	assert_eq(GameManager.get_visit_count(Vector2i(0, 0)), 5, "the owner reads the migrated document")


func test_r_010_48_world_backup_replaces_unreadable_main() -> void:
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.MAIN, PackedByteArray([0xff, 0xfe, 0x00, 0x80]))
	_assert_backup_world_loads()


func test_r_010_48_world_backup_replaces_broken_json_main() -> void:
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.MAIN, "{\"a\": ".to_utf8_buffer())
	_assert_backup_world_loads()


func test_r_010_48_world_backup_replaces_invalid_document_main() -> void:
	_put_world({SaveMigrations.VERSION_KEY: 1})
	_assert_backup_world_loads()


func _assert_backup_world_loads() -> void:
	_put_world(_world_doc(WORLD_ID, OTHER_SEED, 3), ISaveStore.Copy.BACKUP)
	SaveManager.load_profile()
	var result: ActionResult = SaveManager.load_game()
	assert_true(result.ok, "the backup is loaded")
	assert_eq(GameManager.get_world_seed(), OTHER_SEED)
	assert_eq(GameManager.get_visit_count(Vector2i(0, 0)), 3)
	assert_push_error_count(1)


func test_r_010_49_world_both_damaged_starts_a_new_world() -> void:
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.MAIN, "{broken".to_utf8_buffer())
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.BACKUP, "also broken".to_utf8_buffer())
	SaveManager.load_profile()
	watch_signals(SaveManager)
	var result: ActionResult = SaveManager.load_game()
	assert_true(result.ok, "a new World is started")
	assert_eq(_store.get_set_aside("world_" + WORLD_ID).size(), 1, "the damaged files are kept")
	assert_ne(GameManager.get_world_id(), WORLD_ID, "a new World, not the damaged one")
	assert_true(SaveManager.has_world())
	assert_signal_emitted_with_parameters(SaveManager, "save_notice", [SaveManager.MSG_WORLD_DAMAGED])
	assert_push_error_count(1)


func test_r_010_55_newer_world_is_not_loaded_nor_overwritten() -> void:
	var document: Dictionary = _world_doc(WORLD_ID, OTHER_SEED, 1)
	document[SaveMigrations.VERSION_KEY] = SaveMigrations.WORLD_VERSION + 1
	var bytes: PackedByteArray = SaveCodec.encode(document)
	_store.put("world_" + WORLD_ID, ISaveStore.Copy.MAIN, bytes)
	SaveManager.load_profile()
	var writes: int = _store.write_count
	var result: ActionResult = SaveManager.load_game()
	assert_false(result.ok)
	assert_eq(result.error_key, SaveManager.MSG_SAVE_NEWER_VERSION)
	assert_false(SaveManager.has_world(), "no game starts")
	var later: ActionResult = SaveManager.save_game(SaveManager.REASON_CLOSE)
	assert_false(later.ok, "and nothing can save over it")
	assert_eq(_store.write_count, writes, "nothing written")
	assert_eq(_store.get_bytes("world_" + WORLD_ID, ISaveStore.Copy.MAIN), bytes, "bytes unchanged")
	assert_push_error_count(2)


func test_r_010_50_valid_main_never_reads_the_backup() -> void:
	_store.put("profile", ISaveStore.Copy.MAIN, SaveCodec.encode(_profile_doc("p")))
	_put_world(_world_doc(WORLD_ID, OTHER_SEED, 1))
	SaveManager.load_profile()
	SaveManager.load_game()
	assert_true(_store.reads.size() > 0, "something was read")
	for read: String in _store.reads:
		assert_false(read.ends_with(":BACKUP"), "read %s" % read)


func test_r_010_43_holds_reset_by_use_store() -> void:
	SaveManager.hold_saves(&"stale")
	_store = SaveTestSupport.start_world()
	await _assert_request_saves_after_frames()


func test_r_010_43_holds_reset_by_load_game() -> void:
	_store = SaveTestSupport.start_world()
	SaveManager.hold_saves(&"stale")
	SaveManager.load_game()
	await _assert_request_saves_after_frames()


func test_r_010_43_holds_reset_by_create_world() -> void:
	_store = SaveTestSupport.start_world()
	SaveManager.hold_saves(&"stale")
	SaveManager.create_world(OTHER_SEED)
	await _assert_request_saves_after_frames()


func _assert_request_saves_after_frames() -> void:
	watch_signals(EventBus)
	SaveManager.request_save(&"after_reset")
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [&"after_reset"])


# --- create_world, save_game: R-010-04, R-010-17, R-010-45, R-010-57 ---


func test_r_010_18_create_world_sets_game_manager_and_writes() -> void:
	SaveManager.load_profile()
	watch_signals(EventBus)
	var result: ActionResult = SaveManager.create_world(OTHER_SEED)
	assert_true(result.ok)
	assert_true(SaveManager.has_world())
	assert_eq(GameManager.get_world_seed(), OTHER_SEED)
	assert_ne(GameManager.get_world_id(), "")
	assert_same(GameManager.get_ruleset(), DataRegistry.get_catalog().new_world_ruleset)
	assert_true(_store.has_copy("world_" + GameManager.get_world_id(), ISaveStore.Copy.MAIN), "written at once")
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SaveManager.REASON_NEW_WORLD])


func test_r_010_57_store_receives_plain_json() -> void:
	_store = SaveTestSupport.start_world()
	var profile: Dictionary = _decode(_store.get_bytes("profile", ISaveStore.Copy.MAIN))
	assert_true(profile.has(SaveDocuments.KEY_PLAYER_UUID))
	var world: Dictionary = _decode(_world_bytes())
	assert_true(world.has(SaveDocuments.KEY_WORLD_ID))
	var seed_text: String = world.get(SaveDocuments.KEY_SEED, "")
	assert_eq(seed_text, str(SaveTestSupport.KNOWN_SEED), "the seed goes as text")


func test_r_010_17_save_game_writes_now_and_announces() -> void:
	_store = SaveTestSupport.start_world()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	var before: int = int(Time.get_unix_time_from_system())
	var result: ActionResult = SaveManager.save_game(SaveManager.REASON_RECHARGED)
	var after: int = int(Time.get_unix_time_from_system())
	assert_true(result.ok)
	assert_eq(_store.write_count, writes + 1, "written during the call")
	assert_signal_emit_count(EventBus, "game_saved", 1)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SaveManager.REASON_RECHARGED])
	var document: Dictionary = _decode(_world_bytes())
	var saved_at: int = SaveFields.to_int(document.get(SaveDocuments.KEY_SAVED_AT), -1)
	assert_between(saved_at, before, after, "saved_at is the clock of the save")


func test_r_010_04_save_game_without_world_is_an_error() -> void:
	SaveManager.load_profile()
	watch_signals(EventBus)
	var result: ActionResult = SaveManager.save_game(SaveManager.REASON_CLOSE)
	assert_false(result.ok)
	assert_eq(result.error_key, SaveManager.ERR_SAVE_FAILED)
	assert_signal_not_emitted(EventBus, "game_saved")
	assert_push_error_count(1)


func test_r_010_45_failed_write_keeps_the_store_and_tells_the_player() -> void:
	_store = SaveTestSupport.start_world()
	SaveManager.save_game(SaveManager.REASON_CLOSE)
	var main_bytes: PackedByteArray = _world_bytes()
	var backup_bytes: PackedByteArray = _world_bytes(ISaveStore.Copy.BACKUP)
	_store.fail_writes = true
	watch_signals(EventBus)
	watch_signals(SaveManager)
	var result: ActionResult = SaveManager.save_game(SaveManager.REASON_DIED)
	assert_false(result.ok)
	assert_eq(result.error_key, SaveManager.ERR_SAVE_FAILED)
	assert_signal_emitted_with_parameters(SaveManager, "save_notice", [SaveManager.ERR_SAVE_FAILED])
	assert_signal_not_emitted(EventBus, "game_saved")
	assert_eq(_world_bytes(), main_bytes, "MAIN unchanged")
	assert_eq(_world_bytes(ISaveStore.Copy.BACKUP), backup_bytes, "BACKUP unchanged")
	assert_push_error_count(1)


# --- Grouped requests and holds: R-010-44, R-010-43 ---


func test_r_010_44_request_save_acts_at_the_end_of_the_frame() -> void:
	_store = SaveTestSupport.start_world()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	SaveManager.request_save(SaveManager.REASON_RECHARGED)
	assert_eq(_store.write_count, writes, "never acts during the call")
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes + 1)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SaveManager.REASON_RECHARGED])


func test_r_010_44_several_requests_in_a_frame_make_one_save() -> void:
	_store = SaveTestSupport.start_world()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	SaveManager.request_save(SaveManager.REASON_DIED)
	SaveManager.request_save(SaveManager.REASON_ENTERED_BASE)
	SaveManager.request_save(SaveManager.REASON_RECHARGED)
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes + 1, "one save")
	assert_signal_emit_count(EventBus, "game_saved", 1)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SaveManager.REASON_DIED])


func test_r_010_44_request_without_world_is_ignored() -> void:
	SaveManager.load_profile()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	SaveManager.request_save(SaveManager.REASON_RECHARGED)
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes)
	assert_signal_not_emitted(EventBus, "game_saved")


func test_r_010_43_hold_defers_the_request_until_released() -> void:
	_store = SaveTestSupport.start_world()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	SaveManager.hold_saves(&"build")
	SaveManager.request_save(SaveManager.REASON_STRUCTURE_BUILT)
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes, "nothing while held")
	SaveManager.release_saves(&"build")
	assert_eq(_store.write_count, writes, "release does not act during the call")
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes + 1)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SaveManager.REASON_STRUCTURE_BUILT])


func test_r_010_43_saves_wait_for_the_last_hold() -> void:
	_store = SaveTestSupport.start_world()
	var writes: int = _store.write_count
	SaveManager.hold_saves(&"a")
	SaveManager.hold_saves(&"b")
	SaveManager.request_save(SaveManager.REASON_RECHARGED)
	SaveManager.release_saves(&"a")
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes, "one hold is still active")
	SaveManager.release_saves(&"b")
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes + 1)


# --- EventBus triggers ---


func test_r_010_44_entering_the_base_requests_a_save() -> void:
	await _assert_event_saves(
		func() -> void: EventBus.zone_changed.emit(_base_zone_id()), SaveManager.REASON_ENTERED_BASE
	)


func test_r_010_44_changing_to_another_zone_saves_nothing() -> void:
	_store = SaveTestSupport.start_world()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	EventBus.zone_changed.emit(_base_zone_id() + Vector2i(1, 0))
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes)
	assert_signal_not_emitted(EventBus, "game_saved")


func test_r_010_44_recharge_requests_a_save() -> void:
	await _assert_event_saves(func() -> void: EventBus.player_recharged.emit("p"), SaveManager.REASON_RECHARGED)


func test_r_010_44_death_requests_a_save() -> void:
	await _assert_event_saves(func() -> void: EventBus.player_died.emit("p"), SaveManager.REASON_DIED)


func test_r_010_44_building_requests_a_save() -> void:
	await _assert_event_saves(
		func() -> void: EventBus.structure_built.emit("s"), SaveManager.REASON_STRUCTURE_BUILT
	)


func test_r_010_44_moving_requests_a_save() -> void:
	await _assert_event_saves(
		func() -> void: EventBus.structure_moved.emit("s"), SaveManager.REASON_STRUCTURE_MOVED
	)


func _assert_event_saves(trigger: Callable, reason: StringName) -> void:
	_store = SaveTestSupport.start_world()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	trigger.call()
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes + 1, "one save for %s" % reason)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [reason])


# --- Close and background: R-010-40, R-010-41 ---


func test_r_010_40_close_without_world_quits_at_once() -> void:
	SaveManager.load_profile()
	SaveManager.quit_action = _record_quit
	var writes: int = _store.write_count
	SaveManager.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_quit_writes, [writes], "quit, with nothing saved")


func test_r_010_40_close_saves_then_quits() -> void:
	_store = SaveTestSupport.start_world()
	SaveManager.quit_action = _record_quit
	watch_signals(EventBus)
	var writes: int = _store.write_count
	SaveManager.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_quit_writes, [writes + 1], "quit after the save")
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SaveManager.REASON_CLOSE])


func test_r_010_40_close_waits_for_holds() -> void:
	_store = SaveTestSupport.start_world()
	SaveManager.quit_action = _record_quit
	var writes: int = _store.write_count
	SaveManager.hold_saves(&"build")
	SaveManager.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await wait_process_frames(2)
	assert_eq(_store.write_count, writes, "no save while held")
	assert_eq(_quit_writes.size(), 0, "no quit while held")
	SaveManager.release_saves(&"build")
	await wait_process_frames(2)
	assert_eq(_quit_writes, [writes + 1], "saved, then quit")


func test_r_010_41_background_saves_at_once() -> void:
	_store = SaveTestSupport.start_world()
	watch_signals(EventBus)
	var writes: int = _store.write_count
	SaveManager.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(_store.write_count, writes + 1, "no frame wait")
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SaveManager.REASON_BACKGROUND])


# --- delete_save: R-010-65 ---


func test_r_010_65_delete_save() -> void:
	_store = SaveTestSupport.start_world()
	SaveManager.save_game(SaveManager.REASON_CLOSE)
	SaveManager.save_profile()
	var file: String = "world_" + GameManager.get_world_id()
	assert_true(_store.has_copy(file, ISaveStore.Copy.BACKUP), "the world has a backup to delete")
	var profile_main: PackedByteArray = _store.get_bytes("profile", ISaveStore.Copy.MAIN)
	var profile_backup: PackedByteArray = _store.get_bytes("profile", ISaveStore.Copy.BACKUP)
	var result: ActionResult = SaveManager.delete_save()
	assert_true(result.ok)
	assert_false(_store.has_copy(file, ISaveStore.Copy.MAIN), "world deleted")
	assert_false(_store.has_copy(file, ISaveStore.Copy.BACKUP), "and its backup")
	assert_false(SaveManager.has_world())
	assert_eq(_store.get_bytes("profile", ISaveStore.Copy.MAIN), profile_main, "the profile stays")
	assert_eq(_store.get_bytes("profile", ISaveStore.Copy.BACKUP), profile_backup, "with its backup")
