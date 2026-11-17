class_name TransferScreen
extends Control
## "Transferencia de Consciencia" (spec 008): covers the game between a death
## and the respawn. It ends on its own after DeathConfigData.transfer_duration_s
## and has no button. It is not a UIManager screen: Escape and "back" must not
## close it. It swallows every touch while it shows.
## Placeholder look (a title over a fade); the final animation is ACTION_PLAN 4.4.

signal finished

@export var config: DeathConfigData

var _playing: bool = false
var _elapsed_s: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Shows the screen and starts counting. No config → push_error, no change.
func play() -> void:
	if config == null:
		push_error("TransferScreen '%s': config must be assigned." % name)
		return
	_elapsed_s = 0.0
	_playing = true
	visible = true
	set_process(true)


func is_playing() -> bool:
	return _playing


## Advances delta seconds; hides and emits finished once the duration is
## reached. Time comes by parameter so tests do not wait.
func advance(delta: float) -> void:
	if not _playing:
		return
	_elapsed_s += delta
	if _elapsed_s < config.transfer_duration_s:
		return
	_playing = false
	visible = false
	set_process(false)
	finished.emit()
