class_name ZoneData
extends Resource
## Data of one zone of the world (BALANCE.md §7): the base or a farm zone
## (spec 009, architecture §6). ZoneLoader loads the scene of a zone from here.

enum Kind { BASE, FARM }

## Cell of the global zone grid; saved positions are (zone_id, local position).
## It is also the stable id of the zone (architecture §10.3).
@export var zone_id: Vector2i
@export var kind: Kind = Kind.FARM
## A path, not a PackedScene: the scene already references this ZoneData, and
## a PackedScene here would load every zone with the catalog at start-up.
@export_file("*.tscn") var scene_path: String = ""
## Playable area, centred in its grid cell.
@export var size_m: Vector2 = Vector2.ZERO
@export var box_count_min: int = 0
@export var box_count_max: int = 0
## Enemies placed on each visit: a number in [min, max], shared out among the
## entries (ZonePopulation.pick_enemy_spawns).
@export var enemy_count_min: int = 0
@export var enemy_count_max: int = 0
@export var enemy_spawns: Array[EnemySpawnEntryData] = []


## Only farm zones count visits (spec 009, question 12): leaving or dying in
## the base repopulates nothing.
func counts_visits() -> bool:
	return kind == Kind.FARM
