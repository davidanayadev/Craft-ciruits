class_name InventoryScreen
extends UIScreen
## The player's inventory (R-005-24, R-005-25): a title and one cell per slot.
## Tapping a stack selects it; with a thrower in the context, a quantity
## selector and a throw button appear (spec 008). The screen only asks the
## thrower: it never changes the inventory itself.

const SCREEN_ID := &"inventory"
## InventoryComponent of the player.
const CONTEXT_INVENTORY := &"inventory"
## Robot that throws the selected stack; without it the throw controls stay hidden.
const CONTEXT_THROWER := &"thrower"
const NO_SELECTION := -1

var _inventory: InventoryComponent = null
var _thrower: Robot = null
var _selected_index: int = NO_SELECTION

@onready var _grid: InventoryGrid = %Grid
@onready var _throw_controls: Control = %ThrowControls
@onready var _quantity_selector: QuantitySelector = %QuantitySelector
@onready var _throw_button: Button = %ThrowButton


## Missing or wrong type → push_error.
func setup(context: Dictionary) -> void:
	var inventory: InventoryComponent = context.get(CONTEXT_INVENTORY) as InventoryComponent
	if inventory == null:
		push_error("InventoryScreen: the context has no '%s' InventoryComponent." % CONTEXT_INVENTORY)
		return
	_inventory = inventory
	_thrower = context.get(CONTEXT_THROWER) as Robot
	_throw_controls.visible = _thrower != null
	_grid.bind(inventory)
	_grid.slot_pressed.connect(_select)
	# After the grid's own connection, so the cells are already repainted.
	inventory.inventory_changed.connect(_on_inventory_changed)
	_throw_button.pressed.connect(_on_throw_button_pressed)
	_select(NO_SELECTION)


## The selector starts at the whole stack (R-008-38).
func _select(index: int) -> void:
	_selected_index = index
	_grid.set_selected_index(index)
	var has_selection: bool = index != NO_SELECTION
	_throw_button.disabled = not has_selection
	_quantity_selector.visible = has_selection
	if has_selection:
		_quantity_selector.set_maximum(_selected_quantity())


## 0 when the selected slot is empty or gone.
func _selected_quantity() -> int:
	var slots: Array[ItemStack] = _inventory.get_slots()
	if _selected_index < 0 or _selected_index >= slots.size() or slots[_selected_index] == null:
		return 0
	return slots[_selected_index].quantity


func _on_inventory_changed() -> void:
	if _selected_index == NO_SELECTION:
		return
	if _selected_quantity() == 0:
		_select(NO_SELECTION)
	else:
		_quantity_selector.set_maximum(_selected_quantity())


func _on_throw_button_pressed() -> void:
	if _thrower == null or _selected_index == NO_SELECTION:
		return
	_thrower.request_throw(_selected_index, _quantity_selector.get_value())
