extends GutTest
## LocalSaveStore (spec 010, plan §1 "Escritura segura", D5, D6, D7): files,
## encryption, backup copy, safe write and set aside. Covers R-010-01, 15, 18,
## 45, 46, 47, 49, 51, 56 and 64. Every test works in its own folder under
## user://test_saves/, never in user://saves.

const TEST_ROOT: String = "user://test_saves"
const ENCRYPTED_HEADER: String = "GDEC"
const WORLD_ID: String = "0a1b2c"
const OTHER_WORLD_ID: String = "ffeedd"

var _root: String = ""


func before_each() -> void:
	_root = "%s/%s" % [TEST_ROOT, Uid.generate()]
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	_remove_recursive(TEST_ROOT)


# --- R-010-01 ---------------------------------------------------------------

func test_r_010_01_constants() -> void:
	var root: String = LocalSaveStore.DEFAULT_ROOT
	var setting: String = LocalSaveStore.PLAIN_IN_DEBUG_SETTING
	assert_eq(root, "user://saves")
	assert_eq(setting, "cyberscrap/save/plain_json_in_debug")


func test_r_010_01_files_under_root() -> void:
	for encrypt: bool in [true, false]:
		var folder: String = "%s/%s" % [_root, "enc" if encrypt else "plain"]
		DirAccess.make_dir_recursive_absolute(folder)
		var store: LocalSaveStore = LocalSaveStore.new(folder, encrypt)
		assert_true(store.write_profile(_doc("p1")).ok, "profile written")
		assert_true(store.write_profile(_doc("p2")).ok, "profile written again")
		assert_true(store.write_world(WORLD_ID, _doc("w1")).ok, "world written")
		assert_true(store.write_world(WORLD_ID, _doc("w2")).ok, "world written again")
		for file_name: String in ["profile.save", "profile.save.bak", "world_%s.save" % WORLD_ID, "world_%s.save.bak" % WORLD_ID]:
			assert_true(FileAccess.file_exists("%s/%s" % [folder, file_name]), "%s exists (encrypt %s)" % [file_name, encrypt])
		assert_false(FileAccess.file_exists("%s/profile.save.tmp" % folder), "no temporary left")
		assert_false(FileAccess.file_exists("%s/profile.save.bak.tmp" % folder), "no temporary left")


func test_r_010_01_write_then_read_main() -> void:
	for encrypt: bool in [true, false]:
		var store: LocalSaveStore = LocalSaveStore.new(_root, encrypt)
		var profile: PackedByteArray = _doc("profile %s" % encrypt)
		var world: PackedByteArray = _doc("world %s" % encrypt)
		assert_true(store.write_profile(profile).ok)
		assert_true(store.write_world(WORLD_ID, world).ok)
		var profile_read: SaveReadResult = store.read_profile(ISaveStore.Copy.MAIN)
		var world_read: SaveReadResult = store.read_world(WORLD_ID, ISaveStore.Copy.MAIN)
		assert_eq(profile_read.status, SaveReadResult.Status.FOUND)
		assert_eq(profile_read.bytes, profile, "profile bytes (encrypt %s)" % encrypt)
		assert_eq(world_read.status, SaveReadResult.Status.FOUND)
		assert_eq(world_read.bytes, world, "world bytes (encrypt %s)" % encrypt)


func test_r_010_01_missing_files_report_missing() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_eq(store.read_profile(ISaveStore.Copy.MAIN).status, SaveReadResult.Status.MISSING)
	assert_eq(store.read_profile(ISaveStore.Copy.BACKUP).status, SaveReadResult.Status.MISSING)
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.MAIN).status, SaveReadResult.Status.MISSING)
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.BACKUP).status, SaveReadResult.Status.MISSING)


func test_r_010_01_first_write_has_no_backup() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_true(store.write_profile(_doc("first")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("first")).ok)
	assert_eq(store.read_profile(ISaveStore.Copy.BACKUP).status, SaveReadResult.Status.MISSING)
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.BACKUP).status, SaveReadResult.Status.MISSING)


