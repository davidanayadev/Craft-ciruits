class_name DamageFlash
extends TextureRect
## Red flash at the screen edges when the local player is hit (spec 007,
## R-007-25). It processes only while it shows, so the HUD needs no _process.

var _duration_s: float = 0.0
var _seconds_left: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Shows the flash and fades it out over duration_s seconds.
func flash(duration_s: float) -> void:
	if duration_s <= 0.0:
		return
	_duration_s = duration_s
	_seconds_left = duration_s
	modulate.a = 1.0
	visible = true
	set_process(true)


func is_flashing() -> bool:
	return _seconds_left > 0.0


## Advances the fade by delta seconds; _process calls it while flashing.
func advance(delta: float) -> void:
	if not is_flashing():
		return
	_seconds_left -= delta
	if is_flashing():
		modulate.a = _seconds_left / _duration_s
		return
	_seconds_left = 0.0
	visible = false
	set_process(false)
