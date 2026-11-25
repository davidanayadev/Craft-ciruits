class_name StatsComponent
extends Node
## Final stats of one entity (spec 015, architecture §9.4): its base stats
## with the modifiers its entity gives it, computed by StatsCalculator.
## Per-entity state (constitution P4). It never looks at pieces: Robot passes
## the modifiers of its equipment and hands the typed views to movement,
## attack and battery (plan 015 D5), so none of them reads pieces (R-015-14).

## State: the stats were computed again (R-015-13). Once per recompute().
signal stats_changed

@export var base_stats: RobotBaseStatsData

var _stats: Dictionary[StringName, float] = {}


func _ready() -> void:
	if base_stats == null:
		push_error("StatsComponent '%s': base_stats must be assigned." % name)
		return
	_stats = base_stats.to_stats()


## The base stats with modifiers (R-015-05); stats_changed once.
func recompute(modifiers: Array[StatModifier]) -> void:
	if base_stats == null:
		push_error("StatsComponent '%s': cannot recompute without base_stats." % name)
		return
	_stats = StatsCalculator.compute(base_stats.to_stats(), modifiers)
	stats_changed.emit()


## The base stats until the first recompute(). Unknown id → push_error, 0.0.
func get_stat(stat: StringName) -> float:
	if not _stats.has(stat):
		push_error("StatsComponent '%s': unknown stat '%s'." % [name, stat])
		return 0.0
	return _stats[stat]


## A new value object each call; can_run = run_speed > 0 (plan 015 D2).
func get_movement() -> MovementStatsData:
	var movement: MovementStatsData = MovementStatsData.new()
	movement.walk_speed = get_stat(StatIds.WALK_SPEED)
	movement.run_speed = get_stat(StatIds.RUN_SPEED)
	movement.can_run = movement.run_speed > 0.0
	movement.walk_drain = get_stat(StatIds.WALK_DRAIN)
	return movement


## A new value object each call; the damage is a whole number (plan 015 §7).
func get_attack() -> AttackStatsData:
	var attack: AttackStatsData = AttackStatsData.new()
	attack.damage = roundi(get_stat(StatIds.ATTACK_DAMAGE))
	attack.attacks_per_second = get_stat(StatIds.ATTACKS_PER_SECOND)
	attack.battery_cost = get_stat(StatIds.BATTERY_PER_SWING)
	return attack
