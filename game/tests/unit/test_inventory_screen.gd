extends GutTest
## InventoryScreen (spec 005): one cell per slot with the item's icon and
## quantity, and an empty look for empty slots (R-005-25); it follows
## inventory_changed and never polls (R-005-26); its title is a translation
## key in ES and EN (R-005-30). Headless cannot click Controls (ADR 0002).
## Spec 008: occupied cells can be pressed without taking focus (R-008-38), a
## tap selects a stack and shows the quantity selector (R-008-38), the throw
## button asks the thrower for slot and quantity (R-008-39), it needs a
## selection (R-008-41) and the screen never changes the inventory
## itself (R-008-42).
## Spec 012: a "Use" button for a selected consumable (R-012-25), disabled for
## a material or without selection, that asks the robot to use that slot.

const SCREEN_SCENE := preload("res://scenes/ui/inventory_screen.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const TITLE_KEY := &"INVENTORY_TITLE"
const THROW_KEY := &"INVENTORY_THROW"
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


func _new_thrower() -> Robot:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.set_physics_process(false)
	return robot


func _setup_with_thrower(robot: Robot) -> void:
	_screen.setup(
		{InventoryScreen.CONTEXT_INVENTORY: _inventory, InventoryScreen.CONTEXT_THROWER: robot}
	)


func _selector() -> QuantitySelector:
	return _screen.get_node("%QuantitySelector") as QuantitySelector


func _selector_slider(selector: QuantitySelector) -> HSlider:
	return selector.get_node("%Slider") as HSlider


func _throw_button() -> Button:
	return _screen.get_node("%ThrowButton") as Button


## One "id x quantity" entry per slot, empty slots as "-".
func _describe(inventory: InventoryComponent) -> Array[String]:
	var lines: Array[String] = []
	for stack: ItemStack in inventory.get_slots():
		lines.append("-" if stack == null else "%s x%d" % [stack.item.id, stack.quantity])
	return lines


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


func test_r_008_38_cells_pressable_without_focus() -> void:
	_inventory.add(&"scrap", 7)
	_inventory.add(&"iron", 2)
	_setup()
	watch_signals(_grid)
	var cells: Array[InventorySlotView] = _cells()
	assert_eq(cells.size(), SLOT_COUNT, "one cell per slot")
	for index: int in cells.size():
		var occupied: bool = index < 2
		assert_eq(cells[index].disabled, not occupied, "cell %d: only occupied cells are enabled" % index)
		assert_eq(cells[index].focus_mode, Control.FOCUS_NONE, "cells never take keyboard focus")
	cells[1].pressed.emit()
	assert_signal_emit_count(_grid, "slot_pressed", 1, "pressing an occupied cell reports it")
	assert_signal_emitted_with_parameters(_grid, "slot_pressed", [1])


func test_r_008_38_tap_selects_and_shows_selector() -> void:
	var robot: Robot = _new_thrower()
	_inventory.add(&"scrap", 7)
	_inventory.add(&"iron", 2)
	_setup_with_thrower(robot)
	var selector: QuantitySelector = _selector()
	assert_false(selector.visible, "no selector before a selection")
	var cells: Array[InventorySlotView] = _cells()
	cells[1].pressed.emit()
	for index: int in cells.size():
		assert_eq(cells[index].is_selected(), index == 1, "only cell 1 is selected (cell %d)" % index)
	assert_true(selector.visible, "the selector shows")
	assert_eq(_selector_slider(selector).max_value, 2.0, "its maximum is the stack")
	assert_eq(selector.get_value(), 2, "and it starts at the whole stack")
	cells[0].pressed.emit()
	assert_true(cells[0].is_selected(), "another tap moves the selection")
	assert_false(cells[1].is_selected(), "and clears the previous one")
	assert_eq(selector.get_value(), 7, "with the quantity of that stack")


func test_r_008_39_throw_requests_slot_and_quantity() -> void:
	var robot: Robot = _new_thrower()
	_inventory.add(&"scrap", 7)
	_setup_with_thrower(robot)
	watch_signals(robot)
	watch_signals(_screen)
	_cells()[0].pressed.emit()
	_throw_button().pressed.emit()
	assert_signal_emit_count(robot, "throw_requested", 1, "one request")
	assert_signal_emitted_with_parameters(robot, "throw_requested", [robot, 0, 7], 0)
	var selector: QuantitySelector = _selector()
	(selector.get_node("%MinusButton") as Button).pressed.emit()
	(selector.get_node("%MinusButton") as Button).pressed.emit()
	_throw_button().pressed.emit()
	assert_signal_emit_count(robot, "throw_requested", 2, "a second request")
	assert_signal_emitted_with_parameters(robot, "throw_requested", [robot, 0, 5], 1)
	assert_signal_not_emitted(_screen, "close_requested", "the screen stays open")


func test_r_008_41_throw_disabled_without_selection() -> void:
	var robot: Robot = _new_thrower()
	_inventory.add(&"scrap", 7)
	_setup_with_thrower(robot)
	watch_signals(robot)
	assert_true(_throw_button().disabled, "no selection, no throwing")
	_throw_button().pressed.emit()
	assert_signal_not_emitted(robot, "throw_requested", "nothing is requested")


func test_r_008_41_selection_cleared_when_slot_empties() -> void:
	var robot: Robot = _new_thrower()
	_inventory.add(&"scrap", 7)
	_setup_with_thrower(robot)
	var cells: Array[InventorySlotView] = _cells()
	cells[0].pressed.emit()
	assert_false(_throw_button().disabled, "a selection enables the button")
	_inventory.remove(&"scrap", 3)
	assert_true(cells[0].is_selected(), "a stack that only shrinks stays selected")
	assert_eq(_selector_slider(_selector()).max_value, 4.0, "and the maximum follows it")
	assert_eq(_selector().get_value(), 4, "the value too")
	_inventory.remove(&"scrap", 4)
	for cell: InventorySlotView in cells:
		assert_false(cell.is_selected(), "no cell is selected")
	assert_true(_throw_button().disabled, "the button is disabled")
	assert_false(_selector().visible, "the selector hides")


func test_r_008_42_screen_never_changes_inventory() -> void:
	var robot: Robot = _new_thrower()
	_inventory.add(&"scrap", 7)
	_inventory.add(&"iron", 2)
	_setup_with_thrower(robot)
	var before: Array[String] = _describe(_inventory)
	_cells()[0].pressed.emit()
	_throw_button().pressed.emit()
	_cells()[1].pressed.emit()
	_throw_button().pressed.emit()
	assert_eq(_describe(_inventory), before, "only the owner of the throw changes the inventory")


func test_r_008_42_texts_translated_es_en() -> void:
	var button: Button = _throw_button()
	assert_eq(button.text, String(THROW_KEY), "the button text is a translation key")
	assert_ne(button.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(THROW_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, THROW_KEY])


func test_r_008_38_throw_controls_hidden_without_thrower() -> void:
	_inventory.add(&"scrap", 7)
	_setup()
	assert_false((_screen.get_node("%ThrowControls") as Control).visible, "no thrower, no controls")
	var with_thrower: InventoryScreen = SCREEN_SCENE.instantiate() as InventoryScreen
	add_child_autofree(with_thrower)
	with_thrower.setup(
		{
			InventoryScreen.CONTEXT_INVENTORY: _inventory,
			InventoryScreen.CONTEXT_THROWER: _new_thrower(),
		}
	)
	assert_true((with_thrower.get_node("%ThrowControls") as Control).visible, "with one they show")


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


const USE_KEY := &"INVENTORY_USE"


func _use_button() -> Button:
	return _screen.get_node("%UseButton") as Button


func test_r_012_25_use_button_for_consumable() -> void:
	var robot: Robot = _new_thrower()
	var item: ConsumableData = DataRegistry.get_item(&"portable_battery") as ConsumableData
	assert_not_null(item, "the catalog has the portable battery")
	if item == null:
		return
	robot.inventory.add(&"scrap", 2)
	robot.inventory.add(&"portable_battery", 3)
	robot.battery.consume(item.battery_points * 2.0)
	_screen.setup(
		{InventoryScreen.CONTEXT_INVENTORY: robot.inventory, InventoryScreen.CONTEXT_THROWER: robot}
	)
	assert_true(_use_button().disabled, "no selection, no use")
	var cells: Array[InventorySlotView] = _cells()
	cells[1].pressed.emit()
	assert_false(_use_button().disabled, "a selected portable battery enables the button")
	var before: float = robot.battery.get_current()
	_use_button().pressed.emit()
	var stack: ItemStack = robot.inventory.get_slots()[1]
	assert_eq(stack.quantity, 2, "one unit is gone")
	assert_almost_eq(robot.battery.get_current(), before + item.battery_points, 0.01, "the battery rises")
	assert_false(_use_button().disabled, "the stack remains selected and usable")


func test_r_012_25_use_button_asks_the_robot() -> void:
	var robot: Robot = _new_thrower()
	robot.inventory.add(&"portable_battery", 3)
	robot.battery.consume(1.0)
	_screen.setup(
		{InventoryScreen.CONTEXT_INVENTORY: robot.inventory, InventoryScreen.CONTEXT_THROWER: robot}
	)
	watch_signals(robot)
	_cells()[0].pressed.emit()
	_use_button().pressed.emit()
	assert_signal_not_emitted(robot, "use_refused", "a valid use is no refusal")
	var stack: ItemStack = robot.inventory.get_slots()[0]
	assert_eq(stack.quantity, 2, "the request used the selected slot")


func test_r_012_25_use_button_refusal_reaches_the_robot_signal() -> void:
	var robot: Robot = _new_thrower()
	robot.inventory.add(&"portable_battery", 3)
	_screen.setup(
		{InventoryScreen.CONTEXT_INVENTORY: robot.inventory, InventoryScreen.CONTEXT_THROWER: robot}
	)
	watch_signals(robot)
	_cells()[0].pressed.emit()
	_use_button().pressed.emit()
	assert_signal_emitted_with_parameters(robot, "use_refused", [ConsumableRules.ERR_BATTERY_FULL])
	var stack: ItemStack = robot.inventory.get_slots()[0]
	assert_eq(stack.quantity, 3, "a full battery spends nothing")


func test_r_012_25_use_button_disabled_for_material() -> void:
	var robot: Robot = _new_thrower()
	robot.inventory.add(&"scrap", 7)
	robot.battery.consume(10.0)
	_screen.setup(
		{InventoryScreen.CONTEXT_INVENTORY: robot.inventory, InventoryScreen.CONTEXT_THROWER: robot}
	)
	watch_signals(robot)
	_cells()[0].pressed.emit()
	assert_true(_use_button().disabled, "a material cannot be used")
	_use_button().pressed.emit()
	assert_signal_not_emitted(robot, "use_refused", "pressing it asks for nothing")
	var stack: ItemStack = robot.inventory.get_slots()[0]
	assert_eq(stack.quantity, 7, "nothing changes")


func test_r_012_25_use_button_follows_selection() -> void:
	var robot: Robot = _new_thrower()
	robot.inventory.add(&"scrap", 7)
	robot.inventory.add(&"portable_battery", 2)
	_screen.setup(
		{InventoryScreen.CONTEXT_INVENTORY: robot.inventory, InventoryScreen.CONTEXT_THROWER: robot}
	)
	var cells: Array[InventorySlotView] = _cells()
	cells[1].pressed.emit()
	assert_false(_use_button().disabled, "enabled on the battery")
	cells[0].pressed.emit()
	assert_true(_use_button().disabled, "disabled when the selection moves to a material")


func test_r_012_25_use_key_translated() -> void:
	var button: Button = _use_button()
	assert_not_null(button, "%UseButton exists")
	if button == null:
		return
	assert_eq(button.text, String(USE_KEY), "the button text is a translation key")
	assert_ne(button.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(USE_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, USE_KEY])


# --- Closing by tapping outside the panel (spec 012, R-012-46, plan D16) -------
# Real mouse events are pushed to the viewport; the test runner's own panel is
# hidden meanwhile so it does not catch them.

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
	_setup()
	assert_true(_screen.closes_on_outside_tap, "this screen closes on an outside tap")
	watch_signals(_screen)
	await _push_tap(Vector2(8, 8))
	assert_signal_emit_count(_screen, "back_requested", 1, "a tap outside the panel asks to go back once")


func test_r_012_46_tap_inside_panel_does_not_close() -> void:
	_setup()
	watch_signals(_screen)
	await wait_process_frames(1)
	await _push_tap(_panel().get_global_rect().get_center())
	assert_signal_not_emitted(_screen, "back_requested", "a tap on the panel is not outside")


func test_r_012_46_panel_stops_the_mouse() -> void:
	assert_eq(_panel().mouse_filter, Control.MOUSE_FILTER_STOP, "the panel stops the mouse")
	assert_eq((_screen.get_node("Center") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "centring lets it through")
	assert_eq((_screen.get_node("Backdrop") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "the backdrop too")
