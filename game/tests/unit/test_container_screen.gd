extends GutTest
## ContainerScreen (spec 012): a chest or an opened loot box next to the
## player's inventory, replacing the loot screen of spec 005 (R-012-37, plan
## D13). Both grids show their slots with the same cells (R-005-25); "Take
## all" takes every stack in slot order, as much as fits (R-005-19, R-012-31).
## Both grids follow inventory_changed, a selection whose stack is gone is
## cleared, and the screen never closes by itself (R-005-26, R-012-35). It
## closes on a tap outside its panel (R-012-46). No control takes focus
## (R-005-24) and the texts are keys in ES and EN (R-005-30, R-012-45).
## Spec 013 replaces its layout and touch handling (R-012-27 to R-012-30):
## headers with name and occupancy (R-013-12), a fixed action card
## (R-013-13), a tap only selects (R-013-14), the move button names its
## destination (R-013-15), "Place…" is an explicit mode (R-013-16) that back
## leaves (R-013-17), "Take all" is disabled when empty (R-013-18), refusals
## and done moves show in the card and the destination slots (R-013-19), with
## no platform checks (R-013-22).
## Spec 014: player slots that grow while open get their cells and header
## (R-014-13), and the last chassis level fits the 1920x1080 screen (R-014-14).
## Tests moved from test_loot_screen.gd keep their names (plan 012 §5.4).
## Headless cannot click Controls (ADR 0002): pressed is emitted by hand.

const SCREEN_SCENE := preload("res://scenes/ui/container_screen.tscn")
const UI_MANAGER_SCENE := preload("res://scenes/ui/ui_manager.tscn")
const CONTROLS_PATH := "res://resources/config/controls.tres"
const SCREENS_PATH := "res://resources/ui/screens.tres"
const TITLE_KEY := &"LOOT_TITLE"
const TAKE_ALL_KEY := &"CONTAINER_TAKE_ALL"
const MOVE_KEY := &"CONTAINER_MOVE"
const MOVE_TO_INVENTORY_KEY := &"CONTAINER_MOVE_TO_INVENTORY"
const MOVE_TO_BOX_KEY := &"CONTAINER_MOVE_TO_BOX"
const STORE_IN_CHEST_KEY := &"CONTAINER_STORE_IN_CHEST"
const PLACE_KEY := &"CONTAINER_PLACE"
const CANCEL_KEY := &"CONTAINER_CANCEL"
const HINT_SELECT_KEY := &"CONTAINER_HINT_SELECT"
const HINT_PLACE_KEY := &"CONTAINER_HINT_PLACE"
const SELECTED_KEY := &"CONTAINER_SELECTED"
const HEADER_BOX_KEY := &"CONTAINER_HEADER_BOX"
const HEADER_CHEST_KEY := &"CONTAINER_HEADER_CHEST"
const HEADER_INVENTORY_KEY := &"CONTAINER_HEADER_INVENTORY"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const KEYS: Array[StringName] = [
	&"LOOT_TITLE",
	&"CHEST_TITLE",
	&"CONTAINER_TAKE_ALL",
	&"CONTAINER_HEADER_BOX",
	&"CONTAINER_HEADER_CHEST",
	&"CONTAINER_HEADER_INVENTORY",
	&"CONTAINER_HINT_SELECT",
	&"CONTAINER_HINT_PLACE",
	&"CONTAINER_SELECTED",
	&"CONTAINER_MOVE",
	&"CONTAINER_MOVE_TO_INVENTORY",
	&"CONTAINER_MOVE_TO_BOX",
	&"CONTAINER_STORE_IN_CHEST",
	&"CONTAINER_PLACE",
	&"CONTAINER_CANCEL",
	&"ERR_PARTIAL_SWAP",
	&"ERR_SLOT_FULL",
	&"ERR_NO_ROOM",
]
## Code of the screen and its parts, checked for platform checks (R-013-22).
const SCREEN_SCRIPTS: PackedStringArray = [
	"res://scenes/ui/container_screen.gd",
	"res://scenes/ui/inventory_grid.gd",
	"res://scenes/ui/inventory_slot.gd",
	"res://scenes/ui/quantity_selector.gd",
]
const PLATFORM_CHECKS: PackedStringArray = [
	"OS.has_feature", "OS.get_name", "InputEventScreenTouch", "InputEventKey"
]
const CONTAINER_SLOTS := 4
const CHASSIS_LEVELS_PATH := "res://resources/progression/chassis_levels.tres"
const SCRAP_SLOT := 0
const CABLES_SLOT := 1
const IRON_SLOT := 2
const EMPTY_SLOT := 3

var _source: InventoryComponent
var _player: InventoryComponent
var _screen: ContainerScreen
var _source_grid: InventoryGrid
var _player_grid: InventoryGrid
var _take_all: Button
var _move: Button
var _place: Button


