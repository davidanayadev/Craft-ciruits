class_name LocationComponent
extends Node
## Where its player stands, as (zone_id, local position) (spec 010, R-010-23,
## PMV §4.5 hook 2): per-player state (constitution P4), a child of the player
## entity. The position is read from its parent when saved, local to the root
## of the zone it entered, so it survives the zone being loaded elsewhere.
## A loaded location waits here until the player enters a zone; who travels
## there decides whether it is still usable (R-010-36).

const SAVE_KEY := &"location"
const _ZONE_ID_KEY := "zone_id"
const _POSITION_KEY := "position"

var _zone_id: Vector2i = Vector2i.ZERO
var _zone_root: Node3D = null
var _has_restored: bool = false
var _restored_zone_id: Vector2i = Vector2i.ZERO
var _restored_position: Vector3 = Vector3.ZERO


## The player now stands in zone_id; positions are local to zone_root. A
## restored location is spent.
func enter(zone_id: Vector2i, zone_root: Node3D) -> void:
	_zone_id = zone_id
	_zone_root = zone_root
	_has_restored = false


func has_restored_location() -> bool:
	return _has_restored


## Meaningless unless has_restored_location().
func get_restored_zone_id() -> Vector2i:
	return _restored_zone_id


## Meaningless unless has_restored_location().
func get_restored_local_position() -> Vector3:
	return _restored_position


func get_save_key() -> StringName:
	return SAVE_KEY


## The live location while in a zone; the restored one before entering any;
## {} if neither (a new player).
func to_save_data() -> Dictionary:
	var player: Node3D = get_parent() as Node3D
	if player != null and is_instance_valid(_zone_root) and _zone_root.is_inside_tree():
		return _location_data(_zone_id, _zone_root.to_local(player.global_position))
	if _has_restored:
		return _location_data(_restored_zone_id, _restored_position)
	return {}


## {} is a player that never entered a zone: nothing to restore. Anything
## else malformed → push_error, nothing restored. Emits nothing.
func from_save_data(data: Dictionary) -> void:
	_has_restored = false
	if data.is_empty():
		return
	var zone_id: Variant = SaveFields.to_vector2i(data.get(_ZONE_ID_KEY))
	var local_position: Variant = SaveFields.to_vector3(data.get(_POSITION_KEY))
	if zone_id == null or local_position == null:
		push_error("LocationComponent '%s': malformed saved location %s; none restored." % [name, data])
		return
	_restored_zone_id = zone_id
	_restored_position = local_position
	_has_restored = true


static func _location_data(zone_id: Vector2i, local_position: Vector3) -> Dictionary:
	return {
		_ZONE_ID_KEY: SaveFields.vector2i_to_array(zone_id),
		_POSITION_KEY: SaveFields.vector3_to_array(local_position),
	}
