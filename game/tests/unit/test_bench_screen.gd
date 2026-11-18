extends GutTest
## BenchScreen (spec 011): the repair bench screen with three tabs, Build,
## Craft and Repair, that opens on Build (R-011-21). Build keeps the behaviour
## of the spec 009 build screen (R-009-38, R-009-39, R-009-64, R-009-65; its
## tests moved here with their names). Craft lists the workbench item recipes
## (R-011-22) with a disabled button and a notice when the player cannot craft
## (R-011-23) and creates at once (R-011-15). Repair lists the damaged pieces or
## says there is nothing to repair (R-011-24). The screen follows the inventory
## (R-011-25), stays open after crafting or repairing (R-011-26) and shows only
## translated keys (R-011-27).
## Headless cannot click Controls (ADR 0002): buttons are pressed by signal.

const SCREEN_SCENE := preload("res://scenes/ui/bench_screen.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const BENCH_SCENE := preload("res://scenes/base/repair_bench.tscn")
const BASE_GRID_PATH := "res://resources/config/base_grid.tres"
const RECIPE_ID := &"charging_station"
const PIECE_RECIPE_IDS: Array[StringName] = [&"basic_arms", &"basic_legs", &"basic_core"]
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const TAB_TITLE_KEYS: Array[StringName] = [&"BUILD_TITLE", &"CRAFT_TITLE", &"REPAIR_TITLE"]
const KEYS: Array[StringName] = [
	&"BENCH_TITLE",
	&"BUILD_TITLE",
	&"CRAFT_TITLE",
	&"REPAIR_TITLE",
	&"BUILD_BUTTON",
	&"CRAFT_BUTTON",
	&"REPAIR_BUTTON",
	&"BUILD_COST_ENTRY",
	&"BENCH_DURABILITY",
	&"STRUCTURE_CHARGING_STATION",
	&"ITEM_BASIC_ARMS",
	&"ITEM_BASIC_LEGS",
	&"ITEM_BASIC_CORE",
	&"ERR_NOT_ENOUGH_MATERIALS",
	&"ERR_NO_ROOM_FOR_RESULT",
	&"ERR_PIECE_INTACT",
	&"ERR_PIECE_BROKEN",
	&"ERR_PIECE_NOT_FOUND",
	&"MSG_BASE_FULL",
	&"MSG_NOTHING_TO_REPAIR",
]

var _screen: BenchScreen
var _robot: Robot
var _structures: BaseStructures
var _bench: RepairBench


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_structures = _new_structures(load(BASE_GRID_PATH) as BuildGridData)
	_bench = BENCH_SCENE.instantiate() as RepairBench
	add_child_autofree(_bench)
	_screen = SCREEN_SCENE.instantiate() as BenchScreen
	add_child_autofree(_screen)


func _new_structures(grid: BuildGridData) -> BaseStructures:
	var structures: BaseStructures = BaseStructures.new()
	structures.grid_config = grid
	add_child_autofree(structures)
	return structures


func _setup() -> void:
	_screen.setup({
		BenchScreen.CONTEXT_PLAYER: _robot,
		BenchScreen.CONTEXT_BASE: _structures,
		BenchScreen.CONTEXT_BENCH: _bench,
	})


func _recipe() -> RecipeData:
	return DataRegistry.get_recipe(RECIPE_ID)


func _section(section_name: String) -> Node:
	return _screen.get_node("%" + section_name)


func _entries_of(section_name: String) -> Array[BenchEntry]:
	var entries: Array[BenchEntry] = []
	for child: Node in _section(section_name).get_children():
		var entry: BenchEntry = child as BenchEntry
		if entry != null and not entry.is_queued_for_deletion():
			entries.append(entry)
	return entries


func _entry() -> Node:
	return _section("BuildSection").get_node_or_null(String(RECIPE_ID))


func _craft_entry(recipe_id: StringName) -> Node:
	return _section("CraftSection").get_node_or_null(String(recipe_id))


func _repair_entry(piece_uid: String) -> Node:
	return _section("RepairSection").get_node_or_null(piece_uid)


func _button(entry: Node = _entry()) -> Button:
	return entry.get_node("ActionButton") as Button


func _notice(entry: Node = _entry()) -> Label:
	return entry.get_node("Notice") as Label


func _label(entry: Node, label_name: String) -> Label:
	return entry.get_node(label_name) as Label


func _nothing_to_repair() -> Label:
	return _screen.get_node("%NothingToRepair") as Label


func _give_cost(recipe: RecipeData = _recipe()) -> void:
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	for item_id: StringName in cost:
		_robot.inventory.add(item_id, cost[item_id])


## A crafted piece at durability, put in the robot's inventory.
func _give_piece(piece_id: StringName, durability: int) -> ItemStack:
	var piece: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(piece_id))
	piece.durability = durability
	var offered: Array[ItemStack] = [piece]
	assert_true(_robot.inventory.add_stacks(offered).ok, "test setup: the piece fits")
	return piece