func before_each() -> void:
	_source = _new_inventory(CONTAINER_SLOTS)
	var loot: Array[ItemStack] = [
		ItemStack.new(DataRegistry.get_item(&"scrap"), 4),
		ItemStack.new(DataRegistry.get_item(&"cables"), 2),
		ItemStack.new(DataRegistry.get_item(&"iron"), 1),
	]
	_source.add_stacks(loot)


func _new_inventory(slot_count: int) -> InventoryComponent:
	var inventory: InventoryComponent = InventoryComponent.new()
	add_child_autofree(inventory)
	inventory.set_slot_count(slot_count)
	return inventory


## Opens the screen on the box and a player inventory of that many slots.
func _open(player_slots: int, kind: ContainerScreen.Kind = ContainerScreen.Kind.LOOT_BOX) -> void:
	_player = _new_inventory(player_slots)
	_open_with(_player, kind)


func _open_with(
	player: InventoryComponent, kind: ContainerScreen.Kind = ContainerScreen.Kind.LOOT_BOX
) -> void:
	_player = player
	_screen = SCREEN_SCENE.instantiate() as ContainerScreen
	add_child_autofree(_screen)
	_find_controls()
	watch_signals(_screen)
	_screen.setup(_context(kind))


func _context(kind: Variant) -> Dictionary:
	return {
		ContainerScreen.CONTEXT_CONTAINER: _source,
		ContainerScreen.CONTEXT_INVENTORY: _player,
		ContainerScreen.CONTEXT_KIND: kind,
	}


func _find_controls() -> void:
	_source_grid = _screen.get_node("%ContainerGrid") as InventoryGrid
	_player_grid = _screen.get_node("%PlayerGrid") as InventoryGrid
	_take_all = _screen.get_node("%TakeAllButton") as Button
	_move = _screen.get_node("%MoveButton") as Button
	_place = _screen.get_node("%PlaceButton") as Button


func _cells(grid: InventoryGrid) -> Array[InventorySlotView]:
	var cells: Array[InventorySlotView] = []
	for child: Node in grid.get_children():
		var cell: InventorySlotView = child as InventorySlotView
		if cell != null and not cell.is_queued_for_deletion():
			cells.append(cell)
	return cells


func _icon(cell: InventorySlotView) -> Texture2D:
	return (cell.get_node("%Icon") as TextureRect).texture


func _quantity(cell: InventorySlotView) -> String:
	return (cell.get_node("%Quantity") as Label).text


func _quantities(inventory: InventoryComponent) -> Array[int]:
	var quantities: Array[int] = []
	for stack: ItemStack in inventory.get_slots():
		quantities.append(0 if stack == null else stack.quantity)
	return quantities


func _selector() -> QuantitySelector:
	return _screen.get_node("%QuantitySelector") as QuantitySelector


func _notice() -> Label:
	return _screen.get_node("%Notice") as Label


func _hint() -> Label:
	return _screen.get_node("%Hint") as Label


func _label(unique_name: String) -> Label:
	return _screen.get_node("%" + unique_name) as Label


func _tap(grid: InventoryGrid, index: int) -> void:
	_cells(grid)[index].pressed.emit()


## Sets the selector to quantity through its own slider.
func _choose(quantity: int) -> void:
	(_selector().get_node("%Slider") as HSlider).value = quantity


## Selects the stack at index and enters placing mode.
func _start_placing(grid: InventoryGrid, index: int) -> void:
	_tap(grid, index)
	_place.pressed.emit()


func _highlighted(grid: InventoryGrid) -> Array[int]:
	var indices: Array[int] = []
	var cells: Array[InventorySlotView] = _cells(grid)
	for i: int in cells.size():
		if cells[i].is_highlighted():
			indices.append(i)
	return indices


func _header(key: StringName, inventory: InventoryComponent) -> String:
	var used: int = InventoryRules.count_used_slots(inventory.get_slots())
	return tr(key) % [used, inventory.get_slot_count()]


# --- Moved from test_loot_screen.gd -------------------------------------------


func test_r_005_25_both_grids() -> void:
	_open(5)
	var source_cells: Array[InventorySlotView] = _cells(_source_grid)
	assert_eq(source_cells.size(), CONTAINER_SLOTS, "one cell per slot of the box")
	assert_eq(_cells(_player_grid).size(), 5, "one cell per slot of the player")
	if source_cells.size() != CONTAINER_SLOTS:
		return
	assert_same(_icon(source_cells[SCRAP_SLOT]), DataRegistry.get_item(&"scrap").icon, "box icon")
	assert_eq(_quantity(source_cells[SCRAP_SLOT]), "4", "box quantity")
	assert_eq(_quantity(source_cells[CABLES_SLOT]), "2", "box quantity")
	assert_eq(_quantity(source_cells[IRON_SLOT]), "1", "box quantity")
	for cell: InventorySlotView in _cells(_player_grid):
		assert_null(_icon(cell), "the player's cells are empty")
		assert_true(cell.disabled, "and cannot be pressed without a selection")


