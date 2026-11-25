class_name AttackStatsData
extends Resource
## Melee numbers of the robot's arms (BALANCE.md §4.2): a value object that
## StatsComponent builds from the stats of its equipped arms, or of one arm
## (spec 015, plan D4). Never a .tres: each number lives in the base stats or a piece.

## HP taken from each enemy the swing hits.
@export var damage: int = 0
@export var attacks_per_second: float = 0.0
## Battery points per swing, whether it hits or not (BALANCE §1.1).
@export var battery_cost: float = 0.0
