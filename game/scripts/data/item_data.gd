class_name ItemData
extends Resource
## One kind of item (BALANCE.md §2). Later specs add fields as they need them
## (PieceData extends it in spec 014).

## snake_case and stable forever: saves and the network only use ids
## (architecture §8). Never rename a published id.
@export var id: StringName
## Translation key of the player-visible name (ITEM_SCRAP…).
@export var name_key: StringName
## Largest quantity one inventory slot holds.
@export var stack_max: int = 0
