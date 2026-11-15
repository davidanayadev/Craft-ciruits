class_name InventoryScreen
extends UIScreen
## The player's inventory (R-005-24, R-005-25): a title and one cell per slot.
## It only shows; the cells cannot be pressed.

const SCREEN_ID := &"inventory"
## InventoryComponent of the player.
const CONTEXT_INVENTORY := &"inventory"

@onready var _grid: InventoryGrid = %Grid


## Missing or wrong type → push_error.
func setup(context: Dictionary) -> void:
	var inventory: InventoryComponent = context.get(CONTEXT_INVENTORY) as InventoryComponent
	if inventory == null:
		push_error("InventoryScreen: the context has no '%s' InventoryComponent." % CONTEXT_INVENTORY)
		return
	_grid.bind(inventory)
