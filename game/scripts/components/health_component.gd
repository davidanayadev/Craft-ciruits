class_name HealthComponent
extends Node
## Hit points of one entity (spec 006): enemies now, anything with HP later.
## The robot has none: its battery is its health (BatteryComponent).
## The maximum comes from the owner's data through reset(), never from a
## literal here, so a pooled entity can come back as another kind.
## Before the first reset() it is inactive: maximum 0, not dead, and
## take_damage()/heal() report an error and change nothing.

signal health_changed(current: int, maximum: int)
## Emitted once per life, on arrival at 0.
signal died

var _current: int = 0
var _maximum: int = 0
var _dead: bool = false


## Starts a new life at full HP. maximum <= 0 → push_error, no change.
func reset(maximum: int) -> void:
	if maximum <= 0:
		push_error("HealthComponent '%s': reset() needs a positive maximum (%d)." % [name, maximum])
		return
	_maximum = maximum
	_current = maximum
	_dead = false
	health_changed.emit(_current, _maximum)


## Lowers the HP, never below 0. Negative amount → push_error, no change.
## A dead entity ignores it.
func take_damage(amount: int) -> void:
	if not _accepts(amount, "take_damage"):
		return
	_set_current(_current - amount)


## Raises the HP, never above the maximum. Negative amount → push_error, no
## change. A dead entity ignores it: only reset() revives.
func heal(amount: int) -> void:
	if not _accepts(amount, "heal"):
		return
	_set_current(_current + amount)


func get_current() -> int:
	return _current


func get_maximum() -> int:
	return _maximum


func is_dead() -> bool:
	return _dead


func _accepts(amount: int, method: String) -> bool:
	if _maximum <= 0:
		push_error("HealthComponent '%s': %s() before reset()." % [name, method])
		return false
	if amount < 0:
		push_error(
			"HealthComponent '%s': %s() got a negative amount (%d)." % [name, method, amount]
		)
		return false
	return not _dead


## Single write path, so every change is clamped and reported the same way:
## health_changed, then died.
func _set_current(value: int) -> void:
	var clamped: int = clampi(value, 0, _maximum)
	if clamped == _current:
		return
	_current = clamped
	health_changed.emit(_current, _maximum)
	if _current == 0:
		_dead = true
		died.emit()
