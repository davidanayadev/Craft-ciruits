extends GutTest
## ISaveStore and SaveReadResult (spec 010, R-010-01): the base class reports an
## error and fails for every method until a store overrides it. Pure code.

const BASE_METHOD_COUNT: int = 8


func test_r_010_01_base_methods_report_errors() -> void:
	var store: ISaveStore = ISaveStore.new()
	var bytes: PackedByteArray = PackedByteArray([1, 2, 3])

	var profile_read: SaveReadResult = store.read_profile(ISaveStore.Copy.MAIN)
	var profile_write: ActionResult = store.write_profile(bytes)
	var profile_aside: ActionResult = store.set_aside_profile()
	var ids: PackedStringArray = store.list_world_ids()
	var world_read: SaveReadResult = store.read_world("abc", ISaveStore.Copy.BACKUP)
	var world_write: ActionResult = store.write_world("abc", bytes)
	var world_aside: ActionResult = store.set_aside_world("abc")
	var world_delete: ActionResult = store.delete_world("abc")

	assert_push_error_count(BASE_METHOD_COUNT, "one push_error per method")
	assert_eq(profile_read.status, SaveReadResult.Status.UNREADABLE, "read_profile")
	assert_eq(world_read.status, SaveReadResult.Status.UNREADABLE, "read_world")
	assert_eq(profile_read.bytes.size(), 0, "no bytes when unreadable")
	assert_eq(world_read.bytes.size(), 0, "no bytes when unreadable")
	assert_eq(ids.size(), 0, "list is empty")
	for result: ActionResult in [profile_write, profile_aside, world_write, world_aside, world_delete]:
		assert_false(result.ok, "fails")
		var key: StringName = result.error_key
		assert_eq(key, ISaveStore.ERR_SAVE_FAILED)


func test_r_010_01_error_key_constant() -> void:
	var key: StringName = ISaveStore.ERR_SAVE_FAILED
	assert_eq(key, &"ERR_SAVE_FAILED")


func test_r_010_01_copy_enum() -> void:
	assert_ne(ISaveStore.Copy.MAIN, ISaveStore.Copy.BACKUP)
	assert_eq(ISaveStore.Copy.keys(), ["MAIN", "BACKUP"])


func test_r_010_01_read_result_enum() -> void:
	assert_eq(SaveReadResult.Status.keys(), ["FOUND", "MISSING", "UNREADABLE"])


func test_r_010_01_read_result_found_keeps_bytes() -> void:
	var bytes: PackedByteArray = PackedByteArray([7, 8, 9])
	var result: SaveReadResult = SaveReadResult.found(bytes)
	assert_eq(result.status, SaveReadResult.Status.FOUND)
	assert_eq(result.bytes, bytes)


func test_r_010_01_read_result_missing_has_no_bytes() -> void:
	var result: SaveReadResult = SaveReadResult.missing()
	assert_eq(result.status, SaveReadResult.Status.MISSING)
	assert_eq(result.bytes.size(), 0)


func test_r_010_01_read_result_unreadable_has_no_bytes() -> void:
	var result: SaveReadResult = SaveReadResult.unreadable()
	assert_eq(result.status, SaveReadResult.Status.UNREADABLE)
	assert_eq(result.bytes.size(), 0)
