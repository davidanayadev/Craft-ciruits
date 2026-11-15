class_name BatteryConfigData
extends Resource
## General battery numbers of the robot (BALANCE.md §1.1). The maximum is the
## basic Core's (§4.2); spec 014 will move it to the equipped Core.

## Points.
@export var maximum: float = 0.0
## Points per second, always while any charge remains.
@export var passive_drain: float = 0.0
## Points per second while running; replaces the legs' walk_drain.
@export var run_drain: float = 0.0
## Fraction of the maximum below which the battery counts as low.
@export var low_threshold_ratio: float = 0.0
