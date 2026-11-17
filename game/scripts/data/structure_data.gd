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
