class_name LocalSaveStore
extends ISaveStore
## The saves as files under a root folder of user:// (spec 010). It encrypts
## and decrypts (AES-256 with FileAccess file encryption, R-010-56), keeps the
## backup copy and writes so that a cut at any point leaves a readable MAIN or
## a valid BACKUP (plan §1, R-010-47):
##   1. write X.tmp whole and read it back;
##   2. when X is valid, copy it to X.bak.tmp (a damaged X never becomes the backup);
##   3. rename X.tmp to X;
##   4. rename X.bak.tmp to X.bak.
## A failure in 1-3 removes the temporaries and leaves X and X.bak as they were.
## Encryption lives only here (R-010-57): the rest of the game sees plain bytes.

const DEFAULT_ROOT := "user://saves"
## Debug builds may save plain JSON to inspect it (R-010-64); release never does.
const PLAIN_IN_DEBUG_SETTING := "cyberscrap/save/plain_json_in_debug"

const PROFILE_FILE := "profile.save"
const WORLD_PREFIX := "world_"
const SAVE_EXTENSION := ".save"
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"
const DAMAGED_SUFFIX := ".damaged."
## The first bytes FileAccess writes in an encrypted file. Checked before
## decrypting, so a plain file never reaches the decryption (plan D5).
const ENCRYPTED_HEADER := "GDEC"
## Obfuscation, not a secret (spec question 1): it only stops casual edits.
const _PASSWORD := "cyberscrap-local-save-v1"
const _VALID_ID_PATTERN := "^[A-Za-z0-9_-]+$"

var _root: String
var _encrypt: bool


func _init(p_root: String, p_encrypt: bool) -> void:
	_root = p_root
	_encrypt = p_encrypt


## Release builds always encrypt (R-010-64).
static func should_encrypt(is_debug_build: bool, plain_requested: bool) -> bool:
	return not (is_debug_build and plain_requested)


func read_profile(copy: Copy) -> SaveReadResult:
	return _read(_copy_path(_root.path_join(PROFILE_FILE), copy))


func write_profile(bytes: PackedByteArray) -> ActionResult:
	return _write(_root.path_join(PROFILE_FILE), bytes)


func set_aside_profile() -> ActionResult:
	return _set_aside(_root.path_join(PROFILE_FILE))


func list_world_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(_root):
		return ids
	for file: String in DirAccess.get_files_at(_root):
		if not file.begins_with(WORLD_PREFIX) or not file.ends_with(SAVE_EXTENSION):
			continue
		var world_id: String = file.trim_prefix(WORLD_PREFIX).trim_suffix(SAVE_EXTENSION)
		if _is_valid_id(world_id):
			ids.append(world_id)
	ids.sort()
	return ids


func read_world(world_id: String, copy: Copy) -> SaveReadResult:
	if not _check_id(world_id):
		return SaveReadResult.unreadable()
	return _read(_copy_path(_world_path(world_id), copy))


func write_world(world_id: String, bytes: PackedByteArray) -> ActionResult:
	if not _check_id(world_id):
		return ActionResult.failure(ERR_SAVE_FAILED)
	return _write(_world_path(world_id), bytes)


func set_aside_world(world_id: String) -> ActionResult:
	if not _check_id(world_id):
		return ActionResult.failure(ERR_SAVE_FAILED)
	return _set_aside(_world_path(world_id))


func delete_world(world_id: String) -> ActionResult:
	if not _check_id(world_id):
		return ActionResult.failure(ERR_SAVE_FAILED)
	var path: String = _world_path(world_id)
	var deleted: bool = true
	for file: String in [path, path + BACKUP_SUFFIX, path + TEMP_SUFFIX, path + BACKUP_SUFFIX + TEMP_SUFFIX]:
		deleted = _remove_if_present(file) and deleted
	return ActionResult.success() if deleted else ActionResult.failure(ERR_SAVE_FAILED)


func _world_path(world_id: String) -> String:
	return _root.path_join(WORLD_PREFIX + world_id + SAVE_EXTENSION)


static func _copy_path(path: String, copy: Copy) -> String:
	return path + BACKUP_SUFFIX if copy == Copy.BACKUP else path


## A file name, never a path: the id comes from a save that may have been edited.
func _check_id(world_id: String) -> bool:
	if _is_valid_id(world_id):
		return true
	push_error("LocalSaveStore: '%s' is not a valid world id." % world_id)
	return false


