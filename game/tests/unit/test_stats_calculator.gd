extends GutTest
## StatsCalculator (spec 015): pure, every SET, then every ADD, then every
## MULTIPLY, without changing its inputs (R-015-03); a modifier of a stat the
## base lacks, or a null one, is skipped and reported (R-015-04).


func _modifier(stat: StringName, op: StatModifier.Op, value: float) -> StatModifier:
	var modifier: StatModifier = StatModifier.new()
	modifier.stat = stat
	modifier.op = op
	modifier.value = value
	return modifier


func _base() -> Dictionary[StringName, float]:
	return {&"speed": 1.0, &"damage": 5.0, &"drain": 0.2}


func test_r_015_03_set_then_add_then_multiply() -> void:
	# Listed in the wrong order on purpose: the operation decides, not the list.
	var modifiers: Array[StatModifier] = [
		_modifier(&"speed", StatModifier.Op.MULTIPLY, 2.0),
		_modifier(&"speed", StatModifier.Op.ADD, 1.0),
		_modifier(&"speed", StatModifier.Op.SET, 3.0),
		_modifier(&"damage", StatModifier.Op.ADD, 2.0),
		_modifier(&"damage", StatModifier.Op.ADD, 3.0),
		_modifier(&"drain", StatModifier.Op.MULTIPLY, 0.5),
		_modifier(&"drain", StatModifier.Op.MULTIPLY, 0.5),
	]
	var stats: Dictionary[StringName, float] = StatsCalculator.compute(_base(), modifiers)
	assert_eq(stats[&"speed"], 8.0, "(SET 3 + 1) x 2")
	assert_eq(stats[&"damage"], 10.0, "5 + 2 + 3")
	assert_almost_eq(stats[&"drain"], 0.05, 0.000001, "0.2 x 0.5 x 0.5")


func test_r_015_03_later_set_wins() -> void:
	var modifiers: Array[StatModifier] = [
		_modifier(&"speed", StatModifier.Op.SET, 3.0),
		_modifier(&"speed", StatModifier.Op.SET, 4.0),
	]
	var stats: Dictionary[StringName, float] = StatsCalculator.compute(_base(), modifiers)
	assert_eq(stats[&"speed"], 4.0, "SETs apply in list order")


func test_r_015_03_inputs_unchanged() -> void:
	var base: Dictionary[StringName, float] = _base()
	var modifier: StatModifier = _modifier(&"speed", StatModifier.Op.ADD, 1.0)
	var modifiers: Array[StatModifier] = [modifier]
	var stats: Dictionary[StringName, float] = StatsCalculator.compute(base, modifiers)
	assert_eq(base, _base(), "the base is not changed")
	assert_eq(modifiers.size(), 1, "the list is not changed")
	assert_eq(modifier.value, 1.0, "the modifier is not changed")
	stats[&"damage"] = 99.0
	assert_eq(base[&"damage"], 5.0, "the result is a new dictionary")


func test_r_015_03_no_modifiers_returns_base_copy() -> void:
	var base: Dictionary[StringName, float] = _base()
	var stats: Dictionary[StringName, float] = StatsCalculator.compute(base, [])
	assert_eq(stats, base, "same values")
	stats[&"speed"] = 9.0
	assert_eq(base[&"speed"], 1.0, "never the same dictionary")


func test_r_015_04_unknown_stat_ignored_and_reported() -> void:
	var modifiers: Array[StatModifier] = [
		_modifier(&"armour", StatModifier.Op.SET, 10.0),
		_modifier(&"speed", StatModifier.Op.ADD, 1.0),
	]
	var stats: Dictionary[StringName, float] = StatsCalculator.compute(_base(), modifiers)
	assert_push_error("armour")
	assert_false(stats.has(&"armour"), "an unknown stat is not added")
	assert_eq(stats[&"speed"], 2.0, "the other modifiers apply")


func test_r_015_04_null_modifier_reported() -> void:
	var modifiers: Array[StatModifier] = [null, _modifier(&"damage", StatModifier.Op.ADD, 1.0)]
	var stats: Dictionary[StringName, float] = StatsCalculator.compute(_base(), modifiers)
	assert_push_error("null")
	assert_eq(stats[&"damage"], 6.0, "the other modifiers apply")
