class_name ZoneMemory
extends Node
## What happened in the visit in progress of each farm zone (spec 010,
## R-010-27, R-010-32): which boxes are open and what is left inside, and which
## enemies are dead. World state (constitution P4) under World, like
## DroppedItemSpawner and BaseStructures, so it outlives the zone scene.
## The state belongs to one visit: when the visit counter of a zone goes up it
## is dropped (R-010-28). The visit is read from the zone itself, never from
## GameManager: between the count and the deferred repopulation they differ.

const SAVE_KEY := &"farm_visits"
const _ZONES_KEY := "zones"
const _ZONE_ID_KEY := "zone_id"
const _VISIT_KEY := "visit"
const _STATE_KEY := "state"

## zone_id → {"visit": int, "state": FarmZone.get_visit_state()}.
var _kept: Dictionary[Vector2i, Dictionary] = {}
var _bound: FarmZone = null


func _ready() -> void:
	GameManager.zone_visit_counted.connect(_on_zone_visit_counted)


## The farm zone that is loaded now; its live state is read when saved.
func bind_farm(farm: FarmZone) -> void:
	_bound = farm


## The bound farm is being unloaded: its state is kept under its visit.
## ZoneLoader calls it before despawning its enemies.
func unbind_farm() -> void:
	if _bound == null:
		return
	_kept[_bound.data.zone_id] = {_VISIT_KEY: _bound.get_visit(), _STATE_KEY: _bound.get_visit_state()}
	_bound = null


## The kept state of zone_id when it is of that visit, then forgotten; else {}.
func take_state(zone_id: Vector2i, visit: int) -> Dictionary:
	var kept: Dictionary = _kept.get(zone_id, {})
	_kept.erase(zone_id)
	if kept.is_empty() or SaveFields.to_int(kept.get(_VISIT_KEY), -1) != visit:
		return {}
	var state: Dictionary = kept[_STATE_KEY]
	return state


func get_save_key() -> StringName:
	return SAVE_KEY


## Every kept zone plus the live state of the bound farm, in zone order.
func to_save_data() -> Dictionary:
	var entries: Dictionary[Vector2i, Dictionary] = _kept.duplicate(true)
	if _bound != null:
		entries[_bound.data.zone_id] = {_VISIT_KEY: _bound.get_visit(), _STATE_KEY: _bound.get_visit_state()}
	var zone_ids: Array[Vector2i] = []
	zone_ids.assign(entries.keys())
	zone_ids.sort()
	var zones: Array = []
	for zone_id: Vector2i in zone_ids:
		zones.append({
			_ZONE_ID_KEY: SaveFields.vector2i_to_array(zone_id),
			_VISIT_KEY: entries[zone_id][_VISIT_KEY],
			_STATE_KEY: entries[zone_id][_STATE_KEY],
		})
	return {_ZONES_KEY: zones}


## Replaces what is kept; emits nothing. An entry of a zone the catalog does
## not know, or malformed → push_error and skipped (R-010-11).
func from_save_data(data: Dictionary) -> void:
	var zones: Variant = data.get(_ZONES_KEY)
	if not zones is Array:
		push_error("ZoneMemory '%s': no saved zones in %s; nothing kept." % [name, data])
		return
	_kept.clear()
	var catalog: DataCatalog = DataRegistry.get_catalog()
	for entry: Variant in zones as Array:
		var fields: Dictionary = entry if entry is Dictionary else {}
		var zone_id: Variant = SaveFields.to_vector2i(fields.get(_ZONE_ID_KEY))
		var visit: int = SaveFields.to_int(fields.get(_VISIT_KEY), -1)
		var state: Variant = fields.get(_STATE_KEY)
		var known: bool = zone_id != null and catalog != null and catalog.has_zone(zone_id as Vector2i)
		if not known or visit < ZonePopulation.FIRST_VISIT or not state is Dictionary:
			push_error("ZoneMemory '%s': saved zone state %s is lost." % [name, entry])
			continue
		_kept[zone_id as Vector2i] = {_VISIT_KEY: visit, _STATE_KEY: state}


func _on_zone_visit_counted(zone_id: Vector2i, _visit: int) -> void:
	_kept.erase(zone_id)
