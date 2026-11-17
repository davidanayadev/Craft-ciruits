extends GutTest
## SaveDocuments and ProfileData (spec 010, R-010-05, R-010-07, R-010-12,
## R-010-16, R-010-17, R-010-22, R-010-52, R-010-60, D3): assembling,
## validating and splitting the Profile and World documents.
## Pure code: no scene tree, no files.

const WORLD_KEYS: Array[String] = ["schema_version", "world_id", "name", "seed", "ruleset_id",
		"saved_at", "players", "world"]
const PROFILE_KEYS: Array[String] = ["schema_version", "player_uuid", "entitlements", "hall_of_fame",
		"cosmetics", "blueprints"]
const BIG_SEED := -8213372036854775807
const HEX_PATTERN := "^[0-9a-f]{32}$"

var _catalog: DataCatalog


func before_each() -> void:
	var ruleset: RulesetData = RulesetData.new()
	ruleset.id = &"normal"
	ruleset.respawn_battery_ratio = 1.0
	_catalog = DataCatalog.new()
	_catalog.rulesets.append(ruleset)


func _header() -> SaveDocuments.WorldHeader:
	var header: SaveDocuments.WorldHeader = SaveDocuments.WorldHeader.new()
	header.world_id = Uid.generate()
	header.world_name = "Mi mundo"
	header.world_seed = BIG_SEED
	header.ruleset_id = &"normal"
	header.saved_at_unix = 1763400000
	return header


func _players() -> Dictionary[String, Dictionary]:
	var players: Dictionary[String, Dictionary] = {}
	players["p1"] = {"battery": {"value": 55.5}, "inventory": {"slots": []}}
	return players


func _world_parts() -> Dictionary[String, Dictionary]:
	var parts: Dictionary[String, Dictionary] = {}
	parts["game_manager"] = {"visits": {"0": 2}}
	return parts


func _valid_world() -> Dictionary:
	return SaveDocuments.build_world(_header(), _players(), _world_parts())


## Encode and decode as the disk would, so numbers come back as float.
func _through_json(document: Dictionary) -> Dictionary:
	var decoded: Variant = SaveCodec.decode(SaveCodec.encode(document))
	assert_true(decoded is Dictionary, "document survives the codec")
	return decoded as Dictionary


func _has_key_deep(value: Variant, key: String) -> bool:
	if value is Dictionary:
		var dict: Dictionary = value as Dictionary
		for k: Variant in dict:
			if str(k) == key or _has_key_deep(dict[k], key):
				return true
	elif value is Array:
		var list: Array = value as Array
		for item: Variant in list:
			if _has_key_deep(item, key):
				return true
	return false


# --- ProfileData ---------------------------------------------------------------

func test_r_010_12_profile_fields() -> void:
	var profile: ProfileData = ProfileData.create_new()
	var regex: RegEx = RegEx.create_from_string(HEX_PATTERN)
	assert_not_null(regex.search(profile.player_uuid), "uuid is 32 lowercase hex")
	assert_eq(profile.entitlements.size(), 0)
	assert_eq(profile.hall_of_fame.size(), 0)
	assert_eq(profile.cosmetics.size(), 0)
	assert_eq(profile.blueprints.size(), 0)


func test_r_010_12_two_new_profiles_differ() -> void:
	var first: ProfileData = ProfileData.create_new()
	var second: ProfileData = ProfileData.create_new()
	assert_ne(first.player_uuid, second.player_uuid)


func test_r_010_12_copy_is_independent() -> void:
	var profile: ProfileData = ProfileData.create_new()
	profile.entitlements.append("full_game")
	profile.hall_of_fame.append({"name": "x"})
	var copy: ProfileData = profile.copy()
	assert_eq(copy.player_uuid, profile.player_uuid)
	assert_eq(copy.entitlements, profile.entitlements)
	copy.entitlements.append("other")
	copy.cosmetics.append("skin")
	copy.blueprints.append("bp")
	copy.hall_of_fame.append({"name": "y"})
	copy.player_uuid = "changed"
	assert_eq(profile.entitlements.size(), 1, "entitlements not shared")
	assert_eq(profile.cosmetics.size(), 0, "cosmetics not shared")
	assert_eq(profile.blueprints.size(), 0, "blueprints not shared")
	assert_eq(profile.hall_of_fame.size(), 1, "hall of fame not shared")
	assert_ne(profile.player_uuid, "changed")


