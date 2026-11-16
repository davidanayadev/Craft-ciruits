extends GutTest
## EnemyBrain (spec 006): the pure Idle/Patrol/Chase/Attack state machine.
## Covers R-006-11 (transition table), R-006-12 (idle/patrol cycle), the logic
## part of R-006-13 (chase on vision), R-006-14 (give up), R-006-15 (one hit per
## attack interval) and the logic part of R-006-18 (no living player, INF).
## AI values come from zombie_ai.tres and the interval from zombie_slow.tres.

const AI_PATH: String = "res://resources/ai/zombie_ai.tres"
const ENEMY_PATH: String = "res://resources/enemies/zombie_slow.tres"
const DT: float = 1.0 / 60.0
const EPS: float = 0.0001
const HOME: Vector3 = Vector3(3.0, 2.0, -4.0)
const SEEDS: int = 50


func _ai() -> EnemyAiData:
	var ai: EnemyAiData = load(AI_PATH) as EnemyAiData
	return ai


func _interval() -> float:
	var data: EnemyData = load(ENEMY_PATH) as EnemyData
	return data.attack_interval


func _make(rng_seed: int = 1) -> EnemyBrain:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var brain: EnemyBrain = EnemyBrain.new(_ai(), _interval(), rng)
	brain.reset(HOME)
	return brain


func _to_patrol(brain: EnemyBrain) -> void:
	brain.tick(_ai().patrol_pause_max + 0.5, INF, false)


func _to_chase(brain: EnemyBrain) -> void:
	brain.tick(DT, _ai().vision_radius, false)


func _to_attack(brain: EnemyBrain) -> void:
	_to_chase(brain)
	brain.tick(DT, _ai().attack_range, false)


func _mid_distance() -> float:
	var ai: EnemyAiData = _ai()
	return (ai.vision_radius + ai.give_up_distance) / 2.0


## Ticks inside attack range until a hit lands; returns the ticks used, or -1.
func _ticks_to_hit(brain: EnemyBrain, step: float, max_ticks: int) -> int:
	var in_range: float = _ai().attack_range
	for i: int in max_ticks:
		if brain.tick(step, in_range, false):
			return i + 1
	return -1


func _count_hits(brain: EnemyBrain, step: float, total_time: float) -> int:
	var in_range: float = _ai().attack_range
	var hits: int = 0
	var ticks: int = int(total_time / step)
	for i: int in ticks:
		if brain.tick(step, in_range, false):
			hits += 1
	return hits


# --- R-006-11: transition table -------------------------------------------

func test_r_006_11_starts_in_idle() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var brain: EnemyBrain = EnemyBrain.new(_ai(), _interval(), rng)
	assert_eq(brain.get_state(), EnemyBrain.State.IDLE, "a new brain is idle")


func test_r_006_11_reset_goes_idle_from_any_state() -> void:
	var brain: EnemyBrain = _make()
	_to_patrol(brain)
	brain.reset(HOME)
	assert_eq(brain.get_state(), EnemyBrain.State.IDLE, "from PATROL")
	_to_chase(brain)
	brain.reset(HOME)
	assert_eq(brain.get_state(), EnemyBrain.State.IDLE, "from CHASE")
	_to_attack(brain)
	brain.reset(HOME)
	assert_eq(brain.get_state(), EnemyBrain.State.IDLE, "from ATTACK")


func test_r_006_11_reset_clears_attack_timer() -> void:
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	var interval: float = _interval()
	brain.tick(interval * 0.8, _ai().attack_range, false)
	brain.reset(HOME)
	_to_attack(brain)
	var hit: bool = brain.tick(interval * 0.5, _ai().attack_range, false)
	assert_false(hit, "the wait restarts after reset")


func test_r_006_11_idle_stays_idle_when_far_and_pause_left() -> void:
	var brain: EnemyBrain = _make()
	brain.tick(DT, _ai().vision_radius + 1.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.IDLE, "far target, pause not over")


func test_r_006_11_idle_to_chase_on_vision() -> void:
	var brain: EnemyBrain = _make()
	brain.tick(DT, _ai().vision_radius - 1.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "IDLE -> CHASE")


func test_r_006_11_idle_to_patrol_when_pause_runs_out() -> void:
	var brain: EnemyBrain = _make()
	brain.tick(_ai().patrol_pause_max + 0.5, INF, false)
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "IDLE -> PATROL")


func test_r_006_11_patrol_to_chase_on_vision() -> void:
	var brain: EnemyBrain = _make()
	_to_patrol(brain)
	brain.tick(DT, _ai().vision_radius - 1.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "PATROL -> CHASE")


