class_name ISaveStore
extends RefCounted
## Contract of where saves live (spec 010, architecture §10.1): the plain
## bytes of the Profile and of each World, with a backup copy of each. It
## knows nothing of what the bytes hold. Only SaveManager uses a store
## (R-010-02). GDScript has no interfaces: every method push_errors and fails
## when not overridden (R-010-01).

enum Copy { MAIN, BACKUP }

## The error key of every failed write, set aside or delete.
const ERR_SAVE_FAILED := &"ERR_SAVE_FAILED"


func read_profile(_copy: Copy) -> SaveReadResult:
	_not_implemented("read_profile")
	return SaveReadResult.unreadable()


## The previous MAIN, when valid, becomes the BACKUP (R-010-46); a failure
## leaves both as they were (R-010-45).
func write_profile(_bytes: PackedByteArray) -> ActionResult:
	_not_implemented("write_profile")
	return ActionResult.failure(ERR_SAVE_FAILED)


## MAIN and BACKUP renamed aside, never deleted (R-010-49).
func set_aside_profile() -> ActionResult:
	_not_implemented("set_aside_profile")
	return ActionResult.failure(ERR_SAVE_FAILED)


## Sorted.
func list_world_ids() -> PackedStringArray:
	_not_implemented("list_world_ids")
	return PackedStringArray()


func read_world(_world_id: String, _copy: Copy) -> SaveReadResult:
	_not_implemented("read_world")
	return SaveReadResult.unreadable()


func write_world(_world_id: String, _bytes: PackedByteArray) -> ActionResult:
	_not_implemented("write_world")
	return ActionResult.failure(ERR_SAVE_FAILED)


func set_aside_world(_world_id: String) -> ActionResult:
	_not_implemented("set_aside_world")
	return ActionResult.failure(ERR_SAVE_FAILED)


## MAIN, BACKUP and any leftover temporary (R-010-51).
func delete_world(_world_id: String) -> ActionResult:
	_not_implemented("delete_world")
	return ActionResult.failure(ERR_SAVE_FAILED)


func _not_implemented(method: String) -> void:
	push_error("ISaveStore: %s() is not implemented." % method)
