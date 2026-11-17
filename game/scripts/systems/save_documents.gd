class_name SaveDocuments
extends RefCounted
## The Profile and World documents (spec 010, plan §3): built from the parts of
## their owners, validated and split again. Pure: no files, no scene tree
## (R-010-05). The World header is the document's own schema, owned by no
## component; every other key is a part, under its player's uid (R-010-22) or
## under "world", keyed by its owner's save key.

## Every owner of persisted state is in this group (architecture §10.2).
const PERSISTENT_GROUP := &"persistent"

const KEY_SCHEMA_VERSION := SaveMigrations.VERSION_KEY
const KEY_WORLD_ID := "world_id"
const KEY_NAME := "name"
const KEY_SEED := "seed"
const KEY_RULESET_ID := "ruleset_id"
const KEY_SAVED_AT := "saved_at"
const KEY_PLAYERS := "players"
const KEY_WORLD := "world"

const KEY_PLAYER_UUID := "player_uuid"
const KEY_ENTITLEMENTS := "entitlements"
const KEY_HALL_OF_FAME := "hall_of_fame"
const KEY_COSMETICS := "cosmetics"
const KEY_BLUEPRINTS := "blueprints"


class WorldHeader:
	var world_id: String = ""
	var world_name: String = ""
	var world_seed: int = 0
	var ruleset_id: StringName = &""
	var saved_at_unix: int = 0


## The seed goes as decimal text (plan D3): a JSON number is a float and a
## 64-bit seed would lose precision.
static func build_world(
	header: WorldHeader, players: Dictionary[String, Dictionary], world: Dictionary[String, Dictionary]
) -> Dictionary:
	return {
		KEY_SCHEMA_VERSION: SaveMigrations.WORLD_VERSION,
		KEY_WORLD_ID: header.world_id,
		KEY_NAME: header.world_name,
		KEY_SEED: str(header.world_seed),
		KEY_RULESET_ID: String(header.ruleset_id),
		KEY_SAVED_AT: header.saved_at_unix,
		KEY_PLAYERS: _untyped(players),
		KEY_WORLD: _untyped(world),
	}


static func build_profile(profile: ProfileData) -> Dictionary:
	return {
		KEY_SCHEMA_VERSION: SaveMigrations.PROFILE_VERSION,
		KEY_PLAYER_UUID: profile.player_uuid,
		KEY_ENTITLEMENTS: Array(profile.entitlements),
		KEY_HALL_OF_FAME: profile.hall_of_fame.duplicate(true),
		KEY_COSMETICS: Array(profile.cosmetics),
		KEY_BLUEPRINTS: Array(profile.blueprints),
	}


## Empty when valid; one message per problem. The ruleset id must be in the catalog.
static func validate_world(document: Dictionary, catalog: DataCatalog) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	_check_version(document, problems)
	_check_text(document, KEY_WORLD_ID, false, problems)
	_check_text(document, KEY_NAME, true, problems)
	var world_seed: Variant = document.get(KEY_SEED)
	if not world_seed is String or not (world_seed as String).is_valid_int():
		problems.append("'%s' is not an integer written as text" % KEY_SEED)
	var ruleset_id: Variant = document.get(KEY_RULESET_ID)
	if not ruleset_id is String:
		problems.append("'%s' is not text" % KEY_RULESET_ID)
	elif catalog == null or not catalog.has_ruleset(StringName(ruleset_id as String)):
		problems.append("ruleset '%s' is not in the catalog" % ruleset_id)
	if not SaveFields.is_whole_number(document.get(KEY_SAVED_AT)):
		problems.append("'%s' is not a whole number" % KEY_SAVED_AT)
	_check_players(document.get(KEY_PLAYERS), problems)
	_check_parts(document.get(KEY_WORLD), KEY_WORLD, problems)
	return problems


