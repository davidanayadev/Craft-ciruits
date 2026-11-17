class_name ProfileData
extends RefCounted
## The Profile in memory (spec 010, R-010-12): what outlives every World. It
## holds no state of a world or of a robot (R-010-16). Hall of fame,
## cosmetics and blueprints stay empty in the MVP; entitlements are written
## only by the store of v1.1 (R-010-60).

## Locally generated, never changes once created (R-010-14).
var player_uuid: String = ""
var entitlements: PackedStringArray = PackedStringArray()
var hall_of_fame: Array[Dictionary] = []
var cosmetics: PackedStringArray = PackedStringArray()
var blueprints: PackedStringArray = PackedStringArray()


## A new Profile with a new player_uuid (architecture §10.3) and empty lists.
static func create_new() -> ProfileData:
	var profile: ProfileData = ProfileData.new()
	profile.player_uuid = Uid.generate()
	return profile


## Shares nothing with this one.
func copy() -> ProfileData:
	var other: ProfileData = ProfileData.new()
	other.player_uuid = player_uuid
	other.entitlements = entitlements.duplicate()
	other.hall_of_fame = hall_of_fame.duplicate(true)
	other.cosmetics = cosmetics.duplicate()
	other.blueprints = blueprints.duplicate()
	return other