func test_r_010_01_invalid_world_ids_are_rejected() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, false)
	var calls: int = 0
	for bad_id: String in ["../x", "", "a/b"]:
		var write: ActionResult = store.write_world(bad_id, _doc("x"))
		var read: SaveReadResult = store.read_world(bad_id, ISaveStore.Copy.MAIN)
		var delete: ActionResult = store.delete_world(bad_id)
		calls += 3
		assert_false(write.ok, "write rejected: '%s'" % bad_id)
		var key: StringName = write.error_key
		assert_eq(key, ISaveStore.ERR_SAVE_FAILED)
		assert_eq(read.status, SaveReadResult.Status.UNREADABLE, "read: '%s'" % bad_id)
		assert_false(delete.ok, "delete rejected: '%s'" % bad_id)
	assert_push_error_count(calls, "one push_error per rejected call")
	assert_eq(DirAccess.get_files_at(_root).size(), 0, "nothing written in the root")
	assert_eq(DirAccess.get_directories_at(_root).size(), 0, "no folder created from the id")
	assert_eq(DirAccess.get_files_at(TEST_ROOT).size(), 0, "nothing written outside the root")
	assert_eq(DirAccess.get_directories_at(TEST_ROOT).size(), 1, "only the test folder")


# --- R-010-15 ---------------------------------------------------------------

func test_r_010_15_delete_world_keeps_profile() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_true(store.write_profile(_doc("p1")).ok)
	assert_true(store.write_profile(_doc("p2")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("w1")).ok)
	var main_before: PackedByteArray = _raw("profile.save")
	var backup_before: PackedByteArray = _raw("profile.save.bak")
	assert_gt(main_before.size(), 0)
	assert_gt(backup_before.size(), 0)

	assert_true(store.delete_world(WORLD_ID).ok)

	assert_eq(_raw("profile.save"), main_before, "profile untouched")
	assert_eq(_raw("profile.save.bak"), backup_before, "profile backup untouched")


# --- R-010-18 ---------------------------------------------------------------

func test_r_010_18_world_found_by_id() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	var first: PackedByteArray = _doc("first world")
	var second: PackedByteArray = _doc("second world")
	assert_true(store.write_world(OTHER_WORLD_ID, second).ok)
	assert_true(store.write_world(WORLD_ID, first).ok)
	# Backups, temporaries, damaged files and the profile are not worlds.
	assert_true(store.write_world(WORLD_ID, first).ok)
	assert_true(store.write_profile(_doc("profile")).ok)
	_write_raw("world_%s.save.tmp" % WORLD_ID, PackedByteArray([1]))
	_write_raw("world_%s.save.bak.tmp" % WORLD_ID, PackedByteArray([1]))
	_write_raw("world_%s.save.damaged.1" % WORLD_ID, PackedByteArray([1]))
	_write_raw("world_%s.save.bak.damaged.1" % WORLD_ID, PackedByteArray([1]))

	var ids: PackedStringArray = store.list_world_ids()

	assert_eq(ids, PackedStringArray([WORLD_ID, OTHER_WORLD_ID]), "both worlds, sorted")
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.MAIN).bytes, first)
	assert_eq(store.read_world(OTHER_WORLD_ID, ISaveStore.Copy.MAIN).bytes, second)


func test_r_010_18_no_worlds_gives_empty_list() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_true(store.write_profile(_doc("profile")).ok)
	assert_eq(store.list_world_ids().size(), 0)


# --- R-010-45 ---------------------------------------------------------------

func test_r_010_45_failed_write_keeps_files() -> void:
	# Step 1 fails: the temporary name is taken by a non-empty folder.
	var store: LocalSaveStore = LocalSaveStore.new(_root, false)
	var previous: PackedByteArray = _doc("previous")
	var current: PackedByteArray = _doc("current")
	assert_true(store.write_world(WORLD_ID, previous).ok)
	assert_true(store.write_world(WORLD_ID, current).ok)
	var main_before: PackedByteArray = _raw("world_%s.save" % WORLD_ID)
	var backup_before: PackedByteArray = _raw("world_%s.save.bak" % WORLD_ID)
	var tmp_dir: String = "world_%s.save.tmp" % WORLD_ID
	DirAccess.make_dir_recursive_absolute("%s/%s" % [_root, tmp_dir])
	_write_raw("%s/keep" % tmp_dir, PackedByteArray([1]))

	var result: ActionResult = store.write_world(WORLD_ID, _doc("new"))

	assert_false(result.ok, "step 1 fails")
	var key: StringName = result.error_key
	assert_eq(key, ISaveStore.ERR_SAVE_FAILED)
	assert_push_error_count(1, "the failure is explained by one push_error")
	assert_eq(_raw("world_%s.save" % WORLD_ID), main_before, "main unchanged")
	assert_eq(_raw("world_%s.save.bak" % WORLD_ID), backup_before, "backup unchanged")
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.MAIN).bytes, current)