func test_r_006_11_patrol_to_idle_when_arrived() -> void:
	var brain: EnemyBrain = _make()
	_to_patrol(brain)
	brain.tick(DT, INF, true)
	assert_eq(brain.get_state(), EnemyBrain.State.IDLE, "PATROL -> IDLE")


func test_r_006_11_vision_wins_over_arrival_in_patrol() -> void:
	var brain: EnemyBrain = _make()
	_to_patrol(brain)
	brain.tick(DT, _ai().vision_radius - 1.0, true)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "chase is checked before arrival")


func test_r_006_11_chase_to_attack_in_range() -> void:
	var brain: EnemyBrain = _make()
	_to_chase(brain)
	brain.tick(DT, _ai().attack_range, false)
	assert_eq(brain.get_state(), EnemyBrain.State.ATTACK, "CHASE -> ATTACK at exactly the range")


func test_r_006_11_chase_stays_between_vision_and_give_up() -> void:
	var brain: EnemyBrain = _make()
	_to_chase(brain)
	brain.tick(DT, _mid_distance(), false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "keeps chasing past vision")
	brain.tick(DT, _ai().give_up_distance, false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "exactly give_up_distance still chases")


func test_r_006_11_chase_gives_up_to_patrol() -> void:
	var brain: EnemyBrain = _make()
	_to_chase(brain)
	brain.tick(DT, _ai().give_up_distance + 1.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "CHASE -> PATROL")


func test_r_006_11_attack_to_chase_when_out_of_range() -> void:
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	brain.tick(DT, _ai().attack_range + 0.5, false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "ATTACK -> CHASE")


func test_r_006_11_attack_stays_while_in_range() -> void:
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	brain.tick(DT, _ai().attack_range, false)
	assert_eq(brain.get_state(), EnemyBrain.State.ATTACK, "stays in ATTACK")


func test_r_006_11_give_up_wins_over_chase() -> void:
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	brain.tick(DT, _ai().give_up_distance + 1.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "ATTACK -> PATROL, not CHASE")


func test_r_006_11_one_transition_per_tick() -> void:
	var brain: EnemyBrain = _make()
	brain.tick(DT, 0.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "IDLE next to the target goes to CHASE only")
	brain.tick(DT, 0.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.ATTACK, "the next tick reaches ATTACK")
	brain.tick(DT, _ai().give_up_distance + 1.0, false)
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "ATTACK gives up in one step")


func test_r_006_11_transition_tick_never_hits() -> void:
	var brain: EnemyBrain = _make()
	var huge: float = _interval() * 5.0
	_to_chase(brain)
	assert_false(brain.tick(huge, _ai().attack_range, false), "CHASE -> ATTACK tick")
	assert_false(brain.tick(huge, _ai().attack_range + 0.5, false), "ATTACK -> CHASE tick")
	_to_attack(brain)
	assert_false(brain.tick(huge, _ai().give_up_distance + 1.0, false), "ATTACK -> PATROL tick")


# --- R-006-12: idle / patrol cycle ----------------------------------------

func test_r_006_12_idle_patrol_cycle() -> void:
	var ai: EnemyAiData = _ai()
	var step: float = 0.01
	var brain: EnemyBrain = _make(7)
	var pauses: Array[float] = []
	for cycle: int in 5:
		var ticks: int = 0
		while brain.get_state() == EnemyBrain.State.IDLE and ticks < 100000:
			brain.tick(step, INF, false)
			ticks += 1
		assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "pause ends in PATROL")
		var pause: float = float(ticks) * step
		pauses.append(pause)
		assert_true(pause >= ai.patrol_pause_min - EPS, "pause %f not below min" % pause)
		assert_true(pause <= ai.patrol_pause_max + step + EPS, "pause %f not above max" % pause)
		brain.tick(step, INF, true)
		assert_eq(brain.get_state(), EnemyBrain.State.IDLE, "arrival returns to IDLE")
	var distinct: Dictionary[float, bool] = {}
	for p: float in pauses:
		distinct[p] = true
	assert_gt(distinct.size(), 1, "pauses are drawn again, not repeated")


func test_r_006_12_first_pause_within_range() -> void:
	var ai: EnemyAiData = _ai()
	var step: float = 0.01
	for rng_seed: int in SEEDS:
		var brain: EnemyBrain = _make(rng_seed)
		var ticks: int = 0
		while brain.get_state() == EnemyBrain.State.IDLE and ticks < 100000:
			brain.tick(step, INF, false)
			ticks += 1
		var pause: float = float(ticks) * step
		assert_true(
			pause >= ai.patrol_pause_min - EPS and pause <= ai.patrol_pause_max + step + EPS,
			"seed %d pause %f inside [min, max]" % [rng_seed, pause]
		)


