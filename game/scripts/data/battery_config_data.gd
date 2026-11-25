class_name BatteryConfigData
extends Resource
## General battery numbers of the robot (BALANCE.md §1.1). The maximum and the
## drain rates are stats since spec 015 (RobotBaseStatsData and the pieces).

## Fraction of the maximum below which the battery counts as low.
@export var low_threshold_ratio: float = 0.0
