extends GutTest
## InventoryScreen (spec 005): one cell per slot with the item's icon and
## quantity, and an empty look for empty slots (R-005-25); it follows
## inventory_changed and never polls (R-005-26); its title is a translation
## key in ES and EN (R-005-30). Headless cannot click Controls (ADR 0002).

const SCREEN_SCENE := preload("res://scenes/ui/inventory_screen.tscn")
const TITLE_KEY := &"INVENTORY_TITLE"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const SLOT_COUNT := 5

var _inventory: InventoryComponent
var _screen: InventoryScreen
var _grid: InventoryGrid


func before_each() -> void:
	_inventory = InventoryComponent.new()
	add_child_autofree(_inventory)
	_inventory.set_slot_count(SLOT_COUNT)
	_screen = SCREEN_SCENE.instantiate() as InventoryScreen
	add_child_autofree(_screen)
	_grid = _screen.get_node("%Grid") as InventoryGrid


func _setup() -> void:
	_screen.setup({InventoryScreen.CONTEXT_INVENTORY: _inventory})


func _cells() -> Array[InventorySlotView]:
	var cells: Array[InventorySlotView] = []
	for child: Node in _grid.get_children():
		var cell: InventorySlotView = child as InventorySlotView
		if cell != null and not cell.is_queued_for_deletion():
			cells.append(cell)
	return cells


func _icon(cell: InventorySlotView) -> Texture2D:
	return (cell.get_node("%Icon") as TextureRect).texture


func _quantity(cell: InventorySlotView) -> String:
	return (cell.get_node("%Quantity") as Label).text


func test_r_005_25_one_cell_per_slot_with_icon_and_quantity() -> void:
	_inventory.add(&"scrap", 7)
	_inventory.add(&"iron", 2)
	_setup()
	var cells: Array[InventorySlotView] = _cells()
	assert_eq(cells.size(), SLOT_COUNT, "one cell per slot")
	if cells.size() != SLOT_COUNT:
		return
	assert_same(_icon(cells[0]), DataRegistry.get_item(&"scrap").icon, "slot 0 shows the scrap icon")
	assert_eq(_quantity(cells[0]), "7", "and its quantity")
	assert_same(_icon(cells[1]), DataRegistry.get_item(&"iron").icon, "slot 1 shows the iron icon")
	assert_eq(_quantity(cells[1]), "2", "and its quantity")


func test_r_005_25_empty_cells() -> void:
	_inventory.add(&"scrap", 7)
	_setup()
	var cells: Array[InventorySlotView] = _cells()
	assert_eq(cells.size(), SLOT_COUNT, "one cell per slot")
	for i: int in range(1, cells.size()):
		assert_null(_icon(cells[i]), "empty slot %d has no icon" % i)
		assert_eq(_quantity(cells[i]), "", "empty slot %d has no quantity" % i)


func test_r_005_25_cells_follow_slot_count() -> void:
	_setup()
	assert_eq(_cells().size(), SLOT_COUNT, "one cell per slot")
	_inventory.set_slot_count(SLOT_COUNT + 2)
	assert_eq(_cells().size(), SLOT_COUNT + 2, "new slots get their cells")


func test_r_005_25_cells_cannot_be_pressed() -> void:
	_inventory.add(&"scrap", 7)
	_setup()
	watch_signals(_grid)
	for cell: InventorySlotView in _cells():
		assert_true(cell.disabled, "the inventory screen only shows")
		assert_eq(cell.focus_mode, Control.FOCUS_NONE, "cells never take keyboard focus")
		cell.pressed.emit()
	assert_signal_not_emitted(_grid, "slot_pressed")


func test_r_005_26_updates_on_inventory_changed() -> void:
	_setup()
	var cells: Array[InventorySlotView] = _cells()
	if cells.is_empty():
		fail_test("the screen has no cells")
		return
	assert_null(_icon(cells[0]), "empty at the start")
	_inventory.add(&"cables", 3)
	assert_same(_icon(cells[0]), DataRegistry.get_item(&"cables").icon, "the icon appears by itself")
	assert_eq(_quantity(cells[0]), "3", "with its quantity")
	_inventory.add(&"cables", 4)
	assert_eq(_quantity(cells[0]), "7", "the quantity follows the inventory")
	_inventory.remove(&"cables", 7)
	assert_null(_icon(cells[0]), "an emptied slot looks empty again")
	assert_eq(_quantity(cells[0]), "", "without quantity")


func test_r_005_26_does_not_poll() -> void:
	_setup()
	assert_false(_screen.is_processing(), "no _process in the screen")
	assert_false(_screen.is_physics_processing(), "no _physics_process in the screen")
	assert_false(_grid.is_processing(), "no _process in the grid")
	assert_false(_grid.is_physics_processing(), "no _physics_process in the grid")


func test_r_005_30_title_key_translated() -> void:
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, String(TITLE_KEY), "the title is a translation key")
	assert_ne(title.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(TITLE_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, TITLE_KEY])


func test_r_005_30_quantities_are_not_translated() -> void:
	_inventory.add(&"scrap", 7)
	_setup()
	var quantity: Label = _cells()[0].get_node("%Quantity") as Label
	assert_eq(quantity.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "a number is not a key")


func test_screen_consumes_touches() -> void:
	# The floating joystick only appears outside HUD controls (R-002-10).
	assert_eq(_screen.mouse_filter, Control.MOUSE_FILTER_STOP, "touches stop at the screen")
	assert_eq(_screen.anchor_right, 1.0, "it covers the whole width")
	assert_eq(_screen.anchor_bottom, 1.0, "and the whole height")


func test_setup_without_inventory_reports_error() -> void:
	_screen.setup({})
	assert_push_error("InventoryScreen")
	assert_eq(_cells().size(), 0, "nothing is shown")
