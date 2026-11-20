class_name InventoryGrid
extends GridContainer
## Grid of cells bound to one InventoryComponent: one cell per slot, repainted
## only on inventory_changed (R-005-25, R-005-26). It never changes the
## inventory: it reports the pressed slot and the screen asks the owner.

signal slot_pressed(index: int)

const SLOT_SCENE := preload("res://scenes/ui/inventory_slot.tscn")

## Whether occupied cells can be pressed.
@export var interactive: bool = false

var _inventory: InventoryComponent = null
var _cells: Array[InventorySlotView] = []
## -1 = none.
var _selected_index: int = -1
var _empty_cells_pressable: bool = false


## Paints now and on every inventory_changed.
func bind(inventory: InventoryComponent) -> void:
	if _inventory != null:
		_inventory.inventory_changed.disconnect(_refresh)
	_inventory = inventory
	_inventory.inventory_changed.connect(_refresh)
	_refresh()


## Marks one cell as selected; -1 = none. Only the look: the screen decides
## what a selection means.
func set_selected_index(index: int) -> void:
	_selected_index = index
	for i: int in _cells.size():
		_cells[i].set_selected(i == index)


## Empty cells of an interactive grid can be pressed too (spec 012, plan D14);
## false by default, so the inventory screen does not change.
func set_empty_cells_pressable(pressable: bool) -> void:
	_empty_cells_pressable = pressable
	for cell: InventorySlotView in _cells:
		cell.set_empty_pressable(pressable)


func _refresh() -> void:
	var slots: Array[ItemStack] = _inventory.get_slots()
	_set_cell_count(slots.size())
	for index: int in slots.size():
		_cells[index].show_stack(slots[index])


func _set_cell_count(count: int) -> void:
	while _cells.size() > count:
		var removed: InventorySlotView = _cells.pop_back()
		removed.queue_free()
	while _cells.size() < count:
		var cell: InventorySlotView = SLOT_SCENE.instantiate() as InventorySlotView
		add_child(cell)
		cell.set_interactive(interactive)
		cell.set_empty_pressable(_empty_cells_pressable)
		cell.set_selected(_cells.size() == _selected_index)
		cell.pressed.connect(_on_cell_pressed.bind(_cells.size()))
		_cells.append(cell)


func _on_cell_pressed(index: int) -> void:
	if interactive:
		slot_pressed.emit(index)
