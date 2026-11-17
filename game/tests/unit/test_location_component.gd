extends GutTest
## LocationComponent (spec 010): remembers in which zone and where inside it the
## player stands (R-010-06, R-010-36). enter() records the zone and the local
## position of the parent Node3D; from_save_data() only stores a restored
## location for the loader to use and emits nothing (D15, R-010-09).
## R-010-08: the saved data uses JSON types only.

var _body: Node3D
var _zone_root: Node3D
var _location: LocationComponent
var _expected_errors: int = 0


func before_each() -> void:
	_expected_errors = 0
	_zone_root = Node3D.new()
	_zone_root.position = Vector3(100.0, 0.0, -40.0)
	add_child_autofree(_zone_root)
	_body = Node3D.new()
	add_child_autofree(_body)
	_location = LocationComponent.new()
	_location.name = "Location"
	_body.add_child(_location)


func _vec3_from(array: Array) -> Vector3:
	var x: float = array[0] as float
	var y: float = array[1] as float
	var z: float = array[2] as float
	return Vector3(x, y, z)


func test_r_010_06_save_key() -> void:
	assert_eq(LocationComponent.SAVE_KEY, &"location", "const")
	assert_eq(_location.get_save_key(), &"location", "getter")


func test_r_010_06_empty_without_enter_or_restore() -> void:
	var data: Dictionary = _location.to_save_data()
	assert_true(data.is_empty(), "nothing known, nothing saved")
	assert_false(_location.has_restored_location(), "no restored location")


func test_r_010_06_enter_saves_zone_and_local_position() -> void:
	_body.global_position = Vector3(103.0, 1.5, -38.0)
	_location.enter(Vector2i(2, -1), _zone_root)
	var data: Dictionary = _location.to_save_data()
	var zone_id: Array = data["zone_id"] as Array
	var position: Array = data["position"] as Array
	assert_eq(zone_id, [2, -1], "zone id as [x, y]")
	assert_eq(position.size(), 3, "position has three components")
	var local: Vector3 = _vec3_from(position)
	assert_almost_eq(local.x, 3.0, 0.001, "local x")
	assert_almost_eq(local.y, 1.5, 0.001, "local y")
	assert_almost_eq(local.z, 2.0, 0.001, "local z")


func test_r_010_08_save_data_is_json_safe() -> void:
	_body.global_position = Vector3(103.0, 1.5, -38.0)
	_location.enter(Vector2i(2, -1), _zone_root)
	var data: Dictionary = _location.to_save_data()
	var text: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(text)
	var back: Dictionary = parsed as Dictionary
	assert_eq(back.size(), 2, "survives a JSON round trip with both keys")
	assert_true(back.has("zone_id") and back.has("position"), "both keys present")
	var zone_id: Array = data["zone_id"] as Array
	assert_eq(typeof(zone_id[0]), TYPE_INT, "zone id components are ints")


func test_r_010_06_position_follows_the_body_at_save_time() -> void:
	_location.enter(Vector2i(0, 0), _zone_root)
	_body.global_position = Vector3(110.0, 0.0, -30.0)
	var data: Dictionary = _location.to_save_data()
	var local: Vector3 = _vec3_from(data["position"] as Array)
	assert_almost_eq(local.x, 10.0, 0.001, "local x after moving")
	assert_almost_eq(local.z, 10.0, 0.001, "local z after moving")


func test_r_010_09_from_save_data_stores_restored_location() -> void:
	_location.from_save_data({"zone_id": [3.0, -2.0], "position": [1.5, 0.0, -4.25]})
	assert_true(_location.has_restored_location(), "valid data restores")
	assert_eq(_location.get_restored_zone_id(), Vector2i(3, -2), "float whole numbers accepted")
	assert_eq(_location.get_restored_local_position(), Vector3(1.5, 0.0, -4.25), "position")
	assert_push_error_count(0)


func test_r_010_09_to_save_data_returns_restored_before_enter() -> void:
	_location.from_save_data({"zone_id": [3, -2], "position": [1.5, 0.0, -4.25]})
	var data: Dictionary = _location.to_save_data()
	var zone_id: Array = data["zone_id"]
	assert_eq(zone_id, [3, -2], "restored zone id")
	var local: Vector3 = _vec3_from(data["position"] as Array)
	assert_almost_eq(local.x, 1.5, 0.001, "restored x")
	assert_almost_eq(local.z, -4.25, 0.001, "restored z")


func test_r_010_09_enter_clears_restored_location() -> void:
	_location.from_save_data({"zone_id": [3, -2], "position": [1.5, 0.0, -4.25]})
	_location.enter(Vector2i(0, 0), _zone_root)
	assert_false(_location.has_restored_location(), "the player is placed: nothing to restore")
	var data: Dictionary = _location.to_save_data()
	var zone_id: Array = data["zone_id"]
	assert_eq(zone_id, [0, 0], "now the entered zone is saved")


## {} is what to_save_data() gives for a player that never entered a zone:
## loading it is not an error and restores nothing.
func test_r_010_09_empty_data_restores_nothing_silently() -> void:
	_location.from_save_data({})
	assert_push_error_count(0)
	assert_false(_location.has_restored_location(), "empty data restores nothing")


func test_r_010_11_missing_keys_are_rejected() -> void:
	_location.from_save_data({"zone_id": [1, 1]})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "missing position")
	_location.from_save_data({"position": [1.0, 0.0, 1.0]})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "missing zone_id")


func test_r_010_11_invalid_zone_id_is_rejected() -> void:
	var position: Array = [0.0, 0.0, 0.0]
	_location.from_save_data({"zone_id": [1.5, 2], "position": position})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "fractional zone id")
	_location.from_save_data({"zone_id": [1], "position": position})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "wrong length")
	_location.from_save_data({"zone_id": "1,2", "position": position})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "not an array")
	_location.from_save_data({"zone_id": ["a", 2], "position": position})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "not numbers")


func test_r_010_11_invalid_position_is_rejected() -> void:
	_location.from_save_data({"zone_id": [0, 0], "position": [1.0, 2.0]})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "wrong length")
	_location.from_save_data({"zone_id": [0, 0], "position": [1.0, "x", 2.0]})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "not numbers")
	_location.from_save_data({"zone_id": [0, 0], "position": 5})
	_assert_one_more_error()
	assert_false(_location.has_restored_location(), "not an array")


func test_r_010_11_invalid_load_leaves_nothing_to_save() -> void:
	_location.from_save_data({"zone_id": [0, 0], "position": [1.0]})
	_assert_one_more_error()
	var data: Dictionary = _location.to_save_data()
	assert_true(data.is_empty(), "nothing valid known")


## assert_push_error_count is cumulative per test, so each rejected load adds one.
func _assert_one_more_error() -> void:
	_expected_errors += 1
	assert_push_error_count(_expected_errors)
