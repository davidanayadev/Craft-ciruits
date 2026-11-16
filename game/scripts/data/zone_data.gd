class_name ZoneData
extends Resource
## Data of one zone of the world (BALANCE.md §7). Later specs extend it: scene
## and BASE/FARM kind (spec 009, architecture §6).

## Cell of the global zone grid; saved positions are (zone_id, local position).
@export var zone_id: Vector2i
## Playable area, centred in its grid cell.
@export var size_m: Vector2 = Vector2.ZERO
@export var box_count_min: int = 0
@export var box_count_max: int = 0
## Enemies placed on each visit: a number in [min, max], shared out among the
## entries (ZonePopulation.pick_enemy_spawns).
@export var enemy_count_min: int = 0
@export var enemy_count_max: int = 0
@export var enemy_spawns: Array[EnemySpawnEntryData] = []
