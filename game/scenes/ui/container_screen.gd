class_name ContainerScreen
extends UIScreen
## A chest or an opened loot box next to the player's inventory (spec 012,
## replaces the loot screen of spec 005, R-012-37). Spec 013 gives it headers
## with name and occupancy over each grid (R-013-12) and a fixed action card
## below them (R-013-13). A tap only selects (R-013-14); moving is always a
## button: the move button names the other side (R-013-15), "Place…" enters a
## placing mode where a tap on a slot moves there (R-013-16) and "Take all"
## takes every stack (R-012-31, R-013-18). Back leaves the placing mode first
## (R-013-17). A done move clears the selection and highlights the slots that
## received it; a refusal shows its reason in the card (R-013-19). It only asks
## the inventories (InventoryComponent.move_to_slot / transfer_to / take_from)
## and never closes by itself, also when the container is empty (R-012-35).
## _refresh_card() is the only method that paints the card (plan 013 D9).

const SCREEN_ID := &"container"
## InventoryComponent of the chest or the box.
const CONTEXT_CONTAINER := &"container"
## InventoryComponent of the player.
const CONTEXT_INVENTORY := &"inventory"
## Kind: which container this is, for its texts.
const CONTEXT_KIND := &"kind"
const CHEST_TITLE_KEY := &"CHEST_TITLE"
const LOOT_TITLE_KEY := &"LOOT_TITLE"
const DROPPED_TITLE_KEY := &"DROPPED_TITLE"
const NO_SELECTION := -1

const _INVENTORY_HEADER_KEY := &"CONTAINER_HEADER_INVENTORY"
const _HINT_SELECT_KEY := &"CONTAINER_HINT_SELECT"
const _HINT_PLACE_KEY := &"CONTAINER_HINT_PLACE"
const _SELECTED_KEY := &"CONTAINER_SELECTED"
const _MOVE_KEY := &"CONTAINER_MOVE"
const _MOVE_TO_INVENTORY_KEY := &"CONTAINER_MOVE_TO_INVENTORY"
const _PLACE_KEY := &"CONTAINER_PLACE"
const _CANCEL_KEY := &"CONTAINER_CANCEL"

enum GridSide { CONTAINER, PLAYER }
## New kinds go at the end: the texts are indexed by value (plan 013 D8).
enum Kind { LOOT_BOX, CHEST, DROPPED }
## BROWSING: a tap selects. PLACING: a tap on a slot moves the selection there.
enum Mode { BROWSING, PLACING }

## Texts of each Kind, indexed by its value (plan 013 D8).
const _TITLE_KEYS: Array[StringName] = [LOOT_TITLE_KEY, CHEST_TITLE_KEY, DROPPED_TITLE_KEY]
const _HEADER_KEYS: Array[StringName] = [
	&"CONTAINER_HEADER_BOX", &"CONTAINER_HEADER_CHEST", &"CONTAINER_HEADER_DROPPED"
]
const _MOVE_TO_CONTAINER_KEYS: Array[StringName] = [
	&"CONTAINER_MOVE_TO_BOX", &"CONTAINER_STORE_IN_CHEST", &"CONTAINER_LEAVE_IN_DROPPED"
]

## Source of move_highlight_s, the destination highlight (BALANCE §11).
@export var controls: ControlConfigData

var _container: InventoryComponent = null
var _inventory: InventoryComponent = null
var _kind: Kind = Kind.LOOT_BOX
var _mode: Mode = Mode.BROWSING
var _selected_side: GridSide = GridSide.CONTAINER
var _selected_index: int = NO_SELECTION

@onready var _title: Label = %Title
@onready var _container_header: Label = %ContainerHeader
@onready var _player_header: Label = %PlayerHeader
@onready var _container_grid: InventoryGrid = %ContainerGrid
@onready var _player_grid: InventoryGrid = %PlayerGrid
@onready var _selected_icon: TextureRect = %SelectedIcon
@onready var _selected_label: Label = %SelectedLabel
@onready var _quantity_selector: QuantitySelector = %QuantitySelector
@onready var _move_button: Button = %MoveButton
@onready var _hint: Label = %Hint
@onready var _place_button: Button = %PlaceButton
@onready var _take_all_button: Button = %TakeAllButton
@onready var _notice: Label = %Notice


func _ready() -> void:
	if controls == null:
		push_error("ContainerScreen: controls must be assigned; moves will not be highlighted.")
	_container_grid.slot_pressed.connect(_on_slot_pressed.bind(GridSide.CONTAINER))
	_player_grid.slot_pressed.connect(_on_slot_pressed.bind(GridSide.PLAYER))
	_move_button.pressed.connect(_on_move_pressed)
	_place_button.pressed.connect(_on_place_pressed)
	_take_all_button.pressed.connect(_on_take_all_pressed)


