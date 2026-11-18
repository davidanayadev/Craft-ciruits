class_name PieceData
extends ItemData
## A robot piece (spec 011): a unique inventory item with its own uid and
## durability in its ItemStack. Spec 014 adds slot_type and modifiers.

## BALANCE §4.1. Its stack_max is always 1 (a catalog test guards it).
@export var durability_max: int = 0