func test_r_005_19_take_all_in_slot_order() -> void:
	# Two slots: scrap and cables enter in slot order, the iron does not fit.
	_open(2)
	_take_all.pressed.emit()
	assert_eq(_quantities(_player), [4, 2] as Array[int], "taken in the box's slot order")
	assert_eq(_quantities(_source), [0, 0, 1, 0] as Array[int], "what does not fit stays in the box")
	assert_signal_not_emitted(_screen, "close_requested", "the box still holds the iron")


func test_r_005_19_take_all_moves_everything_that_fits() -> void:
	_open(5)
	_take_all.pressed.emit()
	assert_eq(_player.count(&"scrap"), 4)
	assert_eq(_player.count(&"cables"), 2)
	assert_eq(_player.count(&"iron"), 1)
	assert_true(_source.is_empty(), "the box gave everything")


func test_r_005_26_both_sides_update() -> void:
	_open(5)
	_tap(_source_grid, CABLES_SLOT)
	_move.pressed.emit()
	var source_cell: InventorySlotView = _cells(_source_grid)[CABLES_SLOT]
	var player_cell: InventorySlotView = _cells(_player_grid)[0]
	assert_null(_icon(source_cell), "the box cell looks empty")
	assert_eq(_quantity(source_cell), "", "without quantity")
	assert_same(_icon(player_cell), DataRegistry.get_item(&"cables").icon, "the player cell shows it")
	assert_eq(_quantity(player_cell), "2", "with its quantity")


func test_r_005_26_does_not_poll() -> void:
	_open(5)
	assert_false(_screen.is_processing(), "no _process")
	assert_false(_screen.is_physics_processing(), "no _physics_process")


func test_r_005_24_controls_never_take_focus() -> void:
	_open(5)
	assert_eq(_take_all.focus_mode, Control.FOCUS_NONE, "take all never takes keyboard focus")
	assert_eq(_move.focus_mode, Control.FOCUS_NONE, "move never takes keyboard focus")
	assert_eq(_place.focus_mode, Control.FOCUS_NONE, "place never takes keyboard focus")
	for grid: InventoryGrid in [_source_grid, _player_grid]:
		for cell: InventorySlotView in _cells(grid):
			assert_eq(cell.focus_mode, Control.FOCUS_NONE, "cells never take keyboard focus")


func test_r_005_30_keys_translated() -> void:
	_open(5)
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, String(TITLE_KEY), "the title is a translation key")
	assert_eq(_take_all.text, String(TAKE_ALL_KEY), "take all is a translation key")
	assert_eq(_move.text, String(MOVE_KEY), "move is a translation key")
	assert_eq(_place.text, String(PLACE_KEY), "place is a translation key")
	assert_eq(_hint().text, String(HINT_SELECT_KEY), "the hint is a translation key")
	for control: Control in [title, _take_all, _move, _place, _hint()]:
		assert_ne(control.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "%s is translated" % control.name)
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for key: StringName in KEYS:
			var text: String = translations[0].get_message(key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, key])


func test_screen_consumes_touches() -> void:
	_open(5)
	assert_eq(_screen.mouse_filter, Control.MOUSE_FILTER_STOP, "touches stop at the screen")
	assert_eq(_screen.anchor_right, 1.0, "it covers the whole width")
	assert_eq(_screen.anchor_bottom, 1.0, "and the whole height")


func test_setup_without_inventories_reports_error() -> void:
	var screen: ContainerScreen = SCREEN_SCENE.instantiate() as ContainerScreen
	add_child_autofree(screen)
	screen.setup({ContainerScreen.CONTEXT_CONTAINER: _source})
	assert_push_error("ContainerScreen")


# --- Spec 012 -----------------------------------------------------------------


func test_r_012_31_rest_stays_and_full_notice() -> void:
	_open(1)
	watch_signals(_player)
	_take_all.pressed.emit()
	assert_eq(_quantities(_player), [4] as Array[int], "what fits")
	assert_eq(_quantities(_source), [0, 2, 1, 0] as Array[int], "the rest stays in the container")
	assert_signal_emit_count(_player, "overflowed", 1, "the HUD's inventory full notice (R-005-20)")


