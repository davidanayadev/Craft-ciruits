extends GutTest
## HurtboxComponent (spec 007): an attack lowers the HP of its HealthComponent
## (R-007-11), it sits alone on the hurtbox physics layer so a hitbox finds
## only enemies (R-007-12), remembers who hit it last (R-007-17) and forgets it
## on reset (R-007-23). No physics: attacks come by method call.
## The numbers here are arbitrary test inputs, not balance values.

const MAXIMUM := 20
const DAMAGE := 6
const UID_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const UID_B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

var _health: HealthComponent
var _hurtbox: HurtboxComponent


func before_each() -> void:
	_health = HealthComponent.new()
	add_child_autofree(_health)
	_health.reset(MAXIMUM)
	_hurtbox = HurtboxComponent.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.health = _health
	add_child_autofree(_hurtbox)
	watch_signals(_hurtbox)
	watch_signals(_health)


func test_r_007_11_receive_attack_damages_health() -> void:
	_hurtbox.receive_attack(DAMAGE, UID_A)
	assert_eq(_health.get_current(), MAXIMUM - DAMAGE, "the damage goes to the HealthComponent")
	assert_signal_emitted_with_parameters(_hurtbox, "hurt", [DAMAGE, UID_A])
	assert_signal_emit_count(_hurtbox, "hurt", 1)
	assert_true(_hurtbox.is_alive(), "still alive")


func test_r_007_11_negative_reports_error() -> void:
	_hurtbox.receive_attack(-DAMAGE, UID_A)
	assert_push_error("Hurtbox")
	assert_eq(_health.get_current(), MAXIMUM, "nothing changed")
	assert_eq(_hurtbox.get_last_attacker_uid(), "", "and nobody is remembered")
	assert_signal_not_emitted(_hurtbox, "hurt")


func test_r_007_11_dead_ignores_attacks() -> void:
	_hurtbox.receive_attack(MAXIMUM, UID_A)
	assert_false(_hurtbox.is_alive(), "dead after losing every HP")
	_hurtbox.receive_attack(DAMAGE, UID_B)
	assert_signal_emit_count(_hurtbox, "hurt", 1, "a dead target is not hurt again")
	assert_signal_emit_count(_health, "died", 1, "and dies once")
	assert_eq(_hurtbox.get_last_attacker_uid(), UID_A, "the kill stays with who dealt it")


func test_r_007_11_not_alive_before_first_life() -> void:
	var health: HealthComponent = HealthComponent.new()
	add_child_autofree(health)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.health = health
	add_child_autofree(hurtbox)
	assert_false(hurtbox.is_alive(), "an entity that was never activated cannot be hit")
	hurtbox.receive_attack(DAMAGE, UID_A)
	assert_push_error_count(0)
	assert_eq(health.get_current(), 0, "nothing changed")


func test_r_007_11_missing_health_reports_error() -> void:
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.name = "Orphan"
	add_child_autofree(hurtbox)
	assert_push_error("Orphan")
	assert_false(hurtbox.is_alive(), "without health it cannot be hit")


func test_r_007_12_on_hurtbox_layer() -> void:
	assert_eq(
		_hurtbox.collision_layer, 1 << (HurtboxComponent.PHYSICS_LAYER - 1), "only the hurtbox layer"
	)
	assert_eq(_hurtbox.collision_mask, 0, "it detects nothing itself")
	assert_true(_hurtbox.monitorable, "hitboxes can find it")
	assert_false(_hurtbox.monitoring, "it does not look for anything")
	assert_ne(
		HurtboxComponent.PHYSICS_LAYER, InteractableComponent.PHYSICS_LAYER, "not the interaction layer"
	)


func test_r_007_17_remembers_last_attacker() -> void:
	assert_eq(_hurtbox.get_last_attacker_uid(), "", "nobody hit it yet")
	_hurtbox.receive_attack(DAMAGE, UID_A)
	assert_eq(_hurtbox.get_last_attacker_uid(), UID_A, "the first attacker")
	_hurtbox.receive_attack(DAMAGE, UID_B)
	assert_eq(_hurtbox.get_last_attacker_uid(), UID_B, "the last one wins")


func test_r_007_17_attacker_known_when_died_arrives() -> void:
	var seen: Array[String] = []
	_health.died.connect(func() -> void: seen.append(_hurtbox.get_last_attacker_uid()))
	_hurtbox.receive_attack(DAMAGE, UID_A)
	_hurtbox.receive_attack(MAXIMUM, UID_B)
	var expected: Array[String] = [UID_B]
	assert_eq(seen, expected, "whoever listens to died already finds the final hitter")


func test_r_007_23_reset_forgets_attacker() -> void:
	_hurtbox.receive_attack(DAMAGE, UID_A)
	_hurtbox.reset()
	assert_eq(_hurtbox.get_last_attacker_uid(), "", "a new life has no attacker")
