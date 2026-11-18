class_name ItemData
extends Resource
## One kind of item (BALANCE.md §2). Later specs add fields as they need them
## (PieceData extends it in spec 011).

## snake_case and stable forever: saves and the network only use ids
## (architecture §8). Never rename a published id.
@export var id: StringName
## Translation key of the player-visible name (ITEM_SCRAP…).
@export var name_key: StringName
## Largest quantity one inventory slot holds.
@export var stack_max: int = 0
## Shown in inventory cells. Required: the catalog test rejects an item without one (R-005-31).
@export var icon: Texture2D