func test_r_012_35_selection_cleared_when_gone() -> void:
	_open(5)
	_tap(_source_grid, CABLES_SLOT)
	var indices: Array[int] = [CABLES_SLOT]
	assert_true(_player.take_from(_source, indices).ok, "the stack leaves by another path")
	assert_eq(_screen.get_selected_index(), ContainerScreen.NO_SELECTION, "the selection is cleared")
	assert_true(_selector().visible, "the selector stays visible")
	assert_false(_selector().is_editable(), "but disabled")


func test_r_012_35_stays_open_when_empty() -> void:
	_open(5)
	_take_all.pressed.emit()
	assert_true(_source.is_empty(), "the container is empty")
	assert_signal_not_emitted(_screen, "close_requested", "the screen stays open")
	_tap(_player_grid, 0)
	_move.pressed.emit()
	assert_eq(_source.count(&"scrap"), 4, "something can be left in it again")


# --- Spec 013 -----------------------------------------------------------------


func test_r_013_12_headers_by_kind() -> void:
	_open(5)
	assert_eq(_label("ContainerHeader").text, _header(HEADER_BOX_KEY, _source), "box name and 3/4")
	assert_eq(_label("PlayerHeader").text, _header(HEADER_INVENTORY_KEY, _player), "inventory and 0/5")
	assert_eq(_label("ContainerHeader").text, tr(HEADER_BOX_KEY) % [3, 4], "used over total slots")
	_open(5, ContainerScreen.Kind.CHEST)
	assert_eq(_label("ContainerHeader").text, _header(HEADER_CHEST_KEY, _source), "a chest says so")
	assert_eq((_screen.get_node("%Title") as Label).text, String(ContainerScreen.CHEST_TITLE_KEY), "titled as a chest")


func test_r_013_12_headers_follow_changes() -> void:
	_open(5)
	_take_all.pressed.emit()
	assert_eq(_label("ContainerHeader").text, tr(HEADER_BOX_KEY) % [0, 4], "the box is empty now")
	assert_eq(_label("PlayerHeader").text, tr(HEADER_INVENTORY_KEY) % [3, 5], "the inventory holds three stacks")
	assert_true(_player.add(&"scrap", 1).ok)
	assert_eq(_label("PlayerHeader").text, tr(HEADER_INVENTORY_KEY) % [3, 5], "a merge uses no new slot")
	assert_true(_source.add(&"iron", 1).ok)
	assert_eq(_label("ContainerHeader").text, tr(HEADER_BOX_KEY) % [1, 4], "a change by another path shows")


func test_r_013_12_invalid_kind_reports_error() -> void:
	_player = _new_inventory(5)
	for kind: Variant in [null, 99, "chest"]:
		var screen: ContainerScreen = SCREEN_SCENE.instantiate() as ContainerScreen
		add_child_autofree(screen)
		var context: Dictionary = _context(kind)
		if kind == null:
			context.erase(ContainerScreen.CONTEXT_KIND)
		screen.setup(context)
		assert_push_error("ContainerScreen", "kind %s is reported" % [kind])
		assert_eq((screen.get_node("%ContainerGrid") as InventoryGrid).get_child_count(), 0, "nothing is shown")


func test_r_013_13_card_without_selection() -> void:
	_open(5)
	var card: Control = _screen.get_node("%ActionCard") as Control
	assert_true(card.visible, "the card is always there")
	assert_true(_hint().visible, "the hint shows")
	assert_eq(_hint().text, String(HINT_SELECT_KEY), "tap a stack")
	assert_true(_selector().visible, "the selector is visible")
	assert_false(_selector().is_editable(), "but disabled")
	assert_true(_move.visible, "the move button is visible")
	assert_true(_move.disabled, "but disabled")
	assert_eq(_move.text, String(MOVE_KEY), "and names no destination")
	assert_true(_place.visible, "place is visible")
	assert_true(_place.disabled, "but disabled")


func test_r_013_13_card_keeps_its_size() -> void:
	_open(5)
	var card: Control = _screen.get_node("%ActionCard") as Control
	var panel: Control = _screen.get_node("Center/Panel") as Control
	await wait_process_frames(2)
	var card_size: Vector2 = card.size
	var panel_size: Vector2 = panel.size
	assert_gt(card_size.x, 0.0, "the card has a size")
	for step: Callable in [
		func() -> void: _tap(_source_grid, SCRAP_SLOT),
		func() -> void: _place.pressed.emit(),
		func() -> void: _tap(_player_grid, 0),
	]:
		step.call()
		await wait_process_frames(2)
		assert_eq(card.size, card_size, "the card keeps its size (mode %s)" % _screen.get_mode())
		assert_eq(panel.size, panel_size, "and so does the panel")
	for locale: String in SUPPORTED_LOCALES:
		var previous: String = TranslationServer.get_locale()
		TranslationServer.set_locale(locale)
		_tap(_player_grid, 0)
		await wait_process_frames(2)
		assert_eq(card.size, card_size, "the card keeps its size in '%s'" % locale)
		_tap(_player_grid, 0)
		TranslationServer.set_locale(previous)