## "Scrap x4, Cables x2" in the current language.
func _cost_text(cost: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in cost:
		var item_name: String = TranslationServer.translate(DataRegistry.get_item(item_id).name_key)
		parts.append(TranslationServer.translate(&"BUILD_COST_ENTRY") % [item_name, cost[item_id]])
	return ", ".join(parts)


func _has_text(locale: String, key: StringName) -> bool:
	for translation: Translation in TranslationServer.find_translations(locale, true):
		if not translation.get_message(key).is_empty():
			return true
	return false


# --- Tabs (R-011-21) ----------------------------------------------------------

func test_r_011_21_three_tabs_open_on_build() -> void:
	_setup()
	var tabs: TabContainer = _screen.get_node("%Tabs") as TabContainer
	assert_eq(tabs.get_tab_count(), 3, "three tabs")
	assert_eq(_screen.get_current_tab(), BenchScreen.Tab.BUILD, "it opens on Build")
	assert_eq(tabs.current_tab, BenchScreen.Tab.BUILD, "the Build tab is shown")
	for i: int in TAB_TITLE_KEYS.size():
		assert_eq(tabs.get_tab_title(i), tr(TAB_TITLE_KEYS[i]), "tab %d is titled by its key" % i)
	assert_same(tabs.get_child(BenchScreen.Tab.BUILD), _section("BuildSection"), "Build tab")
	assert_same(tabs.get_child(BenchScreen.Tab.CRAFT), _section("CraftSection"), "Craft tab")
	assert_same(tabs.get_child(BenchScreen.Tab.REPAIR), _section("RepairSection"), "Repair tab")
	_screen.show_tab(BenchScreen.Tab.REPAIR)
	assert_eq(_screen.get_current_tab(), BenchScreen.Tab.REPAIR, "show_tab switches tabs")


func test_r_011_21_missing_context_reports_error() -> void:
	_screen.setup({BenchScreen.CONTEXT_PLAYER: _robot})
	assert_push_error("BenchScreen")
	assert_eq(_entries_of("BuildSection").size(), 0, "no build entries")
	assert_eq(_entries_of("CraftSection").size(), 0, "no craft entries")
	assert_eq(_entries_of("RepairSection").size(), 0, "no repair entries")


# --- Build (spec 009 tests, moved from test_build_screen.gd) -----------------

func test_r_009_64_lists_recipes_with_name_and_cost() -> void:
	_setup()
	assert_eq(_entries_of("BuildSection").size(), 1, "one structure recipe at the bench")
	assert_not_null(_entry(), "the charging station is listed")
	if _entry() == null:
		return
	assert_eq(_label(_entry(), "Name").text, "STRUCTURE_CHARGING_STATION", "its name, as a key")
	var scrap_name: String = TranslationServer.translate(&"ITEM_SCRAP")
	var expected: String = TranslationServer.translate(&"BUILD_COST_ENTRY") % [scrap_name, 4]
	assert_eq(_label(_entry(), "Cost").text, expected, "its cost (BALANCE §5.3)")


func test_r_009_64_texts_are_keys() -> void:
	_setup()
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, "BENCH_TITLE", "the title is a key")
	assert_eq(_button().text, "BUILD_BUTTON", "the button is a key")
	for locale: String in SUPPORTED_LOCALES:
		for key: StringName in KEYS:
			assert_true(_has_text(locale, key), "%s has a text in %s" % [key, locale])


