class_name RepairCostData
extends Resource
## The repair cost tiers of BALANCE §4.3.2 (spec 011, R-011-06). CraftingSystem
## picks the first tier that covers a piece's durability left.

## Ascending by up_to_percent; the last one is 100 (a catalog test guards both).
@export var tiers: Array[RepairTierData] = []