func test_r_010_45_failed_rename_keeps_backup() -> void:
	# Step 3 fails: the main name is a non-empty folder, so the rename cannot replace it.
	var store: LocalSaveStore = LocalSaveStore.new(_root, false)
	assert_true(store.write_world(WORLD_ID, _doc("previous")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("current")).ok)
	var backup_before: PackedByteArray = _raw("world_%s.save.bak" % WORLD_ID)
	var main_name: String = "world_%s.save" % WORLD_ID
	DirAccess.remove_absolute("%s/%s" % [_root, main_name])
	DirAccess.make_dir_recursive_absolute("%s/%s" % [_root, main_name])
	_write_raw("%s/keep" % main_name, PackedByteArray([1]))

	var result: ActionResult = store.write_world(WORLD_ID, _doc("new"))

	assert_false(result.ok, "step 3 fails")
	var key: StringName = result.error_key
	assert_eq(key, ISaveStore.ERR_SAVE_FAILED)
	assert_push_error_count(1, "the failure is explained by one push_error")
	assert_eq(_raw("world_%s.save.bak" % WORLD_ID), backup_before, "backup unchanged")
	assert_true(DirAccess.dir_exists_absolute("%s/%s" % [_root, main_name]), "the folder is still there")
	assert_false(FileAccess.file_exists("%s/%s.tmp" % [_root, main_name]), "temporary removed")
	assert_false(FileAccess.file_exists("%s/%s.bak.tmp" % [_root, main_name]), "temporary removed")


# --- R-010-46 ---------------------------------------------------------------

func test_r_010_46_backup_before_overwrite() -> void:
	for encrypt: bool in [true, false]:
		var store: LocalSaveStore = LocalSaveStore.new(_root, encrypt)
		var first: PackedByteArray = _doc("A %s" % encrypt)
		var second: PackedByteArray = _doc("B %s" % encrypt)
		assert_true(store.write_profile(first).ok)
		assert_true(store.write_profile(second).ok)
		assert_eq(store.read_profile(ISaveStore.Copy.MAIN).bytes, second, "main is B (encrypt %s)" % encrypt)
		assert_eq(store.read_profile(ISaveStore.Copy.BACKUP).bytes, first, "backup is A (encrypt %s)" % encrypt)
		assert_true(store.write_world(WORLD_ID, first).ok)
		assert_true(store.write_world(WORLD_ID, second).ok)
		assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.MAIN).bytes, second)
		assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.BACKUP).bytes, first)


func test_r_010_46_damaged_main_not_kept_as_backup() -> void:
	for encrypt: bool in [true, false]:
		var folder: String = "%s/%s" % [_root, "enc" if encrypt else "plain"]
		DirAccess.make_dir_recursive_absolute(folder)
		var store: LocalSaveStore = LocalSaveStore.new(folder, encrypt)
		var first: PackedByteArray = _doc("A")
		var second: PackedByteArray = _doc("B")
		var third: PackedByteArray = _doc("C")
		assert_true(store.write_profile(first).ok)
		assert_true(store.write_profile(second).ok)
		var main_path: String = "%s/profile.save" % folder
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(main_path)
		if encrypt:
			# Flip a byte of the MD5 area, after the GDEC header: still looks encrypted.
			raw[6] = raw[6] ^ 0xFF
		else:
			raw = "{\"half\": ".to_utf8_buffer()
		var file: FileAccess = FileAccess.open(main_path, FileAccess.WRITE)
		file.store_buffer(raw)
		file.close()

		var result: ActionResult = store.write_profile(third)

		if encrypt:
			assert_engine_error("MD5")
		assert_true(result.ok, "the write still succeeds (encrypt %s)" % encrypt)
		assert_eq(store.read_profile(ISaveStore.Copy.MAIN).bytes, third, "main is C")
		# B was destroyed on disk: the last valid backup (A) stays, the damaged file never replaces it.
		assert_eq(store.read_profile(ISaveStore.Copy.BACKUP).bytes, first, "backup is still A, not the damaged B")


# --- R-010-47 ---------------------------------------------------------------

