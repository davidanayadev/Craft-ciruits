class_name LootScreen
extends UIScreen
## Contents of a loot box next to the player's inventory (R-005-16). Tapping a
## box cell takes that stack, "take all" takes every stack in slot order, as
## much as fits (R-005-18, R-005-19); the screen asks to be closed when the
## box is empty (R-005-21). It only asks: the player's inventory does the move.

const SCREEN_ID := &"loot"
## InventoryComponent of the box.
const CONTEXT_SOURCE := &"source"
## InventoryComponent of the player.
const CONTEXT_INVENTORY := &"inventory"

var _source: InventoryComponent = null
var _inventory: InventoryComponent = null

@onready var _source_grid: InventoryGrid = %SourceGrid
@onready var _player_grid: InventoryGrid = %PlayerGrid
@onready var _take_all_button: Button = %TakeAllButton


func _ready() -> void:
	_source_grid.slot_pressed.connect(_on_source_slot_pressed)
	_take_all_button.pressed.connect(_on_take_all_pressed)


## Missing or wrong type → push_error.
func setup(context: Dictionary) -> void:
	_source = context.get(CONTEXT_SOURCE) as InventoryComponent
	_inventory = context.get(CONTEXT_INVENTORY) as InventoryComponent
	if _source == null or _inventory == null:
		push_error(
			"LootScreen: the context needs '%s' and '%s' InventoryComponents."
			% [CONTEXT_SOURCE, CONTEXT_INVENTORY]
		)
		return
	_source_grid.bind(_source)
	_player_grid.bind(_inventory)
	_source.inventory_changed.connect(_on_source_changed)
	_on_source_changed()


func _on_source_slot_pressed(index: int) -> void:
	if _inventory == null:
		return
	var indices: Array[int] = [index]
	_inventory.take_from(_source, indices)


func _on_take_all_pressed() -> void:
	if _inventory == null:
		return
	var slots: Array[ItemStack] = _source.get_slots()
	var indices: Array[int] = []
	for index: int in slots.size():
		if slots[index] != null:
			indices.append(index)
	_inventory.take_from(_source, indices)


func _on_source_changed() -> void:
	if _source.is_empty():
		close_requested.emit()
