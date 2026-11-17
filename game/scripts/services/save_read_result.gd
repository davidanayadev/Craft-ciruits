class_name SaveReadResult
extends RefCounted
## What reading one copy of a save gave (spec 010): its plain bytes, nothing
## there, or something that could not be read. Whether the bytes are a valid
## document is not the store's to say.

enum Status { FOUND, MISSING, UNREADABLE }

var status: Status = Status.MISSING
## Plain bytes; empty unless FOUND.
var bytes: PackedByteArray = PackedByteArray()


static func found(p_bytes: PackedByteArray) -> SaveReadResult:
	var result: SaveReadResult = SaveReadResult.new()
	result.status = Status.FOUND
	result.bytes = p_bytes
	return result


static func missing() -> SaveReadResult:
	return SaveReadResult.new()


static func unreadable() -> SaveReadResult:
	var result: SaveReadResult = SaveReadResult.new()
	result.status = Status.UNREADABLE
	return result
