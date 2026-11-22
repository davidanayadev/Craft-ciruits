class_name InventorySlotView
extends Button
## One inventory cell (R-005-25): the icon and quantity of a stack, or the
## empty look. It can only be pressed when it is interactive and holds a stack,
## or, when its screen asks for it, also empty (spec 012).
## A selected cell shows a frame (spec 008). A cell that received a move
## shows a highlight that fades by itself, and a possible destination of the
## container screen's placing mode shows an outline (spec 013). The highlight
## processes only while it shows, like DamageFlash.

var _interactive: bool = false
var _has_stack: bool = false
## An empty interactive cell can be pressed too (spec 012, plan D14).
var _empty_pressable: bool = false
var _highlight_duration_s: float = 0.0
var _highlight_left_s: float = 0.0

@onready var _icon: TextureRect = %Icon
@onready var _quantity: Label = %Quantity
@onready var _selection: Control = %Selection
@onready var _highlight: Control = %Highlight
@onready var _target_outline: Control = %TargetOutline


func _ready() -> void:
	_highlight.visible = false
	set_process(false)


func _process(delta: float) -> void:
	advance_highlight(delta)


func set_interactive(interactive: bool) -> void:
	_interactive = interactive
	_update_disabled()


func set_empty_pressable(pressable: bool) -> void:
	_empty_pressable = pressable
	_update_disabled()


func set_selected(selected: bool) -> void:
	_selection.visible = selected


func is_selected() -> bool:
	return _selection.visible


## Shows the highlight frame for duration_s seconds; <= 0 → nothing.
func flash_highlight(duration_s: float) -> void:
	if duration_s <= 0.0:
		return
	_highlight_duration_s = duration_s
	_highlight_left_s = duration_s
	_highlight.modulate.a = 1.0
	_highlight.visible = true
	set_process(true)


func is_highlighted() -> bool:
	return _highlight_left_s > 0.0


## Advances the highlight by delta seconds; _process calls it while highlighted.
func advance_highlight(delta: float) -> void:
	if not is_highlighted():
		return
	_highlight_left_s -= delta
	if is_highlighted():
		_highlight.modulate.a = _highlight_left_s / _highlight_duration_s
		return
	_highlight_left_s = 0.0
	_highlight.visible = false
	set_process(false)


## Outline of a possible destination (placing mode).
func set_target_marked(marked: bool) -> void:
	_target_outline.visible = marked


func is_target_marked() -> bool:
	return _target_outline.visible


## null → empty look.
func show_stack(stack: ItemStack) -> void:
	_has_stack = stack != null
	_icon.texture = stack.item.icon if _has_stack else null
	_quantity.text = str(stack.quantity) if _has_stack else ""
	_update_disabled()


func _update_disabled() -> void:
	disabled = not (_interactive and (_has_stack or _empty_pressable))
