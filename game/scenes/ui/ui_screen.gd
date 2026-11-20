class_name UIScreen
extends Control
## Base of every screen opened through UIManager (architecture §9.5). A screen
## receives what it shows through setup() and never looks for it in the tree.
## Spec 012: a screen with closes_on_outside_tap asks to go back when the
## player taps or clicks outside its panel (R-012-46, plan D16). Only taps that
## no child stops reach the screen's own _gui_input: its panel stops the mouse,
## its backdrop and centring let it through, so a tap there is "outside".

## The screen asks to be closed (for example, when its work is done).
signal close_requested
## Emitted by UIManager when the screen leaves the stack by any path, after
## on_closed() (spec 012, plan D15).
signal closed
## A tap or click outside the panel of a screen with closes_on_outside_tap;
## UIManager handles it as "back" when this screen is on top (R-012-46).
signal back_requested

## Bench, inventory and container: true in their scenes. Placement and notice: false (R-012-48).
@export var closes_on_outside_tap: bool = false


## One kind of event only: on Android a tap also arrives as an emulated mouse
## button, so a single kind never closes twice. Accepted, so it never reaches
## _unhandled_input, where the attack and the joystick listen (R-012-47).
func _gui_input(event: InputEvent) -> void:
	if not closes_on_outside_tap:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	back_requested.emit()


## Called by UIManager once, after the screen enters the tree.
func setup(_context: Dictionary) -> void:
	pass


## Escape or "back" on this screen while it is on top. True when the screen
## handled it itself and must stay open; false lets UIManager close it.
func handle_back() -> bool:
	return false


## Called by UIManager once, when the screen leaves the stack by any path
## (its own request, Escape, back, close_top, close_all), before it is freed.
func on_closed() -> void:
	pass
