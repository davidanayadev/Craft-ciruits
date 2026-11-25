class_name StatsCalculator
extends RefCounted
## Pure stat rules (spec 015, architecture §9.4): a base and a list of
## modifiers give the final stats. No nodes, no autoloads.

const _ORDER: Array[StatModifier.Op] = [
	StatModifier.Op.SET, StatModifier.Op.ADD, StatModifier.Op.MULTIPLY,
]


## A new dictionary: every SET, then every ADD, then every MULTIPLY, each in
## list order (R-015-03). Inputs never change. A null modifier or a stat the
## base lacks → push_error, skipped (R-015-04).
static func compute(
	base: Dictionary[StringName, float], modifiers: Array[StatModifier]
) -> Dictionary[StringName, float]:
	var stats: Dictionary[StringName, float] = base.duplicate()
	var valid: Array[StatModifier] = _valid_modifiers(base, modifiers)
	for op: StatModifier.Op in _ORDER:
		for modifier: StatModifier in valid:
			if modifier.op == op:
				stats[modifier.stat] = _apply(stats[modifier.stat], modifier)
	return stats


static func _valid_modifiers(
	base: Dictionary[StringName, float], modifiers: Array[StatModifier]
) -> Array[StatModifier]:
	var valid: Array[StatModifier] = []
	for modifier: StatModifier in modifiers:
		if modifier == null:
			push_error("StatsCalculator: a null modifier is skipped.")
		elif not base.has(modifier.stat):
			push_error("StatsCalculator: the modifier of unknown stat '%s' is skipped." % modifier.stat)
		else:
			valid.append(modifier)
	return valid


static func _apply(value: float, modifier: StatModifier) -> float:
	match modifier.op:
		StatModifier.Op.SET:
			return modifier.value
		StatModifier.Op.ADD:
			return value + modifier.value
	return value * modifier.value