func test_r_009_39_missing_materials_disables() -> void:
	_setup()
	assert_true(_button().disabled, "nothing to pay with: disabled")
	assert_true(_notice().visible, "with a notice")
	assert_eq(_notice().text, String(CraftingSystem.ERR_NOT_ENOUGH_MATERIALS), "the missing-materials key")
	watch_signals(_robot)
	_button().pressed.emit()
	assert_signal_not_emitted(_robot, "build_requested", "a disabled entry asks for nothing")


func test_r_009_38_full_base_disables_with_notice() -> void:
	var full: BuildGridData = BuildGridData.new()
	full.cell_size_m = 1.0
	full.area_size_cells = Vector2i(1, 1)
	full.reserved_cells = [Vector2i(0, 0)] as Array[Vector2i]
	_structures = _new_structures(full)
	_give_cost()
	_setup()
	assert_true(_button().disabled, "no room: disabled")
	assert_eq(_notice().text, String(BenchBuildSection.MSG_BASE_FULL), "the base-full notice")
	assert_eq(_robot.inventory.count(&"scrap"), 4, "nothing was spent")


func test_r_009_65_pick_requests_placement_without_cost() -> void:
	_give_cost()
	_setup()
	assert_false(_button().disabled, "enough scrap and room: enabled")
	assert_false(_notice().visible, "no notice")
	watch_signals(_robot)
	watch_signals(_screen)
	_button().pressed.emit()
	assert_signal_emit_count(_screen, "close_requested", 1, "the screen closes")
	assert_signal_emit_count(_robot, "build_requested", 1, "and asks to build")
	assert_signal_emitted_with_parameters(_robot, "build_requested", [_robot, _recipe()])
	assert_eq(_robot.inventory.count(&"scrap"), 4, "nothing is charged yet")


# --- Craft (R-011-15, R-011-22, R-011-23) -------------------------------------

func test_r_011_22_craft_lists_item_recipes() -> void:
	_setup()
	assert_eq(_entries_of("CraftSection").size(), PIECE_RECIPE_IDS.size(), "one row per item recipe")
	assert_null(_section("CraftSection").get_node_or_null(String(RECIPE_ID)), "no structure in Craft")
	for recipe_id: StringName in PIECE_RECIPE_IDS:
		var entry: Node = _craft_entry(recipe_id)
		assert_not_null(entry, "%s is listed" % recipe_id)
		if entry == null:
			continue
		var recipe: RecipeData = DataRegistry.get_recipe(recipe_id)
		var icon: TextureRect = entry.get_node("Icon") as TextureRect
		assert_same(icon.texture, recipe.result_item.icon, "%s shows its icon" % recipe_id)
		assert_true(icon.visible, "%s icon visible" % recipe_id)
		assert_eq(_label(entry, "Name").text, String(recipe.result_item.name_key), "%s name key" % recipe_id)
		var expected_cost: String = _cost_text(CraftingSystem.cost_of(recipe))
		assert_eq(_label(entry, "Cost").text, expected_cost, "%s cost (BALANCE §4.3.1)" % recipe_id)
		assert_eq(_button(entry).text, "CRAFT_BUTTON", "%s has a Create button" % recipe_id)
	for entry: BenchEntry in _entries_of("BuildSection"):
		assert_false(PIECE_RECIPE_IDS.has(StringName(entry.name)), "no item recipe in Build")


func test_r_011_23_missing_materials_disables() -> void:
	_setup()
	var entry: Node = _craft_entry(&"basic_arms")
	assert_true(_button(entry).disabled, "nothing to pay with: disabled")
	assert_true(_notice(entry).visible, "with a notice")
	assert_eq(_notice(entry).text, String(CraftingSystem.ERR_NOT_ENOUGH_MATERIALS), "the reason")
	_button(entry).pressed.emit()
	assert_eq(_robot.inventory.count(&"basic_arms"), 0, "a disabled entry creates nothing")