# --- Constants -------------------------------------------------------------------

func test_r_010_52_schema_versions() -> void:
	var world: Dictionary = _valid_world()
	var profile: Dictionary = SaveDocuments.build_profile(ProfileData.create_new())
	assert_eq(SaveFields.to_int(world["schema_version"], -1), SaveMigrations.WORLD_VERSION)
	assert_eq(SaveFields.to_int(profile["schema_version"], -1), SaveMigrations.PROFILE_VERSION)


func test_r_010_06_persistent_group_name() -> void:
	assert_eq(SaveDocuments.PERSISTENT_GROUP, &"persistent")


# --- build_world / header --------------------------------------------------------

func test_r_010_17_world_header() -> void:
	var header: SaveDocuments.WorldHeader = _header()
	var document: Dictionary = SaveDocuments.build_world(header, _players(), _world_parts())
	var keys: Array = document.keys()
	keys.sort()
	var expected: Array = WORLD_KEYS.duplicate()
	expected.sort()
	assert_eq(keys, expected, "exactly the world keys")
	var world_id: String = document["world_id"]
	var world_name: String = document["name"]
	assert_eq(world_id, header.world_id)
	assert_eq(world_name, header.world_name)
	assert_eq(str(document["ruleset_id"]), "normal")
	assert_true(document["players"] is Dictionary)
	assert_true(document["world"] is Dictionary)


func test_r_010_17_seed_is_decimal_text() -> void:
	var document: Dictionary = _valid_world()
	assert_true(document["seed"] is String, "seed is text, not a number (D3)")
	var seed_text: String = document["seed"]
	assert_eq(seed_text, str(BIG_SEED))


func test_r_010_17_header_round_trip_through_codec() -> void:
	var header: SaveDocuments.WorldHeader = _header()
	var document: Dictionary = _through_json(SaveDocuments.build_world(header, _players(), _world_parts()))
	var read: SaveDocuments.WorldHeader = SaveDocuments.read_header(document)
	assert_eq(read.world_id, header.world_id)
	assert_eq(read.world_name, header.world_name)
	assert_eq(read.world_seed, BIG_SEED, "64-bit seed survives exactly")
	assert_eq(read.ruleset_id, &"normal")
	assert_eq(read.saved_at_unix, header.saved_at_unix, "int after JSON float")


func test_r_010_17_seed_extremes_round_trip() -> void:
	for seed_value: int in [0, 1, -1, 9223372036854775807, -9223372036854775807 - 1, 9007199254740993]:
		var header: SaveDocuments.WorldHeader = _header()
		header.world_seed = seed_value
		var document: Dictionary = _through_json(SaveDocuments.build_world(header, _players(), _world_parts()))
		var read: SaveDocuments.WorldHeader = SaveDocuments.read_header(document)
		assert_eq(read.world_seed, seed_value, "seed %d" % seed_value)


func test_r_010_22_players_by_uid() -> void:
	var players: Dictionary[String, Dictionary] = {}
	players["uid_a"] = {"battery": {"value": 10.0}}
	players["uid_b"] = {"battery": {"value": 90.0}}
	var document: Dictionary = _through_json(SaveDocuments.build_world(_header(), players, _world_parts()))
	var read: Dictionary[String, Dictionary] = SaveDocuments.read_players(document)
	assert_eq(read.size(), 2)
	assert_true(read.has("uid_a") and read.has("uid_b"))
	var battery_a: Dictionary = read["uid_a"]["battery"] as Dictionary
	var battery_b: Dictionary = read["uid_b"]["battery"] as Dictionary
	var value_a: float = battery_a["value"]
	var value_b: float = battery_b["value"]
	assert_eq(value_a, 10.0)
	assert_eq(value_b, 90.0)


func test_r_010_22_world_parts_by_key() -> void:
	var parts: Dictionary[String, Dictionary] = {}
	parts["zones"] = {"count": 3}
	parts["base"] = {"cells": []}
	var document: Dictionary = _through_json(SaveDocuments.build_world(_header(), _players(), parts))
	var read: Dictionary[String, Dictionary] = SaveDocuments.read_world_parts(document)
	assert_eq(read.size(), 2)
	var zones: Dictionary = read["zones"]
	var count: float = zones["count"]
	assert_eq(count, 3.0)
	assert_true(read.has("base"))


