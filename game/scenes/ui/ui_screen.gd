class_name UIScreen
extends Control
## Base of every screen opened through UIManager (architecture §9.5). A screen
## receives what it shows through setup() and never looks for it in the tree.

## The screen asks to be closed (for example, the loot screen when the box is empty).
signal close_requested


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