func test_r_010_47_leftover_temporaries_ignored() -> void:
	for encrypt: bool in [true, false]:
		var sub: String = "enc" if encrypt else "plain"
		var folder: String = "%s/%s" % [_root, sub]
		DirAccess.make_dir_recursive_absolute(folder)
		var store: LocalSaveStore = LocalSaveStore.new(folder, encrypt)
		var valid: PackedByteArray = _doc("valid")
		var fresh: PackedByteArray = _doc("fresh")
		assert_true(store.write_world(WORLD_ID, valid).ok)
		var half: PackedByteArray = "{\"half".to_utf8_buffer()
		_write_raw("%s/world_%s.save.tmp" % [sub, WORLD_ID], half)
		_write_raw("%s/world_%s.save.bak.tmp" % [sub, WORLD_ID], half)

		var read: SaveReadResult = store.read_world(WORLD_ID, ISaveStore.Copy.MAIN)
		assert_eq(read.status, SaveReadResult.Status.FOUND, "main still read (encrypt %s)" % encrypt)
		assert_eq(read.bytes, valid)
		assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.BACKUP).status, SaveReadResult.Status.MISSING)

		assert_true(store.write_world(WORLD_ID, fresh).ok, "next write works")
		assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.MAIN).bytes, fresh, "main has the new bytes")
		assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.BACKUP).bytes, valid, "backup is the previous main")


# --- R-010-49 ---------------------------------------------------------------

func test_r_010_49_set_aside_keeps_files() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_true(store.write_world(WORLD_ID, _doc("A")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("B")).ok)
	var main_name: String = "world_%s.save" % WORLD_ID
	var main_bytes: PackedByteArray = _raw(main_name)
	var backup_bytes: PackedByteArray = _raw(main_name + ".bak")

	assert_true(store.set_aside_world(WORLD_ID).ok)

	assert_false(FileAccess.file_exists("%s/%s" % [_root, main_name]), "main moved")
	assert_false(FileAccess.file_exists("%s/%s.bak" % [_root, main_name]), "backup moved")
	assert_eq(_raw(main_name + ".damaged.1"), main_bytes, "main kept, same bytes")
	assert_eq(_raw(main_name + ".bak.damaged.1"), backup_bytes, "backup kept, same bytes")
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.MAIN).status, SaveReadResult.Status.MISSING)
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.BACKUP).status, SaveReadResult.Status.MISSING)

	# A second set aside never overwrites the first.
	assert_true(store.write_world(WORLD_ID, _doc("C")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("D")).ok)
	assert_true(store.set_aside_world(WORLD_ID).ok)
	assert_true(FileAccess.file_exists("%s/%s.damaged.2" % [_root, main_name]), "second main aside")
	assert_true(FileAccess.file_exists("%s/%s.bak.damaged.2" % [_root, main_name]), "second backup aside")
	assert_eq(_raw(main_name + ".damaged.1"), main_bytes, "first one untouched")


func test_r_010_49_set_aside_profile_keeps_files() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, false)
	assert_true(store.write_profile(_doc("A")).ok)
	assert_true(store.write_profile(_doc("B")).ok)
	var main_bytes: PackedByteArray = _raw("profile.save")
	var backup_bytes: PackedByteArray = _raw("profile.save.bak")

	assert_true(store.set_aside_profile().ok)

	assert_false(FileAccess.file_exists("%s/profile.save" % _root))
	assert_false(FileAccess.file_exists("%s/profile.save.bak" % _root))
	assert_eq(_raw("profile.save.damaged.1"), main_bytes)
	assert_eq(_raw("profile.save.bak.damaged.1"), backup_bytes)
	assert_eq(store.read_profile(ISaveStore.Copy.MAIN).status, SaveReadResult.Status.MISSING)
	assert_eq(store.read_profile(ISaveStore.Copy.BACKUP).status, SaveReadResult.Status.MISSING)

	assert_true(store.write_profile(_doc("C")).ok)
	assert_true(store.write_profile(_doc("D")).ok)
	assert_true(store.set_aside_profile().ok)
	assert_true(FileAccess.file_exists("%s/profile.save.damaged.2" % _root))
	assert_true(FileAccess.file_exists("%s/profile.save.bak.damaged.2" % _root))


# --- R-010-51 ---------------------------------------------------------------

func test_r_010_51_delete_removes_backup() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_true(store.write_world(WORLD_ID, _doc("A")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("B")).ok)
	assert_true(store.write_world(OTHER_WORLD_ID, _doc("other")).ok)
	var main_name: String = "world_%s.save" % WORLD_ID
	_write_raw(main_name + ".tmp", PackedByteArray([1]))
	_write_raw(main_name + ".bak.tmp", PackedByteArray([1]))

	var result: ActionResult = store.delete_world(WORLD_ID)

	assert_true(result.ok)
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		assert_false(FileAccess.file_exists("%s/%s%s" % [_root, main_name, suffix]), "'%s' removed" % suffix)
	assert_eq(store.read_world(WORLD_ID, ISaveStore.Copy.MAIN).status, SaveReadResult.Status.MISSING)
	assert_eq(store.read_world(OTHER_WORLD_ID, ISaveStore.Copy.MAIN).status, SaveReadResult.Status.FOUND, "other world kept")


