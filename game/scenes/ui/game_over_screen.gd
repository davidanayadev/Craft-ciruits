class_name GameOverScreen
extends Control
## Provisional game over screen (spec 003, R-003-12): shown when the battery is
## depleted, with a restart button. Spec 008 replaces it with the ruleset and
## the respawn. It only shows itself and reports the button: main.gd decides
## what restarting means.

signal restart_requested

@onready var _restart_button: Button = %RestartButton


func open() -> void:
	visible = true
	# Lets a keyboard or gamepad confirm without a pointer.
	_restart_button.grab_focus()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()
