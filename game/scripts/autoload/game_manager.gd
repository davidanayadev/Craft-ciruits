extends Node
## Autoload "GameManager": global state of the current game (architecture §5):
## the world seed, its ruleset, the visit counter of each zone and the zone
## that is loaded (spec 009), plus access to the clock. Never per-player state (PMV §4.5 hook 7). No class_name: it
## would clash with the autoload name.
## Nothing here is saved yet: spec 010 reads the seed, the ruleset id and the
## counters from the World file.

## The visit counter of a zone went up (spec 008). Whoever has that zone
## loaded repopulates it.
signal zone_visit_changed(zone_id: Vector2i, visit: int)

const DEV_WORLD_PATH := "res://resources/config/dev_world.tres"

var _world_seed: int = 0
var _ruleset: RulesetData
## Zones that are missing are on their first visit.
var _visit_counts: Dictionary[Vector2i, int] = {}
var _time_service: ITimeService = LocalTimeService.new()
## Set only by ZoneLoader, when a travel ends (R-009-09).
var _current_zone_id: Vector2i = Vector2i.ZERO
var _has_current_zone: bool = false


func _ready() -> void:
	var dev_world: DevWorldConfigData = load(DEV_WORLD_PATH) as DevWorldConfigData
	if dev_world == null:
		push_error("GameManager: %s is missing or is not a DevWorldConfigData." % DEV_WORLD_PATH)
		return
	_world_seed = dev_world.world_seed
	_ruleset = DataRegistry.get_ruleset(dev_world.ruleset_id)


func get_world_seed() -> int:
	return _world_seed


## How this world reacts to a death; read its fields, never its id.
func get_ruleset() -> RulesetData:
	return _ruleset


## The only clock of the game (architecture §10.1).
func get_time_service() -> ITimeService:
	return _time_service


## Entering or generating a zone never counts a visit (BALANCE §7.2).
func get_visit_count(zone_id: Vector2i) -> int:
	return _visit_counts.get(zone_id, ZonePopulation.FIRST_VISIT)


## Returns the new count.
func increment_visit_count(zone_id: Vector2i) -> int:
	var visit: int = get_visit_count(zone_id) + 1
	_visit_counts[zone_id] = visit
	zone_visit_changed.emit(zone_id, visit)
	return visit


## A new world starts with no visits (spec 010); tests isolate with it.
func clear_visit_counts() -> void:
	_visit_counts.clear()


## False until the first travel ends.
func has_current_zone() -> bool:
	return _has_current_zone


## Meaningless before has_current_zone().
func get_current_zone_id() -> Vector2i:
	return _current_zone_id


## Only ZoneLoader calls it (a test guards it). Counts no visit.
func set_current_zone(zone_id: Vector2i) -> void:
	_current_zone_id = zone_id
	_has_current_zone = true