func test_r_006_12_patrol_point_within_radius() -> void:
	var ai: EnemyAiData = _ai()
	var outside: int = 0
	var wrong_height: int = 0
	var points: Dictionary[Vector3, bool] = {}
	for rng_seed: int in SEEDS:
		var brain: EnemyBrain = _make(rng_seed)
		for i: int in 10:
			_to_patrol(brain)
			var point: Vector3 = brain.get_patrol_point()
			points[point] = true
			var offset: Vector2 = Vector2(point.x - HOME.x, point.z - HOME.z)
			if offset.length() > ai.patrol_radius + EPS:
				outside += 1
			if not is_equal_approx(point.y, HOME.y):
				wrong_height += 1
			brain.tick(DT, INF, true)
	assert_eq(outside, 0, "every point is within patrol_radius of home")
	assert_eq(wrong_height, 0, "points keep the height of home")
	assert_gt(points.size(), SEEDS, "points are varied")


func test_r_006_12_stays_in_patrol_until_arrived() -> void:
	var brain: EnemyBrain = _make()
	_to_patrol(brain)
	var left: int = 0
	for i: int in 2000:
		brain.tick(DT, INF, false)
		if brain.get_state() != EnemyBrain.State.PATROL:
			left += 1
	assert_eq(left, 0, "no timeout in PATROL")


func test_r_006_12_new_patrol_point_per_patrol() -> void:
	var brain: EnemyBrain = _make(3)
	_to_patrol(brain)
	var first: Vector3 = brain.get_patrol_point()
	brain.tick(DT, INF, true)
	_to_patrol(brain)
	var second: Vector3 = brain.get_patrol_point()
	assert_ne(first, second, "a new point is picked on each patrol")


func test_r_006_12_patrol_point_follows_reset_home() -> void:
	var ai: EnemyAiData = _ai()
	var brain: EnemyBrain = _make()
	var new_home: Vector3 = Vector3(100.0, 0.0, 100.0)
	brain.reset(new_home)
	_to_patrol(brain)
	var point: Vector3 = brain.get_patrol_point()
	var offset: Vector2 = Vector2(point.x - new_home.x, point.z - new_home.z)
	assert_true(offset.length() <= ai.patrol_radius + EPS, "points are around the new home")


func test_r_006_12_same_seed_same_sequence() -> void:
	var a: EnemyBrain = _make(99)
	var b: EnemyBrain = _make(99)
	var mismatches: int = 0
	for i: int in 3000:
		var arrived: bool = i % 7 == 0
		a.tick(DT, INF, arrived)
		b.tick(DT, INF, arrived)
		if a.get_state() != b.get_state():
			mismatches += 1
		elif a.get_state() == EnemyBrain.State.PATROL and a.get_patrol_point() != b.get_patrol_point():
			mismatches += 1
	assert_eq(mismatches, 0, "same seed, same states and points")


# --- R-006-13 (logic): chase on vision -------------------------------------

func test_r_006_13_chase_on_vision() -> void:
	var radius: float = _ai().vision_radius
	var from_idle: EnemyBrain = _make()
	from_idle.tick(DT, radius, false)
	assert_eq(from_idle.get_state(), EnemyBrain.State.CHASE, "IDLE: exactly vision_radius chases")
	var from_patrol: EnemyBrain = _make()
	_to_patrol(from_patrol)
	from_patrol.tick(DT, radius, false)
	assert_eq(from_patrol.get_state(), EnemyBrain.State.CHASE, "PATROL: exactly vision_radius chases")


func test_r_006_13_no_chase_just_outside_vision() -> void:
	var outside: float = _ai().vision_radius + 0.01
	var from_idle: EnemyBrain = _make()
	from_idle.tick(DT, outside, false)
	assert_eq(from_idle.get_state(), EnemyBrain.State.IDLE, "IDLE: slightly beyond does not chase")
	var from_patrol: EnemyBrain = _make()
	_to_patrol(from_patrol)
	from_patrol.tick(DT, outside, false)
	assert_eq(from_patrol.get_state(), EnemyBrain.State.PATROL, "PATROL: slightly beyond does not chase")


# --- R-006-14: give up ------------------------------------------------------

func test_r_006_14_gives_up_beyond_distance() -> void:
	var ai: EnemyAiData = _ai()
	var brain: EnemyBrain = _make()
	_to_chase(brain)
	brain.tick(DT, ai.give_up_distance + 0.01, false)
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "slightly beyond gives up")
	var point: Vector3 = brain.get_patrol_point()
	var offset: Vector2 = Vector2(point.x - HOME.x, point.z - HOME.z)
	assert_true(offset.length() <= ai.patrol_radius + EPS, "it goes to a patrol point near home")


func test_r_006_14_gives_up_from_attack() -> void:
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	brain.tick(DT, _ai().give_up_distance + 0.01, false)
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "ATTACK gives up too")


