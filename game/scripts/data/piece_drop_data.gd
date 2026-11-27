class_name PieceDropData
extends Resource
## The piece an enemy may drop when a player kills it (BALANCE §3.2, spec 016).
## Percentages on the scale of CraftingSystem.PERCENT, so 15 % and 50 % are
## exact. The order of pieces is a contract with saved worlds: changing it
## changes the drop of the enemies of a saved visit.

## Chance of dropping one piece, 0..100.
@export var chance_percent: int = 0
## One of these, with equal chance; never empty while chance_percent > 0.
@export var pieces: Array[PieceData] = []
## Durability the piece keeps, as a percentage of its durability_max, 1..100.
@export var durability_percent: int = 0
