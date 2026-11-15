class_name MovementStatsData
extends Resource
## Movement numbers of the equipped legs (BALANCE.md §4.2).
## Spec 014 will derive these from StatsComponent modifiers; until then the
## robot points at one .tres instance (basic legs).

@export var walk_speed: float = 0.0
@export var run_speed: float = 0.0
@export var can_run: bool = false
## Battery points per second spent while walking on these legs.
@export var walk_drain: float = 0.0
