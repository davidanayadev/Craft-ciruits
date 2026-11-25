class_name MovementStatsData
extends Resource
## Movement numbers of the robot (BALANCE.md §4.2): a value object that
## StatsComponent builds from the stats of its equipped legs, or of no legs
## (spec 015, plan D4). Never a .tres: each number lives in the base stats or a
## piece. can_run is derived: run_speed > 0 (plan 015 D2).

@export var walk_speed: float = 0.0
@export var run_speed: float = 0.0
@export var can_run: bool = false
## Battery points per second spent while walking on these legs.
@export var walk_drain: float = 0.0