func test_r_010_22_players_and_world_may_be_empty() -> void:
	var none: Dictionary[String, Dictionary] = {}
	var document: Dictionary = SaveDocuments.build_world(_header(), none, none)
	assert_eq(SaveDocuments.validate_world(document, _catalog).size(), 0)
	assert_eq(SaveDocuments.read_players(document).size(), 0)
	assert_eq(SaveDocuments.read_world_parts(document).size(), 0)


# --- Profile ---------------------------------------------------------------------

func test_r_010_16_profile_has_no_world_state() -> void:
	var document: Dictionary = SaveDocuments.build_profile(ProfileData.create_new())
	var keys: Array = document.keys()
	keys.sort()
	var expected: Array = PROFILE_KEYS.duplicate()
	expected.sort()
	assert_eq(keys, expected, "exactly the profile keys")


func test_r_010_12_profile_round_trip() -> void:
	var profile: ProfileData = ProfileData.create_new()
	profile.entitlements.append("full_game")
	profile.cosmetics.append("gold_paint")
	profile.blueprints.append("bp_arm")
	profile.hall_of_fame.append({"world": "w", "days": 3})
	var document: Dictionary = _through_json(SaveDocuments.build_profile(profile))
	assert_eq(SaveDocuments.validate_profile(document).size(), 0)
	var read: ProfileData = SaveDocuments.read_profile(document)
	assert_eq(read.player_uuid, profile.player_uuid)
	assert_eq(read.entitlements, profile.entitlements)
	assert_eq(read.cosmetics, profile.cosmetics)
	assert_eq(read.blueprints, profile.blueprints)
	assert_eq(read.hall_of_fame.size(), 1)
	var fame_world: String = read.hall_of_fame[0]["world"]
	assert_eq(fame_world, "w")


func test_r_010_60_entitlements_only_in_profile() -> void:
	var world: Dictionary = _valid_world()
	assert_false(_has_key_deep(world, "entitlements"), "no world holds entitlements")
	var profile: Dictionary = SaveDocuments.build_profile(ProfileData.create_new())
	assert_true(profile.has("entitlements"), "the profile does")


func test_r_010_60_entitlements_survive_in_profile() -> void:
	var profile: ProfileData = ProfileData.create_new()
	profile.entitlements.append("sku_unlock")
	var document: Dictionary = _through_json(SaveDocuments.build_profile(profile))
	var read: ProfileData = SaveDocuments.read_profile(document)
	assert_true(read.entitlements.has("sku_unlock"))


# --- validate_world --------------------------------------------------------------

func test_r_010_05_valid_world_has_no_problems() -> void:
	var document: Dictionary = _through_json(_valid_world())
	assert_eq(SaveDocuments.validate_world(document, _catalog).size(), 0)


func test_r_010_05_world_missing_each_header_field() -> void:
	for key: String in ["world_id", "name", "seed", "ruleset_id", "saved_at", "players", "world"]:
		var document: Dictionary = _through_json(_valid_world())
		document.erase(key)
		var problems: PackedStringArray = SaveDocuments.validate_world(document, _catalog)
		assert_eq(problems.size(), 1, "missing '%s' is one problem: %s" % [key, problems])


func test_r_010_05_world_wrong_types() -> void:
	var cases: Dictionary[String, Variant] = {
		"world_id": 5.0, "name": [], "seed": 12.0, "ruleset_id": 3.0,
		"saved_at": "now", "players": [], "world": "x",
	}
	for key: String in cases:
		var document: Dictionary = _through_json(_valid_world())
		document[key] = cases[key]
		var problems: PackedStringArray = SaveDocuments.validate_world(document, _catalog)
		assert_gt(problems.size(), 0, "wrong type for '%s' is reported" % key)


func test_r_010_05_world_seed_must_be_decimal_text() -> void:
	for bad: String in ["abc", "", "12.5", "0x10", "1e3", " 7"]:
		var document: Dictionary = _through_json(_valid_world())
		document["seed"] = bad
		var problems: PackedStringArray = SaveDocuments.validate_world(document, _catalog)
		assert_eq(problems.size(), 1, "seed '%s' is rejected: %s" % [bad, problems])


