extends GutTest
## ContainerScreen (spec 012): a chest or an opened loot box next to the
## player's inventory, replacing the loot screen of spec 005 (R-012-37, plan
## D13). Both grids show their slots with the same cells (R-005-25); the
## container is a 2-column grid with a quantity selector, "Transfer" and "Take
## all" (R-012-27). A tap selects a whole stack, again clears it (R-012-28); a
## tap on any slot moves the chosen quantity there (R-012-29); "Transfer" sends
## it to the other side (R-012-30); "Take all" takes every stack in slot order,
## as much as fits (R-005-19, R-012-31). Both grids follow inventory_changed,
## a selection whose stack is gone is cleared, and the screen never closes by
## itself (R-005-26, R-012-35). Refusals show in its own notice (plan D22). It
## closes on a tap outside its panel (R-012-46). No control takes focus
## (R-005-24) and the texts are keys in ES and EN (R-005-30, R-012-45).
## Tests moved from test_loot_screen.gd keep their names (plan §5.4).
## Headless cannot click Controls (ADR 0002): pressed is emitted by hand.

const SCREEN_SCENE := preload("res://scenes/ui/container_screen.tscn")
const TITLE_KEY := &"LOOT_TITLE"
const TAKE_ALL_KEY := &"CONTAINER_TAKE_ALL"
const TRANSFER_KEY := &"CONTAINER_TRANSFER"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const KEYS: Array[StringName] = [
	&"LOOT_TITLE",
	&"CHEST_TITLE",
	&"CONTAINER_TAKE_ALL",
	&"CONTAINER_TRANSFER",
	&"ERR_PARTIAL_SWAP",
	&"ERR_SLOT_FULL",
	&"ERR_NO_ROOM",
]
const CONTAINER_SLOTS := 4
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
var _transfer: Button


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
func _open(player_slots: int) -> void:
	_player = _new_inventory(player_slots)
	_open_with(_player)


func _open_with(player: InventoryComponent) -> void:
	_player = player
	_screen = SCREEN_SCENE.instantiate() as ContainerScreen
	add_child_autofree(_screen)
	_source_grid = _screen.get_node("%ContainerGrid") as InventoryGrid
	_player_grid = _screen.get_node("%PlayerGrid") as InventoryGrid
	_take_all = _screen.get_node("%TakeAllButton") as Button
	_transfer = _screen.get_node("%TransferButton") as Button
	watch_signals(_screen)
	_screen.setup({
		ContainerScreen.CONTEXT_CONTAINER: _source,
		ContainerScreen.CONTEXT_INVENTORY: _player,
		ContainerScreen.CONTEXT_TITLE: TITLE_KEY,
	})


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


func _tap(grid: InventoryGrid, index: int) -> void:
	_cells(grid)[index].pressed.emit()


## Sets the selector to quantity through its own slider.
func _choose(quantity: int) -> void:
	(_selector().get_node("%Slider") as HSlider).value = quantity


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
	_transfer.pressed.emit()
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
	assert_eq(_transfer.focus_mode, Control.FOCUS_NONE, "transfer never takes keyboard focus")
	for grid: InventoryGrid in [_source_grid, _player_grid]:
		for cell: InventorySlotView in _cells(grid):
			assert_eq(cell.focus_mode, Control.FOCUS_NONE, "cells never take keyboard focus")


func test_r_005_30_keys_translated() -> void:
	_open(5)
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, String(TITLE_KEY), "the title is a translation key")
	assert_eq(_take_all.text, String(TAKE_ALL_KEY), "the button is a translation key")
	assert_eq(_transfer.text, String(TRANSFER_KEY), "the button is a translation key")
	assert_ne(title.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "the title is translated")
	assert_ne(_take_all.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "the button too")
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


func test_r_012_27_grids_selector_and_buttons() -> void:
	_open(5)
	assert_eq(_source_grid.columns, 2, "the container is a 2x2 grid")
	assert_not_null(_selector(), "a quantity selector")
	assert_not_null(_transfer, "a transfer button")
	assert_not_null(_take_all, "a take-all button")
	assert_false(_selector().visible, "no selector before a selection")
	assert_true(_transfer.disabled, "transfer needs a selection")
	assert_false(_take_all.disabled, "take all is always there")


func test_r_012_28_tap_selects_whole_stack() -> void:
	_open(5)
	_tap(_source_grid, SCRAP_SLOT)
	assert_eq(_screen.get_selected_side(), ContainerScreen.GridSide.CONTAINER, "the container's stack")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "that slot")
	assert_true(_cells(_source_grid)[SCRAP_SLOT].is_selected(), "the cell shows it")
	assert_true(_selector().visible, "the selector shows")
	assert_eq(_selector().get_value(), 4, "set to the whole stack")
	assert_false(_transfer.disabled, "transfer is enabled")
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "a tap moves nothing")


