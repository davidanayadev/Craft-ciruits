class_name InventoryScreen
extends UIScreen
## The player's inventory (R-005-24, R-005-25): a title and one cell per slot.
## Tapping a stack selects it; with a thrower in the context, a quantity
## selector and a throw button appear (spec 008). The screen only asks the
## thrower: it never changes the inventory itself.
## Spec 012: a "Use" button, enabled for a selected consumable, asks the same
## robot to use that slot (R-012-25).
## Spec 015: with that robot, the EquipmentPanel shows its slots and stats
## beside the grid (plan D17). The screen owns the selection: one inventory
## slot or one equipment slot, never both. "Equip" for a selected piece,
## "Unequip" for a selected occupied equipment slot (R-015-34); a refusal shows
## tr(error_key) in %Notice; a selected piece shows its durability (R-015-52).

const SCREEN_ID := &"inventory"
## InventoryComponent of the player.
const CONTEXT_INVENTORY := &"inventory"
## Robot that throws the selected stack; without it the throw controls stay hidden.
const CONTEXT_THROWER := &"thrower"
const NO_SELECTION := -1
const EQUIP_KEY := &"EQUIPMENT_EQUIP"
const UNEQUIP_KEY := &"EQUIPMENT_UNEQUIP"
const DURABILITY_KEY := &"BENCH_DURABILITY"

var _inventory: InventoryComponent = null
var _thrower: Robot = null
var _selected_index: int = NO_SELECTION
## The selected equipment slot, or NO_SELECTION.
var _selected_slot: int = NO_SELECTION

@onready var _grid: InventoryGrid = %Grid
@onready var _throw_controls: Control = %ThrowControls
@onready var _quantity_selector: QuantitySelector = %QuantitySelector
@onready var _throw_button: Button = %ThrowButton
@onready var _use_button: Button = %UseButton
@onready var _equip_button: Button = %EquipButton
@onready var _equipment_panel: EquipmentPanel = %EquipmentPanel
@onready var _selected_detail: Label = %SelectedDetail
@onready var _notice: Label = %Notice


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
	_grid.slot_pressed.connect(_on_grid_slot_pressed)
	# After the grid's own connection, so the cells are already repainted.
	inventory.inventory_changed.connect(_on_inventory_changed)
	_throw_button.pressed.connect(_on_throw_button_pressed)
	_use_button.pressed.connect(_on_use_button_pressed)
	_equip_button.pressed.connect(_on_equip_button_pressed)
	_equipment_panel.visible = _thrower != null
	if _thrower != null:
		_equipment_panel.bind(_thrower.equipment, _thrower.stats)
		_equipment_panel.slot_pressed.connect(_select_equipment_slot)
		_thrower.equipment.equipment_changed.connect(_on_equipment_changed)
	_select(NO_SELECTION)


func on_closed() -> void:
	if _thrower == null:
		return
	_equipment_panel.unbind()
	if _thrower.equipment.equipment_changed.is_connected(_on_equipment_changed):
		_thrower.equipment.equipment_changed.disconnect(_on_equipment_changed)


func _on_grid_slot_pressed(index: int) -> void:
	_notice.visible = false
	_select(index)


## Selects an inventory slot and clears the equipment one. The selector
## starts at the whole stack (R-008-38).
func _select(index: int) -> void:
	_selected_index = index
	_selected_slot = NO_SELECTION
	_grid.set_selected_index(index)
	_equipment_panel.set_selected_slot(NO_SELECTION)
	var has_selection: bool = index != NO_SELECTION
	_throw_button.disabled = not has_selection
	_quantity_selector.visible = has_selection
	if has_selection:
		_quantity_selector.set_maximum(_selected_quantity())
	_update_use_button()
	_update_equip_controls()


## Selects an equipment slot and clears the inventory one (plan 015 D17).
func _select_equipment_slot(slot: PieceData.SlotType) -> void:
	_notice.visible = false
	_select(NO_SELECTION)
	_selected_slot = slot
	_equipment_panel.set_selected_slot(slot)
	_update_equip_controls()


## "Equip" for a selected piece, "Unequip" for a selected occupied slot,
## disabled otherwise (R-015-34); the selected piece's durability (R-015-52).
func _update_equip_controls() -> void:
	var piece: ItemStack = _selected_stack()
	var is_piece: bool = piece != null and piece.item is PieceData
	var occupied: bool = (
		_thrower != null and _selected_slot != NO_SELECTION
		and _thrower.equipment.get_piece(_selected_slot as PieceData.SlotType) != null
	)
	_equip_button.visible = _thrower != null
	_equip_button.text = String(UNEQUIP_KEY if occupied else EQUIP_KEY)
	_equip_button.disabled = not (is_piece or occupied)
	_selected_detail.visible = is_piece
	if is_piece:
		var data: PieceData = piece.item as PieceData
		_selected_detail.text = tr(DURABILITY_KEY) % [piece.durability, data.durability_max]


## The stack of the selected inventory slot; null when none.
func _selected_stack() -> ItemStack:
	var slots: Array[ItemStack] = _inventory.get_slots()
	if _selected_index < 0 or _selected_index >= slots.size():
		return null
	return slots[_selected_index]


## Only a selected consumable can be used (R-012-25).
func _update_use_button() -> void:
	var selected: ItemStack = _selected_stack()
	_use_button.disabled = selected == null or not selected.item is ConsumableData


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
		_update_use_button()
		_update_equip_controls()


## A selected slot that emptied (unequipped, broken, death) loses the selection.
func _on_equipment_changed() -> void:
	if _selected_slot == NO_SELECTION:
		return
	if _thrower.equipment.get_piece(_selected_slot as PieceData.SlotType) == null:
		_select(NO_SELECTION)
	else:
		_update_equip_controls()


func _on_throw_button_pressed() -> void:
	if _thrower == null or _selected_index == NO_SELECTION:
		return
	_thrower.request_throw(_selected_index, _quantity_selector.get_value())


func _on_use_button_pressed() -> void:
	if _thrower == null or _use_button.disabled:
		return
	_thrower.request_use_consumable(_selected_index)


## The robot equips or unequips; the screen never changes either side itself.
## A refusal shows its reason (R-015-34); a done change clears the selection.
func _on_equip_button_pressed() -> void:
	if _thrower == null or _equip_button.disabled:
		return
	var result: ActionResult = null
	if _selected_slot != NO_SELECTION:
		result = _thrower.unequip(_selected_slot as PieceData.SlotType)
	else:
		result = _thrower.equip(_selected_index)
	_notice.visible = not result.ok
	if not result.ok:
		_notice.text = String(result.error_key)
		return
	_select(NO_SELECTION)
