class_name StatIds
extends RefCounted
## Ids of the robot's stats (spec 015, plan D1): the field names of
## RobotBaseStatsData and the stat of every StatModifier. Stable: modifiers in
## .tres name them.

const WALK_SPEED := &"walk_speed"
## 0 means the robot cannot run (plan 015 D2).
const RUN_SPEED := &"run_speed"
const WALK_DRAIN := &"walk_drain"
const RUN_DRAIN := &"run_drain"
const PASSIVE_DRAIN := &"passive_drain"
const MAX_BATTERY := &"max_battery"
const ATTACK_DAMAGE := &"attack_damage"
const ATTACKS_PER_SECOND := &"attacks_per_second"
const BATTERY_PER_SWING := &"battery_per_swing"
const DURABILITY_PER_HIT := &"durability_per_hit"

## Every id, in RobotBaseStatsData field order.
const ALL: Array[StringName] = [
	WALK_SPEED, RUN_SPEED, WALK_DRAIN, RUN_DRAIN, PASSIVE_DRAIN, MAX_BATTERY,
	ATTACK_DAMAGE, ATTACKS_PER_SECOND, BATTERY_PER_SWING, DURABILITY_PER_HIT,
]
