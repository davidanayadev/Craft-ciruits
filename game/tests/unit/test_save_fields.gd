extends GutTest
## SaveFields (spec 010, R-010-05, D4, D18): typed reads of JSON values. JSON
## numbers always arrive as float, so a whole float counts as an integer.
## Pure code: no scene tree, no files.


func test_r_010_05_is_whole_number_accepts_int_and_whole_float() -> void:
	assert_true(SaveFields.is_whole_number(3), "int")
	assert_true(SaveFields.is_whole_number(3.0), "float without fraction")
	assert_true(SaveFields.is_whole_number(-7.0), "negative whole float")
	assert_true(SaveFields.is_whole_number(0), "zero")


func test_r_010_05_is_whole_number_rejects_the_rest() -> void:
	assert_false(SaveFields.is_whole_number(3.5), "fraction")
	assert_false(SaveFields.is_whole_number("3"), "text")
	assert_false(SaveFields.is_whole_number(null), "null")
	assert_false(SaveFields.is_whole_number([3]), "array")
	assert_false(SaveFields.is_whole_number(INF), "infinity")
	assert_false(SaveFields.is_whole_number(NAN), "nan")


func test_r_010_05_to_int_converts_whole_values() -> void:
	assert_eq(SaveFields.to_int(5, -1), 5)
	assert_eq(SaveFields.to_int(5.0, -1), 5)


func test_r_010_05_to_int_uses_fallback_when_not_whole() -> void:
	assert_eq(SaveFields.to_int(5.5, -1), -1, "fraction")
	assert_eq(SaveFields.to_int("5", -1), -1, "text")
	assert_eq(SaveFields.to_int(null, 42), 42, "null")


func test_r_010_05_to_vector2i_from_ints_and_whole_floats() -> void:
	var from_ints: Vector2i = SaveFields.to_vector2i([2, 3])
	var from_floats: Vector2i = SaveFields.to_vector2i([2.0, -3.0])
	assert_eq(from_ints, Vector2i(2, 3))
	assert_eq(from_floats, Vector2i(2, -3))


func test_r_010_05_to_vector2i_null_for_bad_input() -> void:
	assert_true(SaveFields.to_vector2i([1]) == null, "too short")
	assert_true(SaveFields.to_vector2i([1, 2, 3]) == null, "too long")
	assert_true(SaveFields.to_vector2i([]) == null, "empty")
	assert_true(SaveFields.to_vector2i(["a", 2]) == null, "text")
	assert_true(SaveFields.to_vector2i([1.5, 2]) == null, "fraction")
	assert_true(SaveFields.to_vector2i([null, 2]) == null, "null item")
	assert_true(SaveFields.to_vector2i(5) == null, "number")
	assert_true(SaveFields.to_vector2i("1,2") == null, "text value")
	assert_true(SaveFields.to_vector2i({"x": 1, "y": 2}) == null, "dictionary")
	assert_true(SaveFields.to_vector2i(null) == null, "null")


func test_r_010_05_to_vector3_accepts_any_numbers() -> void:
	var from_ints: Vector3 = SaveFields.to_vector3([1, 2, 3])
	var from_floats: Vector3 = SaveFields.to_vector3([1.5, -2.25, 3.0])
	assert_eq(from_ints, Vector3(1, 2, 3))
	assert_eq(from_floats, Vector3(1.5, -2.25, 3.0))


func test_r_010_05_to_vector3_null_for_bad_input() -> void:
	assert_true(SaveFields.to_vector3([1, 2]) == null, "too short")
	assert_true(SaveFields.to_vector3([1, 2, 3, 4]) == null, "too long")
	assert_true(SaveFields.to_vector3([1, "b", 3]) == null, "text")
	assert_true(SaveFields.to_vector3([1, 2, null]) == null, "null item")
	assert_true(SaveFields.to_vector3(7) == null, "number")
	assert_true(SaveFields.to_vector3(null) == null, "null")


func test_r_010_05_vector_to_array() -> void:
	var pair: Array = SaveFields.vector2i_to_array(Vector2i(4, -5))
	var triple: Array = SaveFields.vector3_to_array(Vector3(1.5, 2.0, -3.25))
	assert_eq(pair, [4, -5])
	assert_eq(triple, [1.5, 2.0, -3.25])


func test_r_010_05_round_trip_through_json_floats() -> void:
	var json: String = JSON.stringify({"a": SaveFields.vector2i_to_array(Vector2i(7, -2)),
			"b": SaveFields.vector3_to_array(Vector3(0.5, 1.0, 2.0))})
	var parsed: Variant = JSON.parse_string(json)
	var data: Dictionary = parsed as Dictionary
	var pair: Vector2i = SaveFields.to_vector2i(data["a"])
	var triple: Vector3 = SaveFields.to_vector3(data["b"])
	assert_eq(pair, Vector2i(7, -2), "ints came back as floats")
	assert_eq(triple, Vector3(0.5, 1.0, 2.0))
