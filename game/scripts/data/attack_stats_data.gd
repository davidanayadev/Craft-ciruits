class_name AttackStatsData
extends Resource
## Melee numbers of the robot's arms (BALANCE.md §4.2). Spec 015 will derive
## these from StatsComponent modifiers; until then the robot points at one
## .tres instance (one arm).

## HP taken from each enemy the swing hits.
@export var damage: int = 0
@export var attacks_per_second: float = 0.0
## Battery points per swing, whether it hits or not (BALANCE §1.1).
@export var battery_cost: float = 0.0
