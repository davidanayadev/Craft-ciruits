class_name RepairTierData
extends Resource
## One repair cost tier (spec 011, BALANCE §4.3.2): what repairing a piece
## costs while its durability left is at most up_to_percent of its maximum.

## Highest durability left, in percent of the maximum, this tier covers (inclusive).
@export var up_to_percent: int = 0
@export var ingredients: Array[RecipeIngredientData] = []