func test_r_013_14_tap_selects_whole_stack() -> void:
	_open(5)
	_tap(_source_grid, SCRAP_SLOT)
	var scrap: ItemData = DataRegistry.get_item(&"scrap")
	assert_eq(_screen.get_selected_side(), ContainerScreen.GridSide.CONTAINER, "the container's stack")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "that slot")
	assert_true(_cells(_source_grid)[SCRAP_SLOT].is_selected(), "the cell shows it")
	assert_same((_screen.get_node("%SelectedIcon") as TextureRect).texture, scrap.icon, "the card shows its icon")
	assert_eq(_label("SelectedLabel").text, tr(SELECTED_KEY) % [tr(scrap.name_key), 4], "its name and quantity")
	assert_eq(_selector().get_value(), 4, "the selector is set to the whole stack")
	assert_true(_selector().is_editable(), "and can be used")
	assert_false(_move.disabled, "move is enabled")
	assert_false(_place.disabled, "place is enabled")


func test_r_013_14_tap_again_clears() -> void:
	_open(5)
	_tap(_source_grid, SCRAP_SLOT)
	_tap(_source_grid, SCRAP_SLOT)
	assert_eq(_screen.get_selected_index(), ContainerScreen.NO_SELECTION, "cleared")
	assert_false(_cells(_source_grid)[SCRAP_SLOT].is_selected(), "the cell no longer shows it")
	assert_null((_screen.get_node("%SelectedIcon") as TextureRect).texture, "the card shows no item")
	assert_eq(_hint().text, String(HINT_SELECT_KEY), "but the hint again")
	assert_true(_move.disabled, "move needs a selection again")


func test_r_013_14_tap_other_switches() -> void:
	_open(5)
	assert_true(_player.add(&"iron", 3).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_tap(_source_grid, CABLES_SLOT)
	assert_eq(_screen.get_selected_index(), CABLES_SLOT, "the other stack of the same grid")
	assert_false(_cells(_source_grid)[SCRAP_SLOT].is_selected(), "the first one is no longer selected")
	_tap(_player_grid, 0)
	assert_eq(_screen.get_selected_side(), ContainerScreen.GridSide.PLAYER, "a stack of the other grid")
	assert_eq(_screen.get_selected_index(), 0, "that slot")
	assert_false(_cells(_source_grid)[CABLES_SLOT].is_selected(), "only one cell is selected")
	assert_eq(_selector().get_value(), 3, "the selector follows the new stack")


func test_r_013_14_tap_never_moves() -> void:
	_open(5)
	assert_true(_player.add(&"iron", 1).ok)
	for step: int in 3:
		_tap(_source_grid, SCRAP_SLOT)
		_tap(_player_grid, 0)
		_tap(_source_grid, IRON_SLOT)
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "the container is unchanged")
	assert_eq(_quantities(_player), [1, 0, 0, 0, 0] as Array[int], "and so is the inventory")


func test_r_013_14_empty_cells_not_pressable() -> void:
	_open(2)
	assert_true(_cells(_player_grid)[0].disabled, "an empty cell cannot be pressed")
	_tap(_source_grid, SCRAP_SLOT)
	assert_true(_cells(_player_grid)[0].disabled, "not even with a selection")
	assert_true(_cells(_source_grid)[EMPTY_SLOT].disabled, "in either grid")


func test_r_013_15_button_names_destination() -> void:
	_open(5)
	assert_true(_player.add(&"iron", 1).ok)
	_tap(_source_grid, SCRAP_SLOT)
	assert_eq(_move.text, String(MOVE_TO_INVENTORY_KEY), "a container stack goes to the inventory")
	_tap(_player_grid, 0)
	assert_eq(_move.text, String(MOVE_TO_BOX_KEY), "an inventory stack goes to the box")
	_open_with(_player, ContainerScreen.Kind.CHEST)
	_tap(_player_grid, 0)
	assert_eq(_move.text, String(STORE_IN_CHEST_KEY), "or is stored in the chest")