static func validate_profile(document: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	_check_version(document, problems)
	_check_text(document, KEY_PLAYER_UUID, false, problems)
	for key: String in [KEY_ENTITLEMENTS, KEY_COSMETICS, KEY_BLUEPRINTS]:
		if not _is_list_of(document.get(key), TYPE_STRING):
			problems.append("'%s' is not a list of text" % key)
	if not _is_list_of(document.get(KEY_HALL_OF_FAME), TYPE_DICTIONARY):
		problems.append("'%s' is not a list of objects" % KEY_HALL_OF_FAME)
	return problems


## Of a validated document.
static func read_header(document: Dictionary) -> WorldHeader:
	var header: WorldHeader = WorldHeader.new()
	header.world_id = str(document[KEY_WORLD_ID])
	header.world_name = str(document[KEY_NAME])
	header.world_seed = str(document[KEY_SEED]).to_int()
	header.ruleset_id = StringName(str(document[KEY_RULESET_ID]))
	header.saved_at_unix = SaveFields.to_int(document[KEY_SAVED_AT], 0)
	return header


## player_uid → {save key → part}, of a validated document.
static func read_players(document: Dictionary) -> Dictionary[String, Dictionary]:
	var players: Dictionary[String, Dictionary] = {}
	var source: Dictionary = document[KEY_PLAYERS]
	for player_uid: Variant in source:
		var parts: Dictionary = source[player_uid]
		players[str(player_uid)] = parts
	return players


## save key → part of the world owners, of a validated document.
static func read_world_parts(document: Dictionary) -> Dictionary[String, Dictionary]:
	var parts: Dictionary[String, Dictionary] = {}
	var source: Dictionary = document[KEY_WORLD]
	for key: Variant in source:
		var part: Dictionary = source[key]
		parts[str(key)] = part
	return parts


## Of a validated document.
static func read_profile(document: Dictionary) -> ProfileData:
	var profile: ProfileData = ProfileData.new()
	profile.player_uuid = str(document[KEY_PLAYER_UUID])
	profile.entitlements = PackedStringArray(document[KEY_ENTITLEMENTS] as Array)
	profile.cosmetics = PackedStringArray(document[KEY_COSMETICS] as Array)
	profile.blueprints = PackedStringArray(document[KEY_BLUEPRINTS] as Array)
	for entry: Variant in document[KEY_HALL_OF_FAME] as Array:
		var record: Dictionary = entry
		profile.hall_of_fame.append(record.duplicate(true))
	return profile


## One message per key that appears more than once within one scope (a
## player or the world), so two owners never overwrite each other (R-010-07).
static func find_repeated_keys(keys: Array[StringName]) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary[StringName, int] = {}
	for key: StringName in keys:
		seen[key] = seen.get(key, 0) + 1
	for key: StringName in seen:
		if seen[key] > 1:
			problems.append("save key '%s' is used by %d owners" % [key, seen[key]])
	return problems


static func _check_version(document: Dictionary, problems: PackedStringArray) -> void:
	if SaveFields.to_int(document.get(KEY_SCHEMA_VERSION), 0) < 1:
		problems.append("'%s' is not a whole number >= 1" % KEY_SCHEMA_VERSION)


static func _check_text(
	document: Dictionary, key: String, may_be_empty: bool, problems: PackedStringArray
) -> void:
	var value: Variant = document.get(key)
	if not value is String or (not may_be_empty and (value as String).is_empty()):
		problems.append("'%s' is not %stext" % [key, "" if may_be_empty else "non-empty "])


static func _check_players(players: Variant, problems: PackedStringArray) -> void:
	if not players is Dictionary:
		problems.append("'%s' is not an object" % KEY_PLAYERS)
		return
	var by_uid: Dictionary = players
	for player_uid: Variant in by_uid:
		_check_parts(by_uid[player_uid], "%s.%s" % [KEY_PLAYERS, player_uid], problems)


## An object whose every value is an object (a part of one owner).
static func _check_parts(parts: Variant, where: String, problems: PackedStringArray) -> void:
	if not parts is Dictionary:
		problems.append("'%s' is not an object" % where)
		return
	var by_key: Dictionary = parts
	for key: Variant in by_key:
		if not by_key[key] is Dictionary:
			problems.append("'%s.%s' is not an object" % [where, key])


static func _is_list_of(value: Variant, type: Variant.Type) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value as Array:
		if typeof(entry) != type:
			return false
	return true


## The document holds plain dictionaries, as JSON gives them back.
static func _untyped(typed: Dictionary) -> Dictionary:
	var plain: Dictionary = {}
	for key: Variant in typed:
		plain[key] = typed[key]
	return plain
