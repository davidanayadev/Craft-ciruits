class_name AttackButton
extends Button
## HUD attack button (spec 007, R-007-16): held, not clicked. It reports when
## it goes down and up, with any finger: the usual grip is one thumb on the
## joystick and the other here (plan 007 §5.1, point 2).

signal held_changed(held: bool)

var _held: bool = false


func _ready() -> void:
	button_down.connect(_set_held.bind(true))
	button_up.connect(_set_held.bind(false))


func _notification(what: int) -> void:
	# A button hidden while it is pressed never gets its button_up.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_set_held(false)


func _set_held(held: bool) -> void:
	if held == _held:
		return
	_held = held
	held_changed.emit(held)