func test_r_013_15_move_to_other_side() -> void:
	_open(2)
	assert_true(_player.add(&"scrap", 5).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_choose(3)
	_move.pressed.emit()
	assert_eq(_quantities(_player), [8, 0] as Array[int], "into the stack of the same item")
	assert_eq(_quantities(_source), [1, 2, 1, 0] as Array[int], "the rest stays")
	_tap(_player_grid, 0)
	_move.pressed.emit()
	assert_eq(_quantities(_source), [9, 2, 1, 0] as Array[int], "back to the container")
	assert_true(_player.is_empty(), "the player gave it")


func test_r_013_16_place_mode() -> void:
	_open(2)
	_start_placing(_source_grid, SCRAP_SLOT)
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.PLACING, "placing mode")
	for grid: InventoryGrid in [_source_grid, _player_grid]:
		for cell: InventorySlotView in _cells(grid):
			assert_true(cell.is_target_marked(), "every slot of both grids is outlined")
			assert_false(cell.disabled, "and can be tapped, empty or not")
	assert_eq(_hint().text, String(HINT_PLACE_KEY), "tap the destination slot")
	assert_eq(_place.text, String(CANCEL_KEY), "the button turns into cancel")
	assert_false(_place.disabled, "and can be pressed")


func test_r_013_16_tap_slot_places_and_leaves() -> void:
	_open(3)
	_start_placing(_source_grid, SCRAP_SLOT)
	_choose(3)
	_tap(_player_grid, 2)
	assert_eq(_quantities(_player), [0, 0, 3] as Array[int], "the chosen quantity in the chosen slot")
	assert_eq(_quantities(_source), [1, 2, 1, 0] as Array[int], "the rest stays")
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.BROWSING, "the mode ends")
	assert_eq(_screen.get_selected_index(), ContainerScreen.NO_SELECTION, "a done move clears the selection")
	assert_false(_cells(_player_grid)[0].is_target_marked(), "the outlines go")
	_start_placing(_source_grid, CABLES_SLOT)
	_tap(_source_grid, EMPTY_SLOT)
	assert_eq(_quantities(_source), [1, 0, 1, 2] as Array[int], "also within the same grid")
	_start_placing(_player_grid, 2)
	_tap(_source_grid, IRON_SLOT)
	assert_eq(_source.get_slots()[IRON_SLOT].item.id, &"scrap", "a whole stack swaps")
	assert_eq(_player.get_slots()[2].item.id, &"iron", "with the other item")


func test_r_013_16_cancel_keeps_selection() -> void:
	_open(5)
	_start_placing(_source_grid, SCRAP_SLOT)
	_place.pressed.emit()
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.BROWSING, "cancel leaves the mode")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "keeping the selection")
	assert_eq(_place.text, String(PLACE_KEY), "the button is place again")
	assert_false(_cells(_player_grid)[0].is_target_marked(), "the outlines go")
	assert_true(_cells(_player_grid)[0].disabled, "and empty cells cannot be pressed again")
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "nothing moved")


func test_r_013_16_tap_origin_cancels() -> void:
	_open(5)
	_start_placing(_source_grid, SCRAP_SLOT)
	_tap(_source_grid, SCRAP_SLOT)
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.BROWSING, "tapping the origin leaves the mode")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "keeping the selection")
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "nothing moved")


func test_r_013_16_other_actions_disabled() -> void:
	_open(5)
	_start_placing(_source_grid, SCRAP_SLOT)
	assert_false(_selector().is_editable(), "the selector is disabled")
	assert_true(_selector().visible, "not hidden")
	assert_true(_move.disabled, "move is disabled")
	assert_true(_take_all.disabled, "take all is disabled")
	_take_all.pressed.emit()
	_move.pressed.emit()
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "nothing moved")


func test_r_013_16_stack_gone_leaves_mode() -> void:
	_open(5)
	_start_placing(_source_grid, CABLES_SLOT)
	var indices: Array[int] = [CABLES_SLOT]
	assert_true(_player.take_from(_source, indices).ok, "the stack leaves by another path")
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.BROWSING, "the mode ends")
	assert_eq(_screen.get_selected_index(), ContainerScreen.NO_SELECTION, "the selection is cleared")
	assert_false(_cells(_player_grid)[1].is_target_marked(), "the outlines go")


func test_r_013_17_back_leaves_place_mode() -> void:
	_open(5)
	assert_false(_screen.handle_back(), "without the mode, back closes the screen")
	_start_placing(_source_grid, SCRAP_SLOT)
	assert_true(_screen.handle_back(), "in the mode, back is handled by the screen")
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.BROWSING, "and leaves the mode")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "keeping the selection")
	assert_false(_screen.handle_back(), "a second back closes the screen")


func test_r_013_17_outside_tap_leaves_place_mode() -> void:
	_player = _new_inventory(5)
	var manager: UIManager = UI_MANAGER_SCENE.instantiate() as UIManager
	manager.catalog = load(SCREENS_PATH) as UIScreenCatalog
	add_child_autofree(manager)
	_screen = manager.open(ContainerScreen.SCREEN_ID, _context(ContainerScreen.Kind.LOOT_BOX)) as ContainerScreen
	assert_not_null(_screen, "the manager opens the screen")
	if _screen == null:
		return
	_find_controls()
	_start_placing(_source_grid, SCRAP_SLOT)
	_screen.back_requested.emit()
	assert_true(manager.is_modal_open(), "a tap outside does not close the screen in placing mode")
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.BROWSING, "it leaves the mode")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "keeping the selection")
	_screen.back_requested.emit()
	assert_false(manager.is_modal_open(), "outside the mode it closes the screen")