func test_r_006_14_does_not_give_up_within_distance() -> void:
	var brain: EnemyBrain = _make()
	_to_chase(brain)
	for i: int in 100:
		brain.tick(DT, _mid_distance(), false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "keeps chasing inside give_up_distance")


# --- R-006-15: one hit per attack interval ---------------------------------

func test_r_006_15_first_hit_after_full_interval() -> void:
	var interval: float = _interval()
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	var ticks: int = _ticks_to_hit(brain, DT, 1000)
	assert_gt(ticks, 0, "a hit lands")
	var elapsed: float = float(ticks) * DT
	assert_true(elapsed >= interval - EPS, "not before a full interval (%f)" % elapsed)
	assert_true(elapsed <= interval + DT + EPS, "and right when it is over (%f)" % elapsed)


func test_r_006_15_hits_once_per_interval() -> void:
	var interval: float = _interval()
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	var first: int = _ticks_to_hit(brain, DT, 1000)
	var second: int = _ticks_to_hit(brain, DT, 1000)
	assert_gt(first, 0, "first hit")
	assert_gt(second, 0, "second hit")
	var gap: float = float(second) * DT
	assert_true(absf(gap - interval) <= DT + EPS, "hits are one interval apart (%f)" % gap)


func test_r_006_15_no_hit_every_tick() -> void:
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	var hits: int = _count_hits(brain, DT, _interval() * 3.0 + 0.25)
	assert_eq(hits, 3, "three full intervals, three hits")


func test_r_006_15_leaving_range_restarts_wait() -> void:
	var interval: float = _interval()
	var ai: EnemyAiData = _ai()
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	brain.tick(interval * 0.8, ai.attack_range, false)
	brain.tick(DT, ai.attack_range + 0.5, false)
	assert_eq(brain.get_state(), EnemyBrain.State.CHASE, "stepped out of range")
	brain.tick(DT, ai.attack_range, false)
	assert_eq(brain.get_state(), EnemyBrain.State.ATTACK, "back in range")
	var early: bool = brain.tick(interval * 0.5, ai.attack_range, false)
	assert_false(early, "0.8 + 0.5 intervals would hit without the restart")
	var ticks: int = _ticks_to_hit(brain, DT, 1000)
	assert_gt(ticks, 0, "the hit still lands")
	var elapsed: float = interval * 0.5 + float(ticks) * DT
	assert_true(elapsed >= interval - EPS, "a full interval from the return (%f)" % elapsed)


func test_r_006_15_no_hit_on_tick_that_leaves_range() -> void:
	var interval: float = _interval()
	var ai: EnemyAiData = _ai()
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	brain.tick(interval * 0.9, ai.attack_range, false)
	var hit: bool = brain.tick(interval, ai.attack_range + 0.5, false)
	assert_false(hit, "a tick that transitions never hits")


func test_r_006_15_rate_independent_of_step() -> void:
	var total: float = _interval() * 10.5
	var fine: EnemyBrain = _make()
	_to_attack(fine)
	var slow: EnemyBrain = _make()
	_to_attack(slow)
	var hits_60: int = _count_hits(fine, 1.0 / 60.0, total)
	var hits_30: int = _count_hits(slow, 1.0 / 30.0, total)
	assert_eq(hits_60, 10, "10.5 intervals at 1/60 s")
	assert_eq(hits_30, 10, "10.5 intervals at 1/30 s")


# --- R-006-18 (logic): no living player ------------------------------------

func test_r_006_18_no_target_means_no_hit() -> void:
	var brain: EnemyBrain = _make()
	_to_attack(brain)
	brain.tick(_interval() * 0.9, _ai().attack_range, false)
	var hit: bool = brain.tick(_interval(), INF, false)
	assert_false(hit, "no hit when the target is gone")
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "ATTACK gives up on INF")
	var hits: int = 0
	for i: int in 1000:
		if brain.tick(DT, INF, false):
			hits += 1
	assert_eq(hits, 0, "never hits without a target")


func test_r_006_18_chase_gives_up_on_no_target() -> void:
	var brain: EnemyBrain = _make()
	_to_chase(brain)
	brain.tick(DT, INF, false)
	assert_eq(brain.get_state(), EnemyBrain.State.PATROL, "CHASE gives up on INF")


func test_r_006_18_idle_and_patrol_never_chase_without_target() -> void:
	var brain: EnemyBrain = _make()
	var chases: int = 0
	for i: int in 3000:
		brain.tick(DT, INF, i % 5 == 0)
		if brain.get_state() == EnemyBrain.State.CHASE or brain.get_state() == EnemyBrain.State.ATTACK:
			chases += 1
	assert_eq(chases, 0, "INF never triggers CHASE or ATTACK")
