class_name StructureData
extends Resource
## A structure that can be placed on the base grid (spec 009, BALANCE.md §5.6):
## the charging station now, the generator and the chests with spec 012.
## Structures never rotate in the MVP.

## snake_case and stable forever: saves only use ids (architecture §8).
@export var id: StringName
## Translation key of the player-visible name.
@export var name_key: StringName
@export var scene: PackedScene
## Cells it covers (x, z), counted from the cell it is placed on.
@export var footprint: Vector2i = Vector2i.ONE
## How many can stand in the base at once (BALANCE §5.2, §5.4); 0 = no limit (R-012-03).
@export var max_count: int = 0
