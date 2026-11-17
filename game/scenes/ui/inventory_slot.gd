class_name InventorySlotView
extends Button
## One inventory cell (R-005-25): the icon and quantity of a stack, or the
## empty look. It can only be pressed when it is interactive and holds a stack.
## A selected cell shows a frame (spec 008).

var _interactive: bool = false
var _has_stack: bool = false

@onready var _icon: TextureRect = %Icon
@onready var _quantity: Label = %Quantity
@onready var _selection: Control = %Selection


func set_interactive(interactive: bool) -> void:
	_interactive = interactive
	_update_disabled()


func set_selected(selected: bool) -> void:
	_selection.visible = selected


func is_selected() -> bool:
	return _selection.visible


## null → empty look.
func show_stack(stack: ItemStack) -> void:
	_has_stack = stack != null
	_icon.texture = stack.item.icon if _has_stack else null
	_quantity.text = str(stack.quantity) if _has_stack else ""
	_update_disabled()


func _update_disabled() -> void:
	disabled = not (_interactive and _has_stack)
