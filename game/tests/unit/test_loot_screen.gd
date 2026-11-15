extends GutTest
## LootScreen (spec 005): the box's slots and the player's slots with the same
## cells (R-005-25); tapping a box cell takes that stack (R-005-18) and "take
## all" takes every stack in slot order, as much as fits (R-005-19); the screen
## asks to be closed when the box is empty (R-005-21); both grids follow
## inventory_changed (R-005-26); no control takes focus (R-005-24) and the
## texts are translation keys in ES and EN (R-005-30).
## Headless cannot click Controls (ADR 0002): pressed is emitted by hand.

const SCREEN_SCENE := preload("res://scenes/ui/loot_screen.tscn")
const TITLE_KEY := &"LOOT_TITLE"
const TAKE_ALL_KEY := &"LOOT_TAKE_ALL"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const SCRAP_SLOT := 0
const CABLES_SLOT := 1
const IRON_SLOT := 2

var _source: InventoryComponent
var _player: InventoryComponent
var _screen: LootScreen
var _source_grid: InventoryGrid
var _player_grid: InventoryGrid
var _take_all: Button


func before_each() -> void:
	_source = _new_inventory(3)
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
	_screen = SCREEN_SCENE.instantiate() as LootScreen
	add_child_autofree(_screen)
	_source_grid = _screen.get_node("%SourceGrid") as InventoryGrid
	_player_grid = _screen.get_node("%PlayerGrid") as InventoryGrid
	_take_all = _screen.get_node("%TakeAllButton") as Button
	watch_signals(_screen)
	_screen.setup({LootScreen.CONTEXT_SOURCE: _source, LootScreen.CONTEXT_INVENTORY: _player})


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


func test_r_005_25_both_grids() -> void:
	_open(5)
	var source_cells: Array[InventorySlotView] = _cells(_source_grid)
	assert_eq(source_cells.size(), 3, "one cell per slot of the box")
	assert_eq(_cells(_player_grid).size(), 5, "one cell per slot of the player")
	if source_cells.size() != 3:
		return
	assert_same(_icon(source_cells[SCRAP_SLOT]), DataRegistry.get_item(&"scrap").icon, "box icon")
	assert_eq(_quantity(source_cells[SCRAP_SLOT]), "4", "box quantity")
	assert_eq(_quantity(source_cells[CABLES_SLOT]), "2", "box quantity")
	assert_eq(_quantity(source_cells[IRON_SLOT]), "1", "box quantity")
	for cell: InventorySlotView in _cells(_player_grid):
		assert_null(_icon(cell), "the player's cells are empty")
		assert_true(cell.disabled, "and cannot be pressed: the screen only takes")


func test_r_005_18_tap_box_cell_takes_stack() -> void:
	_open(5)
	_cells(_source_grid)[CABLES_SLOT].pressed.emit()
	assert_eq(_player.count(&"cables"), 2, "the tapped stack is in the player's inventory")
	assert_eq(_source.count(&"cables"), 0, "and left the box")
	assert_eq(_source.count(&"scrap"), 4, "the other stacks stay in the box")
	assert_eq(_source.count(&"iron"), 1, "the other stacks stay in the box")
	assert_signal_not_emitted(_screen, "close_requested", "the box is not empty yet")


func test_r_005_18_tap_takes_as_much_as_fits() -> void:
	var cables_max: int = DataRegistry.get_item(&"cables").stack_max
	var player: InventoryComponent = _new_inventory(1)
	player.add(&"cables", cables_max - 1)
	_open_with(player)
	_cells(_source_grid)[CABLES_SLOT].pressed.emit()
	assert_eq(_player.count(&"cables"), cables_max, "only one more fits")
	assert_eq(_source.count(&"cables"), 1, "the rest stays in the box")


func test_r_005_18_occupied_box_cells_can_be_pressed() -> void:
	_open(5)
	for cell: InventorySlotView in _cells(_source_grid):
		assert_false(cell.disabled, "a box cell with a stack can be pressed")


func test_r_005_19_take_all_in_slot_order() -> void:
	# Two slots: scrap and cables enter in slot order, the iron does not fit.
	_open(2)
	_take_all.pressed.emit()
	assert_eq(_quantities(_player), [4, 2] as Array[int], "taken in the box's slot order")
	assert_eq(_quantities(_source), [0, 0, 1] as Array[int], "what does not fit stays in the box")
	assert_signal_not_emitted(_screen, "close_requested", "the box still holds the iron")


func test_r_005_19_take_all_moves_everything_that_fits() -> void:
	_open(5)
	_take_all.pressed.emit()
	assert_eq(_player.count(&"scrap"), 4)
	assert_eq(_player.count(&"cables"), 2)
	assert_eq(_player.count(&"iron"), 1)
	assert_true(_source.is_empty(), "the box gave everything")


func test_r_005_21_requests_close_when_box_empty() -> void:
	_open(5)
	_take_all.pressed.emit()
	assert_signal_emit_count(_screen, "close_requested", 1, "an empty box closes its screen")


func test_r_005_21_last_tap_requests_close() -> void:
	_open(5)
	for slot: int in [SCRAP_SLOT, CABLES_SLOT]:
		_cells(_source_grid)[slot].pressed.emit()
	assert_signal_not_emitted(_screen, "close_requested")
	_cells(_source_grid)[IRON_SLOT].pressed.emit()
	assert_signal_emit_count(_screen, "close_requested", 1, "taking the last stack closes it")


func test_r_005_26_both_sides_update() -> void:
	_open(5)
	_cells(_source_grid)[CABLES_SLOT].pressed.emit()
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
	for grid: InventoryGrid in [_source_grid, _player_grid]:
		for cell: InventorySlotView in _cells(grid):
			assert_eq(cell.focus_mode, Control.FOCUS_NONE, "cells never take keyboard focus")


func test_r_005_30_keys_translated() -> void:
	_open(5)
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, String(TITLE_KEY), "the title is a translation key")
	assert_eq(_take_all.text, String(TAKE_ALL_KEY), "the button is a translation key")
	assert_ne(title.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "the title is translated")
	assert_ne(_take_all.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "the button too")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for key: StringName in [TITLE_KEY, TAKE_ALL_KEY]:
			var text: String = translations[0].get_message(key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, key])


func test_screen_consumes_touches() -> void:
	_open(5)
	assert_eq(_screen.mouse_filter, Control.MOUSE_FILTER_STOP, "touches stop at the screen")
	assert_eq(_screen.anchor_right, 1.0, "it covers the whole width")
	assert_eq(_screen.anchor_bottom, 1.0, "and the whole height")


func test_setup_without_inventories_reports_error() -> void:
	var screen: LootScreen = SCREEN_SCENE.instantiate() as LootScreen
	add_child_autofree(screen)
	screen.setup({LootScreen.CONTEXT_SOURCE: _source})
	assert_push_error("LootScreen")
