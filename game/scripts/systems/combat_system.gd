class_name CombatSystem
extends RefCounted
## Pure rules of a melee swing (spec 007, R-007-08): when one may start, when
## its impact arrives and how much it hurts. No nodes, no autoloads: the caller
## passes the elapsed time and the state it depends on.

## Slack for the float sum of physics steps, not a gameplay value: 60 steps of
## 1/60 s must count as one second, not as one step short of it.
const TIME_EPSILON := 1e-6


## Attack data that leaves its owner able to attack: positive damage and rate,
## and a cost that is not negative.
static func is_valid_attack(attack: AttackStatsData) -> bool:
	if attack == null:
		return false
	return attack.damage > 0 and attack.attacks_per_second > 0.0 and attack.battery_cost >= 0.0


## Seconds between the starts of two swings. Only for a valid attack.
static func swing_interval(attack: AttackStatsData) -> float:
	return 1.0 / attack.attacks_per_second


## A swing may start once a full interval has passed since the last one began,
## unless the battery is depleted or the input is blocked (R-007-09).
static func can_start_swing(
	seconds_since_swing: float, attack: AttackStatsData, battery_depleted: bool, input_blocked: bool
) -> bool:
	if battery_depleted or input_blocked or not is_valid_attack(attack):
		return false
	return seconds_since_swing + TIME_EPSILON >= swing_interval(attack)


## True only on the step that takes the swing to, or past, its impact moment.
static func impact_reached(seconds_before: float, seconds_after: float, impact_time_s: float) -> bool:
	return (
		seconds_before + TIME_EPSILON < impact_time_s
		and seconds_after + TIME_EPSILON >= impact_time_s
	)


static func damage_per_hit(attack: AttackStatsData) -> int:
	return attack.damage
