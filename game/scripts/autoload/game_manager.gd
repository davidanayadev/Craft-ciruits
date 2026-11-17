extends Node
## Autoload "GameManager": global state of the current game (architecture §5):
## the World it plays (id, name, seed and ruleset, spec 010), the visit
## counter of each zone and the zone that is loaded (spec 009), plus access to
## the clock and the store. Never per-player state (PMV §4.5 hook 7). No
## class_name: it would clash with the autoload name.
## SaveManager gives it the World with begin_world() when one is loaded or
## created; it owns the visit counters in the save (zone_visits).

## A visit of the zone was counted (spec 008): a fact, never emitted on load
## (spec 010, D15). Whoever has that zone loaded repopulates it.
signal zone_visit_counted(zone_id: Vector2i, visit: int)

## Save contract (spec 010, architecture §10.2): world state, in the
## persistent group without being under a player.
const SAVE_KEY := &"zone_visits"
const _ZONES_KEY := "zones"
const _ZONE_ID_KEY := "zone_id"
const _VISIT_KEY := "visit"

var _world_id: String = ""
var _world_name: String = ""
var _world_seed: int = 0
var _ruleset: RulesetData
## Zones that are missing are on their first visit.
var _visit_counts: Dictionary[Vector2i, int] = {}
var _time_service: ITimeService = LocalTimeService.new()
## Always the demo in the MVP (spec 010, plan D1); native billing in v1.1.
var _store: IStore = LocalStore.new()
## Set only by ZoneLoader, when a travel ends (R-009-09).
var _current_zone_id: Vector2i = Vector2i.ZERO
var _has_current_zone: bool = false


func _ready() -> void:
	add_to_group(SaveDocuments.PERSISTENT_GROUP)


## The World being played, from its file or just created (R-010-20). Only
## SaveManager calls it (a test guards it). Clears the visit counters and the
## current zone: nothing of the previous World stays.
func begin_world(world_id: String, world_name: String, world_seed: int, ruleset: RulesetData) -> void:
	_world_id = world_id
	_world_name = world_name
	_world_seed = world_seed
	_ruleset = ruleset
	_visit_counts.clear()
	_current_zone_id = Vector2i.ZERO
	_has_current_zone = false


## Empty before a World begins.
func get_world_id() -> String:
	return _world_id


func get_world_name() -> String:
	return _world_name


func get_world_seed() -> int:
	return _world_seed


## How this world reacts to a death; read its fields, never its id.
func get_ruleset() -> RulesetData:
	return _ruleset


## The only clock of the game (architecture §10.1).
func get_time_service() -> ITimeService:
	return _time_service


## The only store of the game (architecture §10.1, R-010-58).
func get_store() -> IStore:
	return _store


## Entering or generating a zone never counts a visit (BALANCE §7.2).
func get_visit_count(zone_id: Vector2i) -> int:
	return _visit_counts.get(zone_id, ZonePopulation.FIRST_VISIT)


## Returns the new count.
func increment_visit_count(zone_id: Vector2i) -> int:
	var visit: int = get_visit_count(zone_id) + 1
	_visit_counts[zone_id] = visit
	zone_visit_counted.emit(zone_id, visit)
	return visit


## Tests isolate with it; a new World clears them through begin_world().
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


func get_save_key() -> StringName:
	return SAVE_KEY


## Every counted zone, in zone order so the same counters give the same data.
func to_save_data() -> Dictionary:
	var zone_ids: Array[Vector2i] = []
	zone_ids.assign(_visit_counts.keys())
	zone_ids.sort()
	var zones: Array = []
	for zone_id: Vector2i in zone_ids:
		zones.append({
			_ZONE_ID_KEY: SaveFields.vector2i_to_array(zone_id),
			_VISIT_KEY: _visit_counts[zone_id],
		})
	return {_ZONES_KEY: zones}


## Replaces the counters and emits nothing: loading counts no visit
## (R-010-26, D15). A malformed entry → push_error, that zone stays at its
## first visit.
func from_save_data(data: Dictionary) -> void:
	var zones: Variant = data.get(_ZONES_KEY)
	if not zones is Array:
		push_error("GameManager: no saved visit counters in %s; none loaded." % data)
		return
	_visit_counts.clear()
	for entry: Variant in zones as Array:
		var fields: Dictionary = entry if entry is Dictionary else {}
		var zone_id: Variant = SaveFields.to_vector2i(fields.get(_ZONE_ID_KEY))
		var visit: int = SaveFields.to_int(fields.get(_VISIT_KEY), -1)
		if zone_id == null or visit < ZonePopulation.FIRST_VISIT:
			push_error("GameManager: saved visit counter %s is lost." % entry)
			continue
		_visit_counts[zone_id as Vector2i] = visit
