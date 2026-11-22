class_name BatteryComponent
extends Node
## Battery of one entity (spec 003): the robot's health. Holds its own state
## (constitution P4), so two entities never share a battery.
## It has no _physics_process and reads no input or zone: the owning entity
## feeds it through tick(), so the drain rule is testable without a scene and
## a future co-op host can drive it for any entity.

signal battery_changed(current: float, maximum: float)
## Emitted once when the charge drops below the low threshold; armed again
## only after it rises above it.
signal battery_low
## Emitted once on each arrival at 0.
signal battery_depleted

## Save contract (spec 010, architecture §10.2).
const SAVE_KEY := &"battery"
const _CURRENT_KEY := "current"
const _NO_PENDING := -1.0

@export var config: BatteryConfigData
## Walking drain of the equipped legs; StatsComponent replaces it in spec 015.
@export var legs: MovementStatsData

var _current: float = 0.0
var _maximum: float = 0.0
var _low_warning_armed: bool = true
## Points on top of config.maximum (the wind generator, spec 012).
var _maximum_bonus: float = 0.0
## A loaded charge above the maximum, kept until a bonus admits it (plan 012 D11).
var _pending_charge: float = _NO_PENDING


func _ready() -> void:
	if config == null or legs == null:
		push_error("BatteryComponent '%s': config and legs must be assigned." % name)
		return
	_maximum = config.maximum + _maximum_bonus
	_current = _maximum


func get_current() -> float:
	return _current


func get_maximum() -> float:
	return _maximum


func is_depleted() -> bool:
	return _current <= 0.0


## Points per second for a gait: the passive drain plus the movement drain.
## The zone is not an input: the battery drains the same everywhere.
func drain_per_second(gait: LocomotionSystem.Gait) -> float:
	match gait:
		LocomotionSystem.Gait.WALK:
			return config.passive_drain + legs.walk_drain
		LocomotionSystem.Gait.RUN:
			return config.passive_drain + config.run_drain
	return config.passive_drain


## Drains for delta seconds at the rate of the given gait. Depends only on the
## elapsed time, never on the frame rate.
func tick(delta: float, gait: LocomotionSystem.Gait) -> void:
	if is_depleted():
		return
	_set_current(_current - drain_per_second(gait) * delta)


## Takes amount points (a hit, an attack). Taking more than is left is not an
## error: it depletes the battery.
func consume(amount: float) -> void:
	if amount < 0.0:
		push_error("BatteryComponent '%s': consume() got a negative amount (%f)." % [name, amount])
		return
	_set_current(_current - amount)


## Gives amount points, capped at the maximum. Also works at 0.
func add(amount: float) -> void:
	if amount < 0.0:
		push_error("BatteryComponent '%s': add() got a negative amount (%f)." % [name, amount])
		return
	_set_current(_current + amount)


func recharge_full() -> void:
	_set_current(_maximum)


## Maximum = config.maximum + bonus (spec 012, R-012-11, plan D10). The charge
## stays, lowered only if it would be above the new maximum; a charge loaded
## above the old maximum is applied now if nothing changed the charge since
## (R-012-14, D11). One battery_changed when anything changed; never
## battery_low nor battery_depleted: nothing was consumed. bonus < 0 →
## push_error, no change.
func set_maximum_bonus(bonus: float) -> void:
	if bonus < 0.0:
		push_error("BatteryComponent '%s': set_maximum_bonus() got a negative bonus (%f)." % [name, bonus])
		return
	_maximum_bonus = bonus
	if config == null:
		return
	var old_current: float = _current
	var old_maximum: float = _maximum
	_maximum = config.maximum + bonus
	_current = minf(_current, _maximum)
	if _pending_charge != _NO_PENDING:
		_current = minf(_pending_charge, _maximum)
		_drop_pending(_pending_charge > _maximum)
	_low_warning_armed = _current >= _maximum * config.low_threshold_ratio
	if _current != old_current or _maximum != old_maximum:
		battery_changed.emit(_current, _maximum)


func get_save_key() -> StringName:
	return SAVE_KEY


## The charge only: the maximum comes from the config on load (R-010-24).
func to_save_data() -> Dictionary:
	return {_CURRENT_KEY: _current}


## battery_changed when the charge changes, never battery_low nor
## battery_depleted: loading is not something that happened (R-010-09, D15).
## The low warning is armed as if the charge had come from above. A charge
## <= 0 → push_error, no change. A charge above the maximum loads at the maximum
## and waits as pending for a bonus that admits it, whatever order the
## persistent owners load in (R-012-14, plan 012 D11); it is reported when it is
## dropped without being applied.
func from_save_data(data: Dictionary) -> void:
	_drop_pending(true)
	var value: Variant = data.get(_CURRENT_KEY)
	if not (value is float or value is int):
		push_error("BatteryComponent '%s': no saved charge in %s; it stays as it is." % [name, data])
		return
	var current: float = value
	if current <= 0.0:
		push_error(
			"BatteryComponent '%s': saved charge %f is not above 0; it stays as it is." % [name, current]
		)
		return
	if current > _maximum:
		_pending_charge = current
		current = _maximum
	_low_warning_armed = current >= _maximum * config.low_threshold_ratio
	if current == _current:
		return
	_current = current
	battery_changed.emit(_current, _maximum)


## Forgets the pending charge; report → push_error when there was one.
func _drop_pending(report: bool) -> void:
	if _pending_charge == _NO_PENDING:
		return
	if report:
		push_error(
			"BatteryComponent '%s': saved charge %f is above the maximum %f; it stays at the maximum."
			% [name, _pending_charge, _maximum]
		)
	_pending_charge = _NO_PENDING


## Single write path, so every change is clamped and reported the same way:
## battery_changed, then battery_low, then battery_depleted. It also drops a
## pending loaded charge: the charge has moved on since the load.
func _set_current(value: float) -> void:
	_drop_pending(true)
	var clamped: float = clampf(value, 0.0, _maximum)
	if clamped == _current:
		return
	_current = clamped
	battery_changed.emit(_current, _maximum)
	_update_low_warning()
	if is_depleted():
		battery_depleted.emit()


func _update_low_warning() -> void:
	var threshold: float = _maximum * config.low_threshold_ratio
	if _current > threshold:
		_low_warning_armed = true
	elif _current < threshold and _low_warning_armed:
		_low_warning_armed = false
		battery_low.emit()
