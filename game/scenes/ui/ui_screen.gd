class_name UIScreen
extends Control
## Base of every screen opened through UIManager (architecture §9.5). A screen
## receives what it shows through setup() and never looks for it in the tree.

## The screen asks to be closed (for example, the loot screen when the box is empty).
signal close_requested


## Called by UIManager once, after the screen enters the tree.
func setup(_context: Dictionary) -> void:
	pass
