class_name LoadingScreen
extends Control
## Covers the game while ZoneLoader travels (spec 009, R-009-07). It lasts as
## long as the load, with no minimum. Like TransferScreen it is not a UIManager
## screen: Escape and "back" must not close it, and it swallows every touch
## while it shows. Placeholder look until ACTION_PLAN 4.4.


func _ready() -> void:
	visible = false


func show_loading() -> void:
	visible = true


func hide_loading() -> void:
	visible = false


func is_showing() -> bool:
	return visible
