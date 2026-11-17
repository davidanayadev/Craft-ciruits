class_name MemorySaveStore
extends ISaveStore
## A save store in memory for tests (spec 010, plan D10): never touches the
## disk. It follows the backup rule of LocalSaveStore (a valid MAIN becomes the
## BACKUP when overwritten) and lets a test damage a copy or make writes fail.

## Every write, set aside and delete fails while true.
var fail_writes: bool = false
## Only setting files aside fails while true.
var fail_set_aside: bool = false
## Each read as "<file>:<MAIN|BACKUP>", in order (R-010-50).
var reads: PackedStringArray = PackedStringArray()
## How many writes succeeded.
var write_count: int = 0

## file name ("profile", "world_<id>") → {Copy → bytes}.
var _files: Dictionary[String, Dictionary] = {}
## Files set aside, never deleted: file name → list of {Copy → bytes}.
var _set_aside: Dictionary[String, Array] = {}


func read_profile(copy: Copy) -> SaveReadResult:
	return _read("profile", copy)


func write_profile(bytes: PackedByteArray) -> ActionResult:
	return _write("profile", bytes)


func set_aside_profile() -> ActionResult:
	return _aside("profile")


func list_world_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for file: String in _files:
		if file.begins_with("world_") and _files[file].has(Copy.MAIN):
			ids.append(file.trim_prefix("world_"))
	ids.sort()
	return ids


func read_world(world_id: String, copy: Copy) -> SaveReadResult:
	return _read("world_" + world_id, copy)


func write_world(world_id: String, bytes: PackedByteArray) -> ActionResult:
	return _write("world_" + world_id, bytes)


func set_aside_world(world_id: String) -> ActionResult:
	return _aside("world_" + world_id)


func delete_world(world_id: String) -> ActionResult:
	if fail_writes:
		return ActionResult.failure(ERR_SAVE_FAILED)
	_files.erase("world_" + world_id)
	return ActionResult.success()


## Puts bytes as they are in a copy, bypassing the backup rule: a damaged or
## hand-made file.
func put(file: String, copy: Copy, bytes: PackedByteArray) -> void:
	if not _files.has(file):
		_files[file] = {}
	_files[file][copy] = bytes


## The bytes of a copy; empty when it does not exist.
func get_bytes(file: String, copy: Copy) -> PackedByteArray:
	var copies: Dictionary = _files.get(file, {})
	var bytes: PackedByteArray = copies.get(copy, PackedByteArray())
	return bytes


func has_copy(file: String, copy: Copy) -> bool:
	var copies: Dictionary = _files.get(file, {})
	return copies.has(copy)


func get_set_aside(file: String) -> Array:
	return _set_aside.get(file, [])


func _read(file: String, copy: Copy) -> SaveReadResult:
	reads.append("%s:%s" % [file, Copy.keys()[copy]])
	if not has_copy(file, copy):
		return SaveReadResult.missing()
	return SaveReadResult.found(get_bytes(file, copy))


func _write(file: String, bytes: PackedByteArray) -> ActionResult:
	if fail_writes:
		return ActionResult.failure(ERR_SAVE_FAILED)
	if has_copy(file, Copy.MAIN) and SaveCodec.decode(get_bytes(file, Copy.MAIN)) != null:
		put(file, Copy.BACKUP, get_bytes(file, Copy.MAIN))
	put(file, Copy.MAIN, bytes)
	write_count += 1
	return ActionResult.success()


func _aside(file: String) -> ActionResult:
	if fail_writes or fail_set_aside:
		return ActionResult.failure(ERR_SAVE_FAILED)
	if _files.has(file):
		var aside: Array = _set_aside.get(file, [])
		aside.append(_files[file])
		_set_aside[file] = aside
		_files.erase(file)
	return ActionResult.success()