## Missing or wrong context → push_error, nothing shown.
func setup(context: Dictionary) -> void:
	var container: InventoryComponent = context.get(CONTEXT_CONTAINER) as InventoryComponent
	var inventory: InventoryComponent = context.get(CONTEXT_INVENTORY) as InventoryComponent
	var kind: Variant = context.get(CONTEXT_KIND)
	if container == null or inventory == null or not kind is int or not Kind.values().has(kind):
		push_error(
			"ContainerScreen: the context needs '%s' and '%s' InventoryComponents and a '%s' Kind, got %s."
			% [CONTEXT_CONTAINER, CONTEXT_INVENTORY, CONTEXT_KIND, kind]
		)
		return
	_container = container
	_inventory = inventory
	_kind = kind as Kind
	_title.text = String(_TITLE_KEYS[_kind])
	_container_grid.bind(container)
	_player_grid.bind(inventory)
	# After the grids' own connections, so the cells are already repainted.
	container.inventory_changed.connect(_on_inventories_changed)
	inventory.inventory_changed.connect(_on_inventories_changed)
	_select(GridSide.CONTAINER, NO_SELECTION)
	_refresh_headers()


func get_selected_side() -> GridSide:
	return _selected_side


func get_selected_index() -> int:
	return _selected_index


func get_mode() -> Mode:
	return _mode


## In PLACING: leaves the mode, keeps the selection, returns true. Otherwise
## false, so UIManager closes the screen (R-013-17).
func handle_back() -> bool:
	if _mode != Mode.PLACING:
		return false
	_set_mode(Mode.BROWSING)
	return true


## A new selection, or none, hides the notice of an earlier refusal and ends
## the placing mode.
func _select(side: GridSide, index: int) -> void:
	_notice.visible = false
	_selected_side = side
	_selected_index = index
	_mode = Mode.BROWSING
	_quantity_selector.set_maximum(maxi(_selected_quantity(), QuantitySelector.MINIMUM))
	_refresh_card()


## Entering or leaving the mode hides a refusal that no longer applies.
func _set_mode(mode: Mode) -> void:
	_mode = mode
	_notice.visible = false
	_refresh_card()


## BROWSING: a stack selects, the selected one clears, another switches.
## PLACING: the origin cancels, any other slot receives the move (plan 013 D10).
func _on_slot_pressed(index: int, side: GridSide) -> void:
	var is_origin: bool = side == _selected_side and index == _selected_index
	if _mode == Mode.BROWSING:
		_select(side, NO_SELECTION if is_origin else index)
		return
	if is_origin:
		_set_mode(Mode.BROWSING)
		return
	# Read before the move: a stack that leaves its slot clears the selection.
	var origin_in_target: int = _selected_index if side == _selected_side else NO_SELECTION
	var origin: InventoryComponent = _inventory_of(_selected_side)
	var target: InventoryComponent = _inventory_of(side)
	var before: Array[ItemStack] = target.get_slots()
	var result: ActionResult = origin.move_to_slot(
		_selected_index, target, index, _quantity_selector.get_value()
	)
	_report(result, side, before, origin_in_target)


func _on_move_pressed() -> void:
	if _selected_index == NO_SELECTION or _mode != Mode.BROWSING:
		return
	var other: GridSide = _other_side(_selected_side)
	var target: InventoryComponent = _inventory_of(other)
	var before: Array[ItemStack] = target.get_slots()
	var origin: InventoryComponent = _inventory_of(_selected_side)
	_report(
		origin.transfer_to(target, _selected_index, _quantity_selector.get_value()),
		other,
		before,
		NO_SELECTION
	)


func _on_place_pressed() -> void:
	if _selected_index == NO_SELECTION:
		return
	_set_mode(Mode.BROWSING if _mode == Mode.PLACING else Mode.PLACING)


## Every stack in slot order, as much as fits; what does not fit stays and the
## player's inventory reports overflowed, which the HUD shows (R-012-31). When
## nothing fits, the card shows why, like any refused move (R-013-19).
func _on_take_all_pressed() -> void:
	if _inventory == null or _mode != Mode.BROWSING:
		return
	var slots: Array[ItemStack] = _container.get_slots()
	var indices: Array[int] = []
	for index: int in slots.size():
		if slots[index] != null:
			indices.append(index)
	var before: Array[ItemStack] = _inventory.get_slots()
	var result: InventoryAddResult = _inventory.take_from(_container, indices)
	var changed: Array[int] = _changed_slots(before, _inventory.get_slots(), NO_SELECTION)
	if changed.is_empty():
		_notice.text = String(result.error_key)
		_notice.visible = not result.ok
		return
	_select(_selected_side, NO_SELECTION)
	_flash(GridSide.PLAYER, changed)


