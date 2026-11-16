class_name DebugHud
extends CanvasLayer
## Debug-build-only overlay: shows FPS to measure the mobile budget on a real
## device (constitution P12) and the XP of the player it is bound to, until
## the game HUD shows it (spec 007, R-007-22). Never visible in release builds,
## so its text is exempt from i18n (P11 covers player-visible strings).

@onready var _fps_label: Label = %FpsLabel
@onready var _xp_label: Label = %XpLabel
@onready var _refresh: Timer = %Refresh


func _ready() -> void:
	visible = OS.is_debug_build()
	if not visible:
		_refresh.stop()


## Shows the XP of the given player and follows its changes.
func bind(player: Robot) -> void:
	player.experience.xp_changed.connect(_on_xp_changed)
	_on_xp_changed(player.experience.get_total())


func _on_refresh_timeout() -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_xp_changed(total: int) -> void:
	_xp_label.text = "XP: %d" % total