func test_r_010_05_world_unknown_ruleset() -> void:
	var document: Dictionary = _through_json(_valid_world())
	document["ruleset_id"] = "does_not_exist"
	var problems: PackedStringArray = SaveDocuments.validate_world(document, _catalog)
	assert_eq(problems.size(), 1, "one problem: %s" % problems)


func test_r_010_05_world_saved_at_must_be_whole() -> void:
	var document: Dictionary = _through_json(_valid_world())
	document["saved_at"] = 1.5
	assert_eq(SaveDocuments.validate_world(document, _catalog).size(), 1)


func test_r_010_05_world_player_entry_must_be_dictionary() -> void:
	var document: Dictionary = _through_json(_valid_world())
	var players: Dictionary = document["players"] as Dictionary
	players["p1"] = 7.0
	assert_gt(SaveDocuments.validate_world(document, _catalog).size(), 0)


func test_r_010_05_world_several_problems_several_messages() -> void:
	var document: Dictionary = _through_json(_valid_world())
	document.erase("name")
	document["ruleset_id"] = "nope"
	var problems: PackedStringArray = SaveDocuments.validate_world(document, _catalog)
	assert_eq(problems.size(), 2, "one message per problem: %s" % problems)


# --- validate_profile ------------------------------------------------------------

func test_r_010_12_valid_profile_has_no_problems() -> void:
	var document: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
	assert_eq(SaveDocuments.validate_profile(document).size(), 0)


func test_r_010_12_profile_uuid_must_be_non_empty_string() -> void:
	var empty: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
	empty["player_uuid"] = ""
	assert_eq(SaveDocuments.validate_profile(empty).size(), 1, "empty")
	var number: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
	number["player_uuid"] = 4.0
	assert_gt(SaveDocuments.validate_profile(number).size(), 0, "number")
	var missing: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
	missing.erase("player_uuid")
	assert_gt(SaveDocuments.validate_profile(missing).size(), 0, "missing")


func test_r_010_12_profile_lists_must_be_arrays_of_the_right_kind() -> void:
	for key: String in ["entitlements", "hall_of_fame", "cosmetics", "blueprints"]:
		var not_array: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
		not_array[key] = "text"
		assert_gt(SaveDocuments.validate_profile(not_array).size(), 0, "'%s' not an array" % key)
		var missing: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
		missing.erase(key)
		assert_gt(SaveDocuments.validate_profile(missing).size(), 0, "'%s' missing" % key)
	for key: String in ["entitlements", "cosmetics", "blueprints"]:
		var wrong_items: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
		wrong_items[key] = [1.0, 2.0]
		assert_gt(SaveDocuments.validate_profile(wrong_items).size(), 0, "'%s' with non-text items" % key)
	var bad_fame: Dictionary = _through_json(SaveDocuments.build_profile(ProfileData.create_new()))
	bad_fame["hall_of_fame"] = ["not a dictionary"]
	assert_gt(SaveDocuments.validate_profile(bad_fame).size(), 0, "hall_of_fame items must be objects")


# --- find_repeated_keys ----------------------------------------------------------

func test_r_010_07_repeated_key_found() -> void:
	var keys: Array[StringName] = [&"battery", &"inventory", &"battery"]
	var problems: PackedStringArray = SaveDocuments.find_repeated_keys(keys)
	assert_eq(problems.size(), 1, "one message")
	assert_true(problems[0].contains("battery"), "names the repeated key")


func test_r_010_07_unique_keys_have_no_problems() -> void:
	var keys: Array[StringName] = [&"battery", &"inventory", &"experience"]
	assert_eq(SaveDocuments.find_repeated_keys(keys).size(), 0)
	var none: Array[StringName] = []
	assert_eq(SaveDocuments.find_repeated_keys(none).size(), 0)


func test_r_010_07_each_repeated_key_reported_once() -> void:
	var keys: Array[StringName] = [&"a", &"b", &"a", &"b", &"a"]
	assert_eq(SaveDocuments.find_repeated_keys(keys).size(), 2, "one message per repeated key")