func test_r_010_51_delete_missing_world_is_ok() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_true(store.delete_world(WORLD_ID).ok, "nothing to delete is not a failure")


# --- R-010-56 ---------------------------------------------------------------

func test_r_010_56_files_not_readable_as_json() -> void:
	var store: LocalSaveStore = LocalSaveStore.new(_root, true)
	assert_true(store.write_profile(_doc("p1")).ok)
	assert_true(store.write_profile(_doc("p2")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("w1")).ok)
	assert_true(store.write_world(WORLD_ID, _doc("w2")).ok)
	for file_name: String in ["profile.save", "profile.save.bak", "world_%s.save" % WORLD_ID, "world_%s.save.bak" % WORLD_ID]:
		var raw: PackedByteArray = _raw(file_name)
		var header: String = raw.slice(0, 4).get_string_from_ascii()
		assert_eq(header, ENCRYPTED_HEADER, "%s starts with GDEC" % file_name)
		assert_true(SaveCodec.decode(raw) == null, "%s is not JSON" % file_name)
		var json: JSON = JSON.new()
		assert_ne(json.parse(raw.get_string_from_utf8()), OK, "%s does not parse" % file_name)


# --- R-010-64 ---------------------------------------------------------------

func test_r_010_64_release_always_encrypts() -> void:
	assert_true(LocalSaveStore.should_encrypt(false, false), "release, plain not requested")
	assert_true(LocalSaveStore.should_encrypt(false, true), "release ignores the setting")
	assert_true(LocalSaveStore.should_encrypt(true, false), "debug, plain not requested")
	assert_false(LocalSaveStore.should_encrypt(true, true), "debug with the setting writes plain")


func test_r_010_64_plain_in_debug() -> void:
	var plain_store: LocalSaveStore = LocalSaveStore.new(_root, false)
	var bytes: PackedByteArray = _doc("plain")
	assert_true(plain_store.write_profile(bytes).ok)
	var raw: PackedByteArray = _raw("profile.save")
	assert_eq(raw, bytes, "plain store writes the JSON bytes as they are")
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	assert_true(parsed is Dictionary, "readable as text")
	assert_eq(plain_store.read_profile(ISaveStore.Copy.MAIN).bytes, bytes)


func test_r_010_64_plain_store_reads_encrypted_file() -> void:
	var encrypting: LocalSaveStore = LocalSaveStore.new(_root, true)
	var bytes: PackedByteArray = _doc("secret")
	assert_true(encrypting.write_profile(bytes).ok)

	var plain_store: LocalSaveStore = LocalSaveStore.new(_root, false)
	var read: SaveReadResult = plain_store.read_profile(ISaveStore.Copy.MAIN)

	assert_eq(read.status, SaveReadResult.Status.FOUND)
	assert_eq(read.bytes, bytes, "a GDEC file is decrypted whatever the mode")


func test_r_010_64_encrypting_store_rejects_plain_file() -> void:
	var plain_store: LocalSaveStore = LocalSaveStore.new(_root, false)
	assert_true(plain_store.write_profile(_doc("plain")).ok)

	var encrypting: LocalSaveStore = LocalSaveStore.new(_root, true)
	var read: SaveReadResult = encrypting.read_profile(ISaveStore.Copy.MAIN)

	# No engine error is expected: the header is checked before decrypting (D5, D6).
	assert_eq(read.status, SaveReadResult.Status.UNREADABLE)
	assert_eq(read.bytes.size(), 0)


# --- helpers ----------------------------------------------------------------

func _doc(label: String) -> PackedByteArray:
	return SaveCodec.encode({"label": label})


## Raw bytes on disk of a file relative to the test root (empty when absent).
func _raw(relative_path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes("%s/%s" % [_root, relative_path])


func _write_raw(relative_path: String, bytes: PackedByteArray) -> void:
	var path: String = "%s/%s" % [_root, relative_path]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _remove_recursive(path: String) -> void:
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file_name])
	for dir_name: String in DirAccess.get_directories_at(path):
		_remove_recursive("%s/%s" % [path, dir_name])
	DirAccess.remove_absolute(path)
