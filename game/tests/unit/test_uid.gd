extends GutTest
## Uid (spec 007, R-007-18): locally generated ids of 128 random bits as 32
## lowercase hexadecimal characters (architecture §10.3).

const HEX_PATTERN := "^[0-9a-f]{32}$"
const SAMPLES := 50


func test_r_007_18_is_32_hex_chars() -> void:
	var regex: RegEx = RegEx.create_from_string(HEX_PATTERN)
	for i: int in SAMPLES:
		var uid: String = Uid.generate()
		assert_not_null(regex.search(uid), "'%s' is 32 lowercase hex characters" % uid)


func test_r_007_18_two_are_different() -> void:
	var seen: Dictionary[String, bool] = {}
	for i: int in SAMPLES:
		seen[Uid.generate()] = true
	assert_eq(seen.size(), SAMPLES, "no two generated ids are equal")