func test_r_011_23_no_room_disables() -> void:
	# 5 slots: scrap, cables and three of iron. Paying the arms empties none of them.
	_robot.inventory.add(&"scrap", 5)
	_robot.inventory.add(&"cables", 3)
	var iron_max: int = DataRegistry.get_item(&"iron").stack_max
	_robot.inventory.add(&"iron", iron_max * (_robot.inventory.get_slot_count() - 2))
	_setup()
	var entry: Node = _craft_entry(&"basic_arms")
	assert_true(_button(entry).disabled, "no slot for the piece: disabled")
	assert_eq(_notice(entry).text, String(CraftingSystem.ERR_NO_ROOM_FOR_RESULT), "the no-room reason")


func test_r_011_15_create_acts_at_once() -> void:
	_give_cost(DataRegistry.get_recipe(&"basic_arms"))
	_setup()
	_screen.show_tab(BenchScreen.Tab.CRAFT)
	var entry: Node = _craft_entry(&"basic_arms")
	assert_false(_button(entry).disabled, "enough materials: enabled")
	assert_false(_notice(entry).visible, "no notice")
	watch_signals(_screen)
	_button(entry).pressed.emit()
	assert_eq(_robot.inventory.count(&"basic_arms"), 1, "the piece is there right after the press")
	assert_eq(_robot.inventory.count(&"scrap"), 0, "scrap paid")
	assert_eq(_robot.inventory.count(&"cables"), 0, "cables paid")
	assert_signal_not_emitted(_screen, "close_requested", "no other step or screen")


# --- Repair (R-011-24) -------------------------------------------------------

func test_r_011_24_lists_damaged_pieces() -> void:
	var damaged: ItemStack = _give_piece(&"basic_arms", 50)
	var intact: ItemStack = _give_piece(&"basic_legs", 100)
	_robot.inventory.add(&"iron", 2)
	_robot.inventory.add(&"cables", 1)
	_setup()
	assert_eq(_entries_of("RepairSection").size(), 1, "only the damaged piece")
	assert_null(_repair_entry(intact.uid), "the intact piece is not listed")
	var entry: Node = _repair_entry(damaged.uid)
	assert_not_null(entry, "the damaged piece is listed by its uid")
	if entry == null:
		return
	var piece: PieceData = DataRegistry.get_item(&"basic_arms") as PieceData
	assert_same((entry.get_node("Icon") as TextureRect).texture, piece.icon, "its icon")
	assert_eq(_label(entry, "Name").text, "ITEM_BASIC_ARMS", "its name key")
	var durability: String = tr(&"BENCH_DURABILITY") % [50, piece.durability_max]
	assert_eq(_label(entry, "Detail").text, durability, "its durability")
	var costs: RepairCostData = DataRegistry.get_catalog().repair_costs
	var expected_cost: String = _cost_text(CraftingSystem.repair_cost(damaged, costs))
	assert_eq(_label(entry, "Cost").text, expected_cost, "its repair cost (BALANCE §4.3.2)")
	assert_eq(_button(entry).text, "REPAIR_BUTTON", "a Repair button")
	assert_false(_button(entry).disabled, "it can be paid")
	assert_false(_nothing_to_repair().visible, "no 'nothing to repair' notice")


func test_r_011_24_cannot_pay_disables() -> void:
	var damaged: ItemStack = _give_piece(&"basic_arms", 20)
	_robot.inventory.add(&"iron", 2)
	_robot.inventory.add(&"cables", 1)
	_setup()
	var entry: Node = _repair_entry(damaged.uid)
	assert_not_null(entry, "the damaged piece is listed")
	if entry == null:
		return
	assert_true(_button(entry).disabled, "the very damaged tier costs more: disabled")
	assert_true(_notice(entry).visible, "with a notice")
	assert_eq(_notice(entry).text, String(CraftingSystem.ERR_NOT_ENOUGH_MATERIALS), "the reason")
	_button(entry).pressed.emit()
	assert_eq(_robot.inventory.get_slots()[0].durability, 20, "a disabled entry repairs nothing")


