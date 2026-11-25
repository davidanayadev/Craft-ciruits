class_name PieceData
extends ItemData
## A robot piece (spec 011): a unique inventory item with its own uid and
## durability in its ItemStack. Spec 015 adds the equipment slot it fits and
## its stats as modifiers, applied only while it is equipped (R-015-05).

enum SlotType { ARMS, LEGS, CORE }

## BALANCE §4.1. Its stack_max is always 1 (a catalog test guards it).
@export var durability_max: int = 0
@export var slot_type: SlotType = SlotType.ARMS
## Its row of BALANCE §4.2 (plan 015 D3).
@export var modifiers: Array[StatModifier] = []
