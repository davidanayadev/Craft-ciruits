extends GutTest
## Base stats of the robot with no piece equipped (spec 015): one resource with
## the "no piece" rows of BALANCE §4.2, the running drain of §1.1 and the wear
## per hit of §4.1 (R-015-02), the wear being a stat a modifier can change (R-015-06).
## The expected values mirror BALANCE.md; update both together.

const BASE_STATS_PATH := "res://resources/robot/robot_base_stats.tres"
## Stat id → BALANCE value.
const EXPECTED: Dictionary[StringName, float] = {
	StatIds.WALK_SPEED: 0.5,          # §4.2 "Sin piernas"
	StatIds.RUN_SPEED: 0.0,           # §4.2 "Sin piernas": no puede correr (plan D2)
	StatIds.WALK_DRAIN: 0.1,          # §4.2 "Sin piernas"
	StatIds.RUN_DRAIN: 0.15,          # §1.1 consumo al correr
	StatIds.PASSIVE_DRAIN: 0.2,       # §4.2 "Sin Core"
	StatIds.MAX_BATTERY: 100.0,       # §4.2 "Sin Core" (no se reduce)
	StatIds.ATTACK_DAMAGE: 5.0,       # §4.2 "Un brazo"
	StatIds.ATTACKS_PER_SECOND: 1.0,  # §4.2 "Un brazo"
	StatIds.BATTERY_PER_SWING: 1.0,   # §4.2 "Un brazo"
	StatIds.DURABILITY_PER_HIT: 5.0,  # §4.1 degradación por golpe
}


func _load_base() -> RobotBaseStatsData:
	return load(BASE_STATS_PATH) as RobotBaseStatsData


func test_r_015_02_base_matches_balance() -> void:
	var base: RobotBaseStatsData = _load_base()
	assert_not_null(base, "robot_base_stats.tres exists and is a RobotBaseStatsData")
	if base == null:
		return
	var stats: Dictionary[StringName, float] = base.to_stats()
	assert_eq(stats.size(), EXPECTED.size(), "one entry per stat")
	for stat: StringName in EXPECTED:
		assert_true(stats.has(stat), "base has %s" % stat)
		var value: float = stats.get(stat, -1.0)
		assert_almost_eq(value, EXPECTED[stat], 0.0001, "%s (BALANCE)" % stat)


func test_r_015_02_one_field_per_stat_id() -> void:
	var base: RobotBaseStatsData = RobotBaseStatsData.new()
	var names: Array[String] = []
	for property: Dictionary in base.get_property_list():
		var property_name: String = property["name"]
		names.append(property_name)
	for stat: StringName in StatIds.ALL:
		assert_true(names.has(String(stat)), "RobotBaseStatsData has the field %s" % stat)
	assert_eq(base.to_stats().keys(), StatIds.ALL, "to_stats() lists every id, in order")


func test_r_015_06_wear_is_a_stat() -> void:
	var base: RobotBaseStatsData = _load_base()
	if base == null:
		fail_test("robot_base_stats.tres is missing")
		return
	assert_true(StatIds.ALL.has(StatIds.DURABILITY_PER_HIT), "the wear per hit is a stat id")
	assert_eq(base.durability_per_hit, 5.0, "wear per hit received (BALANCE §4.1)")
	var modifier: StatModifier = StatModifier.new()
	modifier.stat = StatIds.DURABILITY_PER_HIT
	modifier.op = StatModifier.Op.ADD
	modifier.value = -1.0
	var stats: Dictionary[StringName, float] = StatsCalculator.compute(base.to_stats(), [modifier])
	assert_eq(stats[StatIds.DURABILITY_PER_HIT], 4.0, "a modifier changes it (BALANCE §6.3 Chasis reforzado)")


func test_r_015_02_old_stat_resources_are_gone() -> void:
	for path: String in [
		"res://resources/movement/basic_legs.tres",
		"res://resources/combat/one_arm.tres",
		"res://resources/combat/basic_arms.tres",
	]:
		assert_false(ResourceLoader.exists(path), "%s is gone: its numbers live in the base or a piece" % path)
	var names: Array[String] = []
	for property: Dictionary in BatteryConfigData.new().get_property_list():
		var property_name: String = property["name"]
		names.append(property_name)
	for field: String in ["maximum", "passive_drain", "run_drain"]:
		assert_false(names.has(field), "BatteryConfigData has no %s: it is a stat" % field)