func test_r_011_24_nothing_to_repair() -> void:
	_setup()
	assert_eq(_entries_of("RepairSection").size(), 0, "no pieces, no rows")
	assert_true(_nothing_to_repair().visible, "the notice says there is nothing to repair")
	assert_eq(_nothing_to_repair().text, "MSG_NOTHING_TO_REPAIR", "as a key")
	_give_piece(&"basic_core", 100)
	assert_eq(_entries_of("RepairSection").size(), 0, "an intact piece is not listed")
	assert_true(_nothing_to_repair().visible, "still nothing to repair")


# --- Refresh, staying open, texts (R-011-25 to R-011-27) ---------------------

func test_r_011_25_updates_on_inventory_change() -> void:
	_setup()
	var arms: Node = _craft_entry(&"basic_arms")
	assert_true(_button().disabled, "Build starts disabled")
	assert_true(_button(arms).disabled, "Create starts disabled")
	_give_cost(DataRegistry.get_recipe(&"basic_arms"))
	assert_false(_button().disabled, "Build follows the inventory")
	assert_false(_notice().visible, "and hides its notice")
	assert_false(_button(arms).disabled, "Create follows the inventory")
	assert_false(_notice(arms).visible, "and hides its notice")
	var damaged: ItemStack = _give_piece(&"basic_legs", 60)
	assert_not_null(_repair_entry(damaged.uid), "Repair lists the new damaged piece")
	assert_false(_nothing_to_repair().visible, "the notice goes")
	assert_true(_button(_repair_entry(damaged.uid)).disabled, "no iron yet: disabled")
	_robot.inventory.add(&"iron", 2)
	assert_false(_button(_repair_entry(damaged.uid)).disabled, "Repair follows the inventory")
	_screen.on_closed()
	_robot.inventory.remove(&"iron", 2)
	assert_false(_button(_repair_entry(damaged.uid)).disabled, "a closed screen no longer follows it")


func test_r_011_26_stays_open_after_craft_and_repair() -> void:
	_give_cost(DataRegistry.get_recipe(&"basic_core"))
	var damaged: ItemStack = _give_piece(&"basic_arms", 50)
	_robot.inventory.add(&"iron", 2)
	_robot.inventory.add(&"cables", 1)
	_setup()
	watch_signals(_screen)
	_button(_craft_entry(&"basic_core")).pressed.emit()
	assert_eq(_robot.inventory.count(&"basic_core"), 1, "the core was created")
	_button(_repair_entry(damaged.uid)).pressed.emit()
	assert_eq(_robot.inventory.get_slots()[_index_of(damaged.uid)].durability, 100, "the arms were repaired")
	assert_signal_not_emitted(_screen, "close_requested", "the screen stays open")
	assert_null(_repair_entry(damaged.uid), "the repaired piece left the list")
	assert_true(_nothing_to_repair().visible, "nothing left to repair")


func test_r_011_27_texts_are_keys_es_en() -> void:
	_give_piece(&"basic_arms", 50)
	_setup()
	assert_eq((_screen.get_node("%Title") as Label).text, "BENCH_TITLE", "the title is a key")
	var entries: Array[BenchEntry] = _entries_of("CraftSection")
	entries.append_array(_entries_of("RepairSection"))
	for entry: BenchEntry in entries:
		var name_label: Label = _label(entry, "Name")
		assert_true(name_label.text.begins_with("ITEM_"), "%s: the name is a key" % entry.name)
		assert_eq(name_label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_ALWAYS, "and is translated")
		assert_eq(_notice(entry).auto_translate_mode, Node.AUTO_TRANSLATE_MODE_ALWAYS, "notice translated")
		assert_true(_button(entry).text.ends_with("_BUTTON"), "%s: the button is a key" % entry.name)
	for locale: String in SUPPORTED_LOCALES:
		for key: StringName in KEYS:
			assert_true(_has_text(locale, key), "%s has a text in %s" % [key, locale])


func _index_of(piece_uid: String) -> int:
	return InventoryRules.index_of_uid(_robot.inventory.get_slots(), piece_uid)
