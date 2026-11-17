extends GutTest
## SaveCodec (spec 010, R-010-05, D4): Dictionary <-> JSON UTF-8 bytes, sorted
## keys and full float precision. Pure code: no scene tree, no files.


func test_r_010_05_round_trip_keeps_structure() -> void:
	var document: Dictionary = {"name": "Farm", "list": [1, 2, 3], "nested": {"ok": true, "none": null}}
	var decoded: Variant = SaveCodec.decode(SaveCodec.encode(document))
	assert_true(decoded is Dictionary, "decodes to a Dictionary")
	var result: Dictionary = decoded as Dictionary
	var name: String = result["name"]
	var list: Array = result["list"]
	var nested: Dictionary = result["nested"] as Dictionary
	var ok: bool = nested["ok"]
	assert_eq(name, "Farm")
	assert_eq(list, [1.0, 2.0, 3.0], "numbers come back as float")
	assert_true(ok)
	assert_true(nested["none"] == null, "null kept")


func test_r_010_05_full_precision_round_trip() -> void:
	var sum: float = 0.1 + 0.2
	var document: Dictionary = {"a": 73.12345678901235, "b": sum}
	var decoded: Variant = SaveCodec.decode(SaveCodec.encode(document))
	var result: Dictionary = decoded as Dictionary
	var a: float = result["a"]
	var b: float = result["b"]
	assert_eq(a, 73.12345678901235, "exact")
	assert_eq(b, sum, "0.1 + 0.2 exact")


func test_r_010_05_keys_are_sorted() -> void:
	var first: PackedByteArray = SaveCodec.encode({"b": 1, "a": 2, "c": 3})
	var second: PackedByteArray = SaveCodec.encode({"c": 3, "a": 2, "b": 1})
	assert_eq(first, second, "same bytes whatever the insertion order")
	var text: String = first.get_string_from_utf8()
	assert_lt(text.find("\"a\""), text.find("\"b\""))
	assert_lt(text.find("\"b\""), text.find("\"c\""))


func test_r_010_05_encoded_bytes_are_utf8_json() -> void:
	var bytes: PackedByteArray = SaveCodec.encode({"name": "Cámara ñ"})
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	var result: Dictionary = parsed as Dictionary
	var name: String = result["name"]
	assert_eq(name, "Cámara ñ")


func test_r_010_05_decode_garbage_bytes_is_null() -> void:
	var garbage: PackedByteArray = PackedByteArray([0xFF, 0xFE, 0x00, 0x9C, 0x80, 0xC3, 0x28])
	assert_true(SaveCodec.decode(garbage) == null, "garbage")


func test_r_010_05_decode_empty_is_null() -> void:
	assert_true(SaveCodec.decode(PackedByteArray()) == null, "empty")


func test_r_010_05_decode_broken_json_is_null() -> void:
	assert_true(SaveCodec.decode("{\"a\": 1,".to_utf8_buffer()) == null, "truncated")
	assert_true(SaveCodec.decode("not json".to_utf8_buffer()) == null, "text")


func test_r_010_05_decode_non_object_top_level_is_null() -> void:
	assert_true(SaveCodec.decode("[1, 2, 3]".to_utf8_buffer()) == null, "array")
	assert_true(SaveCodec.decode("42".to_utf8_buffer()) == null, "number")
	assert_true(SaveCodec.decode("\"text\"".to_utf8_buffer()) == null, "string")
	assert_true(SaveCodec.decode("null".to_utf8_buffer()) == null, "null")


func test_r_010_05_decode_object_is_dictionary() -> void:
	var decoded: Variant = SaveCodec.decode("{\"a\": 1}".to_utf8_buffer())
	assert_true(decoded is Dictionary)