func test_r_012_28_tap_again_clears() -> void:
	_open(5)
	_tap(_source_grid, SCRAP_SLOT)
	_tap(_source_grid, SCRAP_SLOT)
	assert_eq(_screen.get_selected_index(), ContainerScreen.NO_SELECTION, "cleared")
	assert_false(_cells(_source_grid)[SCRAP_SLOT].is_selected(), "the cell no longer shows it")
	assert_false(_selector().visible, "the selector hides")
	assert_true(_transfer.disabled, "transfer needs a selection again")


func test_r_012_29_empty_cells_pressable_only_with_selection() -> void:
	_open(2)
	assert_true(_cells(_player_grid)[0].disabled, "an empty cell cannot be pressed without a selection")
	assert_true(_cells(_source_grid)[EMPTY_SLOT].disabled, "nor in the container")
	_tap(_source_grid, SCRAP_SLOT)
	assert_false(_cells(_player_grid)[0].disabled, "with a selection, an empty cell is a target")
	assert_false(_cells(_source_grid)[EMPTY_SLOT].disabled, "in both grids")
	_tap(_source_grid, SCRAP_SLOT)
	assert_true(_cells(_player_grid)[0].disabled, "not after clearing it")


func test_r_012_29_tap_target_moves() -> void:
	_open(3)
	_tap(_source_grid, SCRAP_SLOT)
	_choose(3)
	_tap(_player_grid, 2)
	assert_eq(_quantities(_player), [0, 0, 3] as Array[int], "the chosen quantity in the chosen slot")
	assert_eq(_quantities(_source), [1, 2, 1, 0] as Array[int], "the rest stays")
	assert_eq(_screen.get_selected_index(), ContainerScreen.NO_SELECTION, "a done move clears the selection")
	_tap(_source_grid, CABLES_SLOT)
	_tap(_source_grid, EMPTY_SLOT)
	assert_eq(_quantities(_source), [1, 0, 1, 2] as Array[int], "also within the same grid")
	_tap(_player_grid, 2)
	_tap(_source_grid, IRON_SLOT)
	assert_eq(_source.get_slots()[IRON_SLOT].item.id, &"scrap", "a whole stack swaps")
	assert_eq(_player.get_slots()[2].item.id, &"iron", "with the other item")


func test_r_012_29_refusal_shows_notice_and_keeps_selection() -> void:
	_open(1)
	assert_true(_player.add(&"iron", 1).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_choose(2)
	_tap(_player_grid, 0)
	assert_true(_notice().visible, "the refusal shows in the screen")
	assert_eq(_notice().text, String(InventoryRules.ERR_PARTIAL_SWAP), "only whole stacks swap")
	assert_eq(_screen.get_selected_index(), SCRAP_SLOT, "the selection stays")
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "nothing moved")
	_choose(4)
	_tap(_player_grid, 0)
	assert_false(_notice().visible, "a move that works hides the notice")


func test_r_012_29_new_selection_hides_notice() -> void:
	_open(1)
	assert_true(_player.add(&"iron", 1).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_choose(2)
	_tap(_player_grid, 0)
	assert_true(_notice().visible, "refused")
	_tap(_source_grid, SCRAP_SLOT)
	assert_false(_notice().visible, "clearing the selection hides the notice")


func test_r_012_30_transfer_button() -> void:
	_open(2)
	assert_true(_player.add(&"scrap", 5).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_choose(3)
	_transfer.pressed.emit()
	assert_eq(_quantities(_player), [8, 0] as Array[int], "into the stack of the same item")
	assert_eq(_quantities(_source), [1, 2, 1, 0] as Array[int], "the rest stays")
	_tap(_player_grid, 0)
	_transfer.pressed.emit()
	assert_eq(_quantities(_source), [9, 2, 1, 0] as Array[int], "back to the container")
	assert_true(_player.is_empty(), "the player gave it")


func test_r_012_30_no_room_shows_notice() -> void:
	_open(1)
	assert_true(_player.add(&"iron", 1).ok)
	_tap(_source_grid, SCRAP_SLOT)
	_transfer.pressed.emit()
	assert_eq(_notice().text, String(InventoryRules.ERR_NO_ROOM), "nothing fits on the other side")
	assert_eq(_quantities(_source), [4, 2, 1, 0] as Array[int], "nothing moved")


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
	assert_false(_selector().visible, "and the selector hides")


func test_r_012_35_stays_open_when_empty() -> void:
	_open(5)
	_take_all.pressed.emit()
	assert_true(_source.is_empty(), "the container is empty")
	assert_signal_not_emitted(_screen, "close_requested", "the screen stays open")
	var cell: InventorySlotView = _cells(_player_grid)[0]
	cell.pressed.emit()
	_transfer.pressed.emit()
	assert_eq(_source.count(&"scrap"), 4, "something can be left in it again")


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
	var panels: Array[Node] = _screen.find_children("*", "PanelContainer", true, false)
	assert_eq(panels.size(), 1, "one panel: no gaps between panels count as outside")
