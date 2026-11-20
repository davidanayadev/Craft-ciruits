class_name ContainerScreen
extends UIScreen
## A chest or an opened loot box next to the player's inventory (spec 012,
## R-012-27): the container as a 2-column grid, the player's grid, a quantity
## selector, "Transfer" and "Take all". It replaces the loot screen of spec 005
## (R-012-37). A tap selects a whole stack and a second tap clears it
## (R-012-28); with a selection, a tap on any slot moves the chosen quantity
## there (R-012-29) and "Transfer" sends it to the other side (R-012-30). It
## only asks the inventories (InventoryComponent.move_to_slot / transfer_to /
## take_from); refusals show in its own %Notice (plan D22). It never closes by
## itself, also when the container is empty (R-012-35).

const SCREEN_ID := &"container"
## InventoryComponent of the chest or the box.
const CONTEXT_CONTAINER := &"container"
## InventoryComponent of the player.
const CONTEXT_INVENTORY := &"inventory"
## StringName: CHEST_TITLE_KEY or LOOT_TITLE_KEY.
const CONTEXT_TITLE := &"title"
const CHEST_TITLE_KEY := &"CHEST_TITLE"
const LOOT_TITLE_KEY := &"LOOT_TITLE"
const NO_SELECTION := -1

enum GridSide { CONTAINER, PLAYER }

var _container: InventoryComponent = null
var _inventory: InventoryComponent = null
var _selected_side: GridSide = GridSide.CONTAINER
var _selected_index: int = NO_SELECTION

@onready var _title: Label = %Title
@onready var _container_grid: InventoryGrid = %ContainerGrid
@onready var _player_grid: InventoryGrid = %PlayerGrid
@onready var _quantity_selector: QuantitySelector = %QuantitySelector
@onready var _transfer_button: Button = %TransferButton
@onready var _take_all_button: Button = %TakeAllButton
@onready var _notice: Label = %Notice


func _ready() -> void:
	_container_grid.slot_pressed.connect(_on_slot_pressed.bind(GridSide.CONTAINER))
	_player_grid.slot_pressed.connect(_on_slot_pressed.bind(GridSide.PLAYER))
	_transfer_button.pressed.connect(_on_transfer_pressed)
	_take_all_button.pressed.connect(_on_take_all_pressed)


## Missing or wrong context → push_error, nothing shown.
func setup(context: Dictionary) -> void:
	var container: InventoryComponent = context.get(CONTEXT_CONTAINER) as InventoryComponent
	var inventory: InventoryComponent = context.get(CONTEXT_INVENTORY) as InventoryComponent
	var title: Variant = context.get(CONTEXT_TITLE)
	if container == null or inventory == null or not title is StringName:
		push_error(
			"ContainerScreen: the context needs '%s' and '%s' InventoryComponents and a '%s' key."
			% [CONTEXT_CONTAINER, CONTEXT_INVENTORY, CONTEXT_TITLE]
		)
		return
	_container = container
	_inventory = inventory
	_title.text = String(title as StringName)
	_container_grid.bind(container)
	_player_grid.bind(inventory)
	# After the grids' own connections, so the cells are already repainted.
	container.inventory_changed.connect(_on_inventories_changed)
	inventory.inventory_changed.connect(_on_inventories_changed)
	_select(GridSide.CONTAINER, NO_SELECTION)


func get_selected_side() -> GridSide:
	return _selected_side


func get_selected_index() -> int:
	return _selected_index


## A new selection, or none, hides the notice of an earlier refusal.
func _select(side: GridSide, index: int) -> void:
	_notice.visible = false
	_selected_side = side
	_selected_index = index
	var has_selection: bool = index != NO_SELECTION
	_container_grid.set_selected_index(index if side == GridSide.CONTAINER else NO_SELECTION)
	_player_grid.set_selected_index(index if side == GridSide.PLAYER else NO_SELECTION)
	_container_grid.set_empty_cells_pressable(has_selection)
	_player_grid.set_empty_cells_pressable(has_selection)
	_transfer_button.disabled = not has_selection
	_quantity_selector.visible = has_selection
	if has_selection:
		_quantity_selector.set_maximum(_selected_quantity())


## No selection → select; the selected slot → clear; any other slot → move there.
func _on_slot_pressed(index: int, side: GridSide) -> void:
	if _selected_index == NO_SELECTION:
		if _inventory_of(side).get_slots()[index] != null:
			_select(side, index)
		return
	if side == _selected_side and index == _selected_index:
		_select(side, NO_SELECTION)
		return
	var origin: InventoryComponent = _inventory_of(_selected_side)
	_report(origin.move_to_slot(_selected_index, _inventory_of(side), index, _quantity_selector.get_value()))


func _on_transfer_pressed() -> void:
	if _selected_index == NO_SELECTION:
		return
	var origin: InventoryComponent = _inventory_of(_selected_side)
	var other: GridSide = GridSide.PLAYER if _selected_side == GridSide.CONTAINER else GridSide.CONTAINER
	_report(origin.transfer_to(_inventory_of(other), _selected_index, _quantity_selector.get_value()))


## Every stack in slot order, as much as fits; what does not fit stays and the
## player's inventory reports overflowed, which the HUD shows (R-012-31).
func _on_take_all_pressed() -> void:
	if _inventory == null:
		return
	var slots: Array[ItemStack] = _container.get_slots()
	var indices: Array[int] = []
	for index: int in slots.size():
		if slots[index] != null:
			indices.append(index)
	_inventory.take_from(_container, indices)


## A done move clears the selection and the notice; a refusal keeps the
## selection and shows why (plan D22).
func _report(result: ActionResult) -> void:
	_notice.visible = not result.ok
	if result.ok:
		_select(_selected_side, NO_SELECTION)
	else:
		_notice.text = String(result.error_key)


## A selection whose stack is gone is cleared (R-012-35).
func _on_inventories_changed() -> void:
	if _selected_index == NO_SELECTION:
		return
	if _selected_quantity() == 0:
		_select(_selected_side, NO_SELECTION)
	else:
		_quantity_selector.set_maximum(_selected_quantity())


## 0 when the selected slot is empty or gone.
func _selected_quantity() -> int:
	var slots: Array[ItemStack] = _inventory_of(_selected_side).get_slots()
	if _selected_index < 0 or _selected_index >= slots.size() or slots[_selected_index] == null:
		return 0
	return slots[_selected_index].quantity


func _inventory_of(side: GridSide) -> InventoryComponent:
	return _container if side == GridSide.CONTAINER else _inventory