## A done move clears the selection and lights up the slots of target_side
## that received it, except the origin when both are in the same grid (a swap
## changes both, but the destination is one, plan 013 D13). A refusal keeps
## the selection and the mode and shows why.
func _report(
	result: ActionResult, target_side: GridSide, before: Array[ItemStack], origin_index: int
) -> void:
	if not result.ok:
		_notice.text = String(result.error_key)
		_notice.visible = true
		return
	var after: Array[ItemStack] = _inventory_of(target_side).get_slots()
	_select(_selected_side, NO_SELECTION)
	_flash(target_side, _changed_slots(before, after, origin_index))


func _flash(side: GridSide, indices: Array[int]) -> void:
	if controls == null:
		return
	_grid_of(side).flash_slots(indices, controls.move_highlight_s)


## Slots whose item, quantity or uid differ, but skipped_index.
func _changed_slots(
	before: Array[ItemStack], after: Array[ItemStack], skipped_index: int
) -> Array[int]:
	var changed: Array[int] = []
	for index: int in mini(before.size(), after.size()):
		if index != skipped_index and not _same_stack(before[index], after[index]):
			changed.append(index)
	return changed


func _same_stack(a: ItemStack, b: ItemStack) -> bool:
	if a == null or b == null:
		return a == b
	return a.item == b.item and a.quantity == b.quantity and a.uid == b.uid


## A selection whose stack is gone is cleared, and the placing mode with it
## (R-012-35, plan 013 D10).
func _on_inventories_changed() -> void:
	_refresh_headers()
	if _selected_index == NO_SELECTION:
		_refresh_card()
		return
	if _selected_quantity() == 0:
		_select(_selected_side, NO_SELECTION)
	else:
		_quantity_selector.set_maximum(_selected_quantity())
		_refresh_card()


func _refresh_headers() -> void:
	_container_header.text = _header_text(_HEADER_KEYS[_kind], _container)
	_player_header.text = _header_text(_INVENTORY_HEADER_KEY, _inventory)


func _header_text(key: StringName, inventory: InventoryComponent) -> String:
	var used: int = InventoryRules.count_used_slots(inventory.get_slots())
	return tr(key) % [used, inventory.get_slot_count()]


## Paints the whole card and the grids' marks from the mode and the selection.
func _refresh_card() -> void:
	var selected: ItemStack = _selected_stack()
	var placing: bool = _mode == Mode.PLACING
	_container_grid.set_selected_index(_selected_index if _selected_side == GridSide.CONTAINER else NO_SELECTION)
	_player_grid.set_selected_index(_selected_index if _selected_side == GridSide.PLAYER else NO_SELECTION)
	for grid: InventoryGrid in [_container_grid, _player_grid]:
		grid.set_empty_cells_pressable(placing)
		grid.set_targets_marked(placing)
	_selected_icon.texture = selected.item.icon if selected != null else null
	_selected_label.text = (
		tr(_SELECTED_KEY) % [tr(selected.item.name_key), selected.quantity] if selected != null else ""
	)
	_hint.text = String(_hint_key(selected != null, placing))
	_quantity_selector.set_editable(selected != null and not placing)
	_move_button.text = String(_move_key(selected != null))
	_move_button.disabled = selected == null or placing
	_place_button.text = String(_CANCEL_KEY if placing else _PLACE_KEY)
	_place_button.disabled = selected == null
	_take_all_button.disabled = placing or _container == null or _container.is_empty()


func _hint_key(has_selection: bool, placing: bool) -> StringName:
	if placing:
		return _HINT_PLACE_KEY
	return &"" if has_selection else _HINT_SELECT_KEY


func _move_key(has_selection: bool) -> StringName:
	if not has_selection:
		return _MOVE_KEY
	if _selected_side == GridSide.CONTAINER:
		return _MOVE_TO_INVENTORY_KEY
	return _MOVE_TO_CONTAINER_KEYS[_kind]


## null when nothing is selected or the slot is empty or gone.
func _selected_stack() -> ItemStack:
	if _selected_index == NO_SELECTION or _container == null:
		return null
	var slots: Array[ItemStack] = _inventory_of(_selected_side).get_slots()
	if _selected_index < 0 or _selected_index >= slots.size():
		return null
	return slots[_selected_index]


## 0 when the selected slot is empty or gone.
func _selected_quantity() -> int:
	var stack: ItemStack = _selected_stack()
	return 0 if stack == null else stack.quantity


func _inventory_of(side: GridSide) -> InventoryComponent:
	return _container if side == GridSide.CONTAINER else _inventory


func _grid_of(side: GridSide) -> InventoryGrid:
	return _container_grid if side == GridSide.CONTAINER else _player_grid


func _other_side(side: GridSide) -> GridSide:
	return GridSide.PLAYER if side == GridSide.CONTAINER else GridSide.CONTAINER
