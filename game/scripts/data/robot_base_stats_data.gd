class_name RobotBaseStatsData
extends Resource
## Stats of the robot with no piece equipped (spec 015, R-015-02): one arm, no
## legs, no Core (BALANCE §4.2), plus the running drain (§1.1) and the wear per
## hit received (§4.1). Equipped pieces change them through their modifiers.
## One field per StatIds constant, with the same name.

## Metres per second.
@export var walk_speed: float = 0.0
## Metres per second; 0 means it cannot run (plan 015 D2).
@export var run_speed: float = 0.0
## Battery points per second while walking.
@export var walk_drain: float = 0.0
## Battery points per second while running; replaces walk_drain.
@export var run_drain: float = 0.0
## Battery points per second, always while any charge remains.
@export var passive_drain: float = 0.0
## Battery points.
@export var max_battery: float = 0.0
## HP taken from each enemy a swing hits.
@export var attack_damage: float = 0.0
@export var attacks_per_second: float = 0.0
## Battery points per swing, hit or miss.
@export var battery_per_swing: float = 0.0
## Durability an equipped piece loses per hit received.
@export var durability_per_hit: float = 0.0


## Stat id → value, one entry per field.
func to_stats() -> Dictionary[StringName, float]:
	var stats: Dictionary[StringName, float] = {}
	for stat: StringName in StatIds.ALL:
		var value: float = get(stat)
		stats[stat] = value
	return stats