static func _is_valid_id(world_id: String) -> bool:
	return RegEx.create_from_string(_VALID_ID_PATTERN).search(world_id) != null


## Reading reports nothing itself: SaveManager decides what a damaged copy means.
func _read(path: String) -> SaveReadResult:
	if not FileAccess.file_exists(path):
		return SaveReadResult.missing()
	if _has_encrypted_header(path):
		var encrypted: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, _PASSWORD)
		if encrypted == null:
			return SaveReadResult.unreadable()
		return SaveReadResult.found(encrypted.get_buffer(encrypted.get_length()))
	if _encrypt:
		return SaveReadResult.unreadable()
	var plain: FileAccess = FileAccess.open(path, FileAccess.READ)
	if plain == null:
		return SaveReadResult.unreadable()
	return SaveReadResult.found(plain.get_buffer(plain.get_length()))


static func _has_encrypted_header(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_buffer(ENCRYPTED_HEADER.length()) == ENCRYPTED_HEADER.to_ascii_buffer()


func _write(path: String, bytes: PackedByteArray) -> ActionResult:
	var temp: String = path + TEMP_SUFFIX
	var backup_temp: String = path + BACKUP_SUFFIX + TEMP_SUFFIX
	var failure: String = _write_steps(path, temp, backup_temp, bytes)
	if not failure.is_empty():
		_remove_if_present(temp)
		_remove_if_present(backup_temp)
		push_error("LocalSaveStore: could not write '%s': %s; the previous files stay." % [path, failure])
		return ActionResult.failure(ERR_SAVE_FAILED)
	if FileAccess.file_exists(backup_temp):
		var rotated: Error = DirAccess.rename_absolute(backup_temp, path + BACKUP_SUFFIX)
		if rotated != OK:
			# MAIN is already saved; the older backup stays valid.
			push_error("LocalSaveStore: the backup of '%s' was not rotated (%s)." % [path, error_string(rotated)])
	return ActionResult.success()


## Steps 1-3 of the safe write; "" when they all worked, else what failed.
func _write_steps(path: String, temp: String, backup_temp: String, bytes: PackedByteArray) -> String:
	var made: Error = DirAccess.make_dir_recursive_absolute(_root)
	if made != OK:
		return "the folder could not be created (%s)" % error_string(made)
	if not _write_file(temp, bytes):
		return "the temporary file could not be written"
	var written: SaveReadResult = _read(temp)
	if written.status != SaveReadResult.Status.FOUND or written.bytes != bytes:
		return "the temporary file did not read back the same"
	if _is_valid(path):
		var copied: Error = DirAccess.copy_absolute(path, backup_temp)
		if copied != OK:
			return "the backup could not be copied (%s)" % error_string(copied)
	var renamed: Error = DirAccess.rename_absolute(temp, path)
	if renamed != OK:
		return "the new file could not replace the old one (%s)" % error_string(renamed)
	return ""


func _write_file(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = (
		FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, _PASSWORD) if _encrypt
		else FileAccess.open(path, FileAccess.WRITE)
	)
	if file == null:
		return false
	var stored: bool = file.store_buffer(bytes)
	file.close()
	return stored


## Readable and holding a JSON object: only then may it become the backup.
func _is_valid(path: String) -> bool:
	var result: SaveReadResult = _read(path)
	return result.status == SaveReadResult.Status.FOUND and SaveCodec.decode(result.bytes) != null


## MAIN and BACKUP each renamed to <file>.damaged.<n>, the first free n (R-010-49).
func _set_aside(path: String) -> ActionResult:
	for file: String in [path, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(file):
			continue
		var index: int = 1
		while FileAccess.file_exists(file + DAMAGED_SUFFIX + str(index)):
			index += 1
		var renamed: Error = DirAccess.rename_absolute(file, file + DAMAGED_SUFFIX + str(index))
		if renamed != OK:
			push_error("LocalSaveStore: could not set '%s' aside (%s)." % [file, error_string(renamed)])
			return ActionResult.failure(ERR_SAVE_FAILED)
	return ActionResult.success()


static func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var removed: Error = DirAccess.remove_absolute(path)
	if removed != OK:
		push_error("LocalSaveStore: could not delete '%s' (%s)." % [path, error_string(removed)])
	return removed == OK
