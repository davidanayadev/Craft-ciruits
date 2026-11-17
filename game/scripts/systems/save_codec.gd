class_name SaveCodec
extends RefCounted
## A save document as bytes and back (spec 010, plan D4): JSON in UTF-8 with
## sorted keys and full precision, so a float comes back exactly. It knows
## nothing of what the document holds, nor of files or encryption.


static func encode(document: Dictionary) -> PackedByteArray:
	return JSON.stringify(document, "", true, true).to_utf8_buffer()


## Null when the bytes are not UTF-8 JSON with an object at the top. Numbers
## come back as floats: read them through SaveFields.
static func decode(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return null
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return null
	var data: Variant = json.data
	if not data is Dictionary:
		return null
	return data
