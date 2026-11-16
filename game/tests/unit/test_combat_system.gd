extends GutTest
## CombatSystem (spec 007): pure rules of the swing, without a scene tree
## (R-007-08). Attack data without damage or rate is rejected (R-007-05), the
## interval comes from the attacks per second (R-007-07) and a depleted battery
## or a blocked input cannot start a swing (R-007-09).
## The numbers here are arbitrary test inputs, exact in binary, not balance
## values.

const DAMAGE := 7
const ATTACKS_PER_SECOND := 2.0
const INTERVAL := 0.5
const COST := 1.5
const IMPACT_TIME := 0.25
const PHYSICS_STEP := 1.0 / 60.0
const STEPS_PER_SECOND := 60


func _attack(
	damage: int = DAMAGE, rate: float = ATTACKS_PER_SECOND, cost: float = COST
) -> AttackStatsData:
	var attack: AttackStatsData = AttackStatsData.new()
	attack.damage = damage
	attack.attacks_per_second = rate
	attack.battery_cost = cost
	return attack


func test_r_007_05_rejects_zero_or_negative() -> void:
	assert_true(CombatSystem.is_valid_attack(_attack()), "a complete attack is valid")
	assert_true(CombatSystem.is_valid_attack(_attack(DAMAGE, ATTACKS_PER_SECOND, 0.0)), "free swings too")
	assert_false(CombatSystem.is_valid_attack(null), "no data")
	assert_false(CombatSystem.is_valid_attack(_attack(0)), "zero damage")
	assert_false(CombatSystem.is_valid_attack(_attack(-1)), "negative damage")
	assert_false(CombatSystem.is_valid_attack(_attack(DAMAGE, 0.0)), "zero attacks per second")
	assert_false(CombatSystem.is_valid_attack(_attack(DAMAGE, -1.0)), "negative attacks per second")
	assert_false(CombatSystem.is_valid_attack(_attack(DAMAGE, ATTACKS_PER_SECOND, -1.0)), "negative cost")
	assert_false(CombatSystem.is_valid_attack(AttackStatsData.new()), "an empty resource")


func test_r_007_05_invalid_attack_cannot_start() -> void:
	assert_false(CombatSystem.can_start_swing(INF, _attack(0), false, false), "zero damage never swings")
	assert_false(CombatSystem.can_start_swing(INF, _attack(DAMAGE, 0.0), false, false), "nor zero rate")
	assert_false(CombatSystem.can_start_swing(INF, null, false, false), "nor missing data")


func test_r_007_07_interval_from_attacks_per_second() -> void:
	assert_eq(CombatSystem.swing_interval(_attack()), INTERVAL, "1 / attacks per second")
	assert_eq(CombatSystem.swing_interval(_attack(DAMAGE, 1.0)), 1.0, "one per second")
	assert_eq(CombatSystem.swing_interval(_attack(DAMAGE, 4.0)), 0.25, "four per second")


func test_r_007_07_sixty_steps_make_one_second() -> void:
	var attack: AttackStatsData = _attack(DAMAGE, 1.0)
	var elapsed: float = 0.0
	for step: int in STEPS_PER_SECOND - 1:
		elapsed += PHYSICS_STEP
		assert_false(
			CombatSystem.can_start_swing(elapsed, attack, false, false), "step %d is too early" % (step + 1)
		)
	elapsed += PHYSICS_STEP
	assert_true(
		CombatSystem.can_start_swing(elapsed, attack, false, false),
		"the 60th step of 1/60 s is one second, despite the rounding"
	)


func test_r_007_08_can_start_when_ready() -> void:
	var attack: AttackStatsData = _attack()
	assert_true(CombatSystem.can_start_swing(INF, attack, false, false), "the first swing starts at once")
	assert_true(CombatSystem.can_start_swing(INTERVAL, attack, false, false), "exactly one interval later")
	assert_true(CombatSystem.can_start_swing(INTERVAL * 3.0, attack, false, false), "or any time after")


func test_r_007_08_waits_for_the_interval() -> void:
	var attack: AttackStatsData = _attack()
	assert_false(CombatSystem.can_start_swing(0.0, attack, false, false), "right after a swing")
	assert_false(CombatSystem.can_start_swing(INTERVAL * 0.5, attack, false, false), "halfway")
	assert_false(CombatSystem.can_start_swing(INTERVAL - 0.01, attack, false, false), "just before")


func test_r_007_08_damage_from_attack() -> void:
	assert_eq(CombatSystem.damage_per_hit(_attack()), DAMAGE, "the damage of the arms")
	assert_eq(CombatSystem.damage_per_hit(_attack(3)), 3, "whatever they are")


func test_r_007_08_impact_reached_once() -> void:
	assert_false(CombatSystem.impact_reached(0.0, 0.125, IMPACT_TIME), "before the impact moment")
	assert_true(CombatSystem.impact_reached(0.125, IMPACT_TIME, IMPACT_TIME), "the step that reaches it")
	assert_true(CombatSystem.impact_reached(0.125, 0.375, IMPACT_TIME), "or jumps over it")
	assert_false(CombatSystem.impact_reached(IMPACT_TIME, 0.375, IMPACT_TIME), "not again afterwards")


func test_r_007_08_impact_with_physics_steps() -> void:
	var impact_time: float = 12.0 * PHYSICS_STEP
	var elapsed: float = 0.0
	var impact_steps: Array[int] = []
	for step: int in STEPS_PER_SECOND:
		var before: float = elapsed
		elapsed += PHYSICS_STEP
		if CombatSystem.impact_reached(before, elapsed, impact_time):
			impact_steps.append(step + 1)
	var expected: Array[int] = [12]
	assert_eq(impact_steps, expected, "one impact, on the step that adds up to the impact time")


func test_r_007_09_depleted_or_blocked_cannot_start() -> void:
	var attack: AttackStatsData = _attack()
	assert_false(CombatSystem.can_start_swing(INF, attack, true, false), "depleted battery")
	assert_false(CombatSystem.can_start_swing(INF, attack, false, true), "blocked input")
	assert_false(CombatSystem.can_start_swing(INF, attack, true, true), "both")
