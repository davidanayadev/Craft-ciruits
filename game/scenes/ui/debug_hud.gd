class_name DebugHud
extends CanvasLayer
## Debug-build-only overlay: shows FPS to measure the mobile budget on a real
## device (constitution P12). Never visible in release builds, so its text is
## exempt from i18n (P11 covers player-visible strings).

@onready var _fps_label: Label = %FpsLabel
@onready var _refresh: Timer = %Refresh


func _ready() -> void:
	visible = OS.is_debug_build()
	if not visible:
		_refresh.stop()


func _on_refresh_timeout() -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