func test_r_013_18_take_all_disabled_when_empty() -> void:
	_open(5)
	assert_false(_take_all.disabled, "the container holds stacks")
	_take_all.pressed.emit()
	assert_true(_take_all.disabled, "empty: nothing to take")
	assert_true(_take_all.visible, "but still shown")
	assert_true(_source.add(&"iron", 1).ok)
	assert_false(_take_all.disabled, "something to take again")


func test_r_013_19_refusal_shows_reason_keeps_selection() -> void:
	_open(1)
	assert_true(_player.add(&"iron", 1).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_choose(2)
	_place.pressed.emit()
	_tap(_player_grid, 0)
	assert_true(_notice().visible, "the refusal shows in the card")
	assert_eq(_notice().text, String(InventoryRules.ERR_PARTIAL_SWAP), "only whole stacks swap")
	assert_eq(_screen.get_mode(), ContainerScreen.Mode.PLACING, "the mode stays to try another slot")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "and the selection too")
	_place.pressed.emit()
	assert_false(_notice().visible, "leaving the mode hides a reason that no longer applies")
	_choose(4)
	_move.pressed.emit()
	assert_eq(_notice().text, String(InventoryRules.ERR_NO_ROOM), "nothing fits on the other side")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "the selection stays")
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "nothing moved")
	assert_true((_screen.get_node("%ActionCard") as Node).is_ancestor_of(_notice()), "the notice lives in the card")
	_place.pressed.emit()
	_tap(_player_grid, 0)
	assert_eq(_player.get_slots()[0].item.id, &"scrap", "the whole stack swapped")
	assert_false(_notice().visible, "a move that works hides the notice")


func test_r_013_19_done_clears_and_highlights() -> void:
	var duration: float = (load(CONTROLS_PATH) as ControlConfigData).move_highlight_s
	_open(5)
	assert_true(_player.add(&"scrap", 1).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_move.pressed.emit()
	assert_eq(_screen.get_selected_index(), ContainerScreen.NO_SELECTION, "a done move clears the selection")
	assert_eq(_highlighted(_player_grid), [0] as Array[int], "the slot that received it lights up")
	assert_eq(_highlighted(_source_grid), [] as Array[int], "the origin does not")
	_cells(_player_grid)[0].advance_highlight(duration)
	assert_false(_cells(_player_grid)[0].is_highlighted(), "for the duration of BALANCE §11")
	_start_placing(_source_grid, CABLES_SLOT)
	_tap(_player_grid, 3)
	assert_eq(_highlighted(_player_grid), [3] as Array[int], "placing lights up the chosen slot")
	_cells(_player_grid)[3].advance_highlight(duration)
	_take_all.pressed.emit()
	assert_eq(_highlighted(_player_grid), [1] as Array[int], "take all lights up the slots it filled")


func test_r_013_19_take_all_refusal_shows_reason() -> void:
	_open(1)
	var piece: Array[ItemStack] = [CraftingSystem.create_result(DataRegistry.get_item(&"basic_core"))]
	assert_true(_player.add_stacks(piece).ok, "the only slot holds a piece")
	_take_all.pressed.emit()
	assert_true(_notice().visible, "nothing fits: the card says why")
	assert_eq(_notice().text, String(InventoryComponent.MSG_INVENTORY_FULL), "the inventory is full")
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "nothing moved")


func test_r_013_19_swap_highlights_destination_only() -> void:
	_open(5)
	_start_placing(_source_grid, CABLES_SLOT)
	_tap(_source_grid, IRON_SLOT)
	assert_eq(_source.get_slots()[IRON_SLOT].item.id, &"cables", "the stacks swapped")
	assert_eq(_highlighted(_source_grid), [IRON_SLOT] as Array[int], "only the destination lights up")


