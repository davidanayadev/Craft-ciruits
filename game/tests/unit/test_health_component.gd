extends GutTest
## HealthComponent rules (spec 006): starts full after reset() and reports
## every change (R-006-05), loses HP down to 0 (R-006-06), dies once and then
## ignores damage and healing until reset (R-006-07), heals up to its maximum
## (R-006-08) and rejects negative amounts (R-006-09).
## No scene: the maximum comes by parameter. The numbers here are arbitrary
## test inputs, not balance values.

const MAXIMUM := 20

var _health: HealthComponent


func before_each() -> void:
	_health = HealthComponent.new()
	_health.name = "Health"
	add_child_autofree(_health)
	watch_signals(_health)


func test_r_006_05_starts_full() -> void:
	_health.reset(MAXIMUM)
	assert_eq(_health.get_maximum(), MAXIMUM, "maximum from reset()")
	assert_eq(_health.get_current(), MAXIMUM, "starts at the maximum")
	assert_false(_health.is_dead(), "a full entity is alive")


func test_r_006_05_inactive_before_reset() -> void:
	assert_eq(_health.get_maximum(), 0, "no maximum before reset()")
	assert_false(_health.is_dead(), "not dead: it was never alive")
	_health.take_damage(1)
	assert_push_error("Health")
	_health.heal(1)
	assert_push_error("Health")
	assert_eq(_health.get_current(), 0, "nothing changed")
	assert_signal_not_emitted(_health, "health_changed")
	assert_signal_not_emitted(_health, "died")


func test_r_006_05_reset_rejects_non_positive_maximum() -> void:
	_health.reset(0)
	assert_push_error("Health")
	assert_eq(_health.get_maximum(), 0, "still inactive")
	assert_signal_not_emitted(_health, "health_changed")


func test_r_006_05_emits_health_changed() -> void:
	_health.reset(MAXIMUM)
	assert_signal_emitted_with_parameters(_health, "health_changed", [MAXIMUM, MAXIMUM])
	_health.take_damage(5)
	assert_signal_emitted_with_parameters(_health, "health_changed", [MAXIMUM - 5, MAXIMUM])
	_health.heal(2)
	assert_signal_emitted_with_parameters(_health, "health_changed", [MAXIMUM - 3, MAXIMUM])
	assert_signal_emit_count(_health, "health_changed", 3)


func test_r_006_05_no_signal_without_change() -> void:
	_health.reset(MAXIMUM)
	_health.heal(5)
	_health.take_damage(0)
	assert_signal_emit_count(_health, "health_changed", 1, "only the reset changed the HP")


func test_r_006_06_take_damage_lowers() -> void:
	_health.reset(MAXIMUM)
	_health.take_damage(7)
	assert_eq(_health.get_current(), MAXIMUM - 7, "HP lowered by the amount")
	assert_eq(_health.get_maximum(), MAXIMUM, "the maximum does not change")


func test_r_006_06_clamps_at_zero() -> void:
	_health.reset(MAXIMUM)
	_health.take_damage(MAXIMUM + 30)
	assert_eq(_health.get_current(), 0, "HP never goes below 0")


func test_r_006_07_died_once() -> void:
	_health.reset(MAXIMUM)
	_health.take_damage(MAXIMUM - 1)
	assert_signal_not_emitted(_health, "died", "still 1 HP left")
	_health.take_damage(1)
	assert_true(_health.is_dead(), "dead at 0 HP")
	_health.take_damage(5)
	assert_signal_emit_count(_health, "died", 1)


func test_r_006_07_dead_ignores_damage_and_heal() -> void:
	_health.reset(MAXIMUM)
	_health.take_damage(MAXIMUM)
	var changes_at_death: int = get_signal_emit_count(_health, "health_changed")
	_health.take_damage(3)
	_health.heal(10)
	assert_eq(_health.get_current(), 0, "a dead entity stays at 0")
	assert_true(_health.is_dead(), "healing does not revive")
	assert_signal_emit_count(_health, "health_changed", changes_at_death)


func test_r_006_07_reset_revives() -> void:
	_health.reset(MAXIMUM)
	_health.take_damage(MAXIMUM)
	_health.reset(15)
	assert_false(_health.is_dead(), "alive again after reset()")
	assert_eq(_health.get_current(), 15, "full HP of the new maximum")
	assert_eq(_health.get_maximum(), 15, "new maximum")
	_health.take_damage(15)
	assert_signal_emit_count(_health, "died", 2, "died once per life")


func test_r_006_08_heal_capped_at_max() -> void:
	_health.reset(MAXIMUM)
	_health.take_damage(10)
	_health.heal(4)
	assert_eq(_health.get_current(), MAXIMUM - 6, "HP raised by the amount")
	_health.heal(100)
	assert_eq(_health.get_current(), MAXIMUM, "HP never goes above the maximum")


func test_r_006_09_negative_amount_reports_error() -> void:
	_health.reset(MAXIMUM)
	_health.take_damage(5)
	_health.take_damage(-3)
	assert_push_error("Health")
	_health.heal(-3)
	assert_push_error("Health")
	assert_eq(_health.get_current(), MAXIMUM - 5, "negative amounts change nothing")