func test_r_013_19_new_selection_hides_reason() -> void:
	_open(1)
	assert_true(_player.add(&"iron", 1).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_move.pressed.emit()
	assert_true(_notice().visible, "refused")
	_tap(_source_grid, CABLES_SLOT)
	assert_false(_notice().visible, "another selection hides the notice")


func test_r_013_22_no_platform_checks() -> void:
	for path: String in SCREEN_SCRIPTS:
		var code: String = FileAccess.get_file_as_string(path)
		assert_ne(code, "", "%s is readable" % path)
		for check: String in PLATFORM_CHECKS:
			assert_false(code.contains(check), "%s has no %s" % [path, check])


# --- Closing by tapping outside the panel (R-012-46, plan D16) -----------------


func _push_tap(viewport_position: Vector2) -> void:
	# The GUI places a control added this frame only on the next one.
	await wait_process_frames(1)
	var runner: CanvasLayer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if runner != null:
		runner.visible = false
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = viewport_position
		event.global_position = viewport_position
		get_viewport().push_input(event, true)
	if runner != null:
		runner.visible = true


func _panel() -> Control:
	return _screen.get_node("Center/Panel") as Control


func test_r_012_46_closes_on_outside_tap() -> void:
	_open(5)
	assert_true(_screen.closes_on_outside_tap, "this screen closes on an outside tap")
	await _push_tap(Vector2(8, 8))
	assert_signal_emit_count(_screen, "back_requested", 1, "a tap outside the panel asks to go back once")


func test_r_012_46_tap_inside_panel_does_not_close() -> void:
	_open(5)
	await wait_process_frames(1)
	await _push_tap(_panel().get_global_rect().get_center())
	assert_signal_not_emitted(_screen, "back_requested", "a tap on the panel is not outside")


func test_r_012_46_panel_stops_the_mouse() -> void:
	_open(5)
	assert_eq(_panel().mouse_filter, Control.MOUSE_FILTER_STOP, "the panel stops the mouse")
	assert_eq((_screen.get_node("Center") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "centring lets it through")
	assert_eq((_screen.get_node("Backdrop") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "the backdrop too")
	# One outer panel: no gaps between panels count as outside. The action card
	# of spec 013 is a panel inside it.
	var panels: Array[Node] = _screen.find_children("*", "PanelContainer", true, false)
	var outer: Array[Node] = panels.filter(func(node: Node) -> bool: return not _panel().is_ancestor_of(node))
	assert_eq(outer.size(), 1, "one outer panel")


# --- Spec 014: chassis level --------------------------------------------------


## A Control of the design size of project.godot at the origin: headless GUT
## has a 64x64 window whose visible rect is not the design size (plan 014 §5.1).
func _design_host() -> Control:
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var host: Control = Control.new()
	host.position = Vector2.ZERO
	host.size = Vector2(width, height)
	add_child_autofree(host)
	return host


func _last_level_slots() -> int:
	var levels: ChassisLevelData = load(CHASSIS_LEVELS_PATH) as ChassisLevelData
	return levels.get_inventory_slots(levels.get_level_count())


## Every cell inside the screen, apart from the others and stopping the mouse.
func _assert_cells_fit(cells: Array[InventorySlotView], screen_rect: Rect2, label: String) -> void:
	for index: int in cells.size():
		var rect: Rect2 = cells[index].get_global_rect()
		assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "%s cell %d is laid out (%s)" % [label, index, rect])
		assert_true(screen_rect.encloses(rect), "%s cell %d %s inside %s" % [label, index, rect, screen_rect])
		assert_eq(cells[index].mouse_filter, Control.MOUSE_FILTER_STOP, "%s cell %d takes taps and clicks" % [label, index])
		for other: int in range(index + 1, cells.size()):
			assert_false(rect.intersects(cells[other].get_global_rect()), "%s cells %d and %d apart" % [label, index, other])


func test_r_014_13_new_slots_and_occupancy_while_open() -> void:
	_open(5)
	_take_all.pressed.emit()
	var slots: int = _last_level_slots()
	_player.set_slot_count(slots)
	assert_eq(_cells(_player_grid).size(), slots, "a cell for every slot, without reopening")
	assert_eq(_label("PlayerHeader").text, _header(HEADER_INVENTORY_KEY, _player), "the header shows the new total")
	assert_eq(_label("PlayerHeader").text, tr(HEADER_INVENTORY_KEY) % [3, slots], "used over the new total")


func test_r_014_14_last_level_slots_fit_screen() -> void:
	var host: Control = _design_host()
	_player = _new_inventory(_last_level_slots())
	for kind: ContainerScreen.Kind in [ContainerScreen.Kind.LOOT_BOX, ContainerScreen.Kind.CHEST]:
		_screen = SCREEN_SCENE.instantiate() as ContainerScreen
		host.add_child(_screen)
		_find_controls()
		_screen.setup(_context(kind))
		await wait_process_frames(2)
		var screen_rect: Rect2 = Rect2(Vector2.ZERO, host.size)
		assert_eq(_cells(_player_grid).size(), _last_level_slots(), "one cell per slot of the last level")
		assert_true(screen_rect.encloses(_panel().get_global_rect()), "the panel fits (kind %d)" % kind)
		_assert_cells_fit(_cells(_player_grid), screen_rect, "inventory (kind %d)" % kind)
		_assert_cells_fit(_cells(_source_grid), screen_rect, "container (kind %d)" % kind)
		_screen.free()
