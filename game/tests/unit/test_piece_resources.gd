extends GutTest
## Piece data (spec 011): PieceData extends ItemData with the maximum
## durability of BALANCE §4.1 and a stack_max of 1 (R-011-01), and the three
## basic pieces of PMV §2.2 are catalog items with an icon and a name in ES and
## EN (R-011-02). The expected values mirror BALANCE.md §4.1; update both together.

const PIECES_DIR := "res://resources/pieces"
const CATALOG_PATH := "res://resources/data_catalog.tres"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
## id → name_key (PMV §2.2).
const EXPECTED_PIECES: Dictionary[StringName, StringName] = {
	&"basic_arms": &"ITEM_BASIC_ARMS",
	&"basic_legs": &"ITEM_BASIC_LEGS",
	&"basic_core": &"ITEM_BASIC_CORE",
}
## BALANCE §4.1: maximum durability of a new piece, every piece.
const EXPECTED_DURABILITY_MAX := 100
const BASE_STATS_PATH := "res://resources/robot/robot_base_stats.tres"
## id → slot (R-015-01).
const EXPECTED_SLOTS: Dictionary[StringName, PieceData.SlotType] = {
	&"basic_arms": PieceData.SlotType.ARMS,
	&"basic_legs": PieceData.SlotType.LEGS,
	&"basic_core": PieceData.SlotType.CORE,
}
## id → stat → value set by the piece (BALANCE §4.2).
const EXPECTED_SETS: Dictionary[StringName, Dictionary] = {
	&"basic_arms": {&"attack_damage": 10.0, &"attacks_per_second": 1.0, &"battery_per_swing": 1.0},
	&"basic_legs": {&"walk_speed": 3.0, &"run_speed": 4.8, &"walk_drain": 0.05},
	&"basic_core": {&"max_battery": 100.0, &"passive_drain": 0.1},
}


func _load_piece(id: StringName) -> PieceData:
	return load("%s/%s.tres" % [PIECES_DIR, id]) as PieceData


func test_r_011_01_piece_data_extends_item_data() -> void:
	var piece: PieceData = PieceData.new()
	assert_true(piece is ItemData, "a PieceData is an ItemData")
	var names: Array[String] = []
	for property: Dictionary in piece.get_property_list():
		var property_name: String = property["name"]
		names.append(property_name)
	assert_true(names.has("durability_max"), "PieceData has durability_max")


func test_r_011_01_every_piece_stacks_one_with_balance_durability() -> void:
	for id: StringName in EXPECTED_PIECES:
		var piece: PieceData = _load_piece(id)
		assert_not_null(piece, "%s.tres exists and is a PieceData" % id)
		if piece == null:
			continue
		assert_eq(piece.stack_max, 1, "%s stacks one per slot" % id)
		assert_eq(piece.durability_max, EXPECTED_DURABILITY_MAX, "%s durability (BALANCE §4.1)" % id)
	# Any piece a later spec adds is unique too.
	var catalog: DataCatalog = load(CATALOG_PATH) as DataCatalog
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	for item: ItemData in catalog.items:
		if item is PieceData:
			assert_eq(item.stack_max, 1, "catalog piece '%s' stacks one per slot" % item.id)


func test_r_011_02_basic_pieces_listed_with_icon() -> void:
	var catalog: DataCatalog = load(CATALOG_PATH) as DataCatalog
	assert_not_null(catalog, "data_catalog.tres is a DataCatalog")
	if catalog == null:
		return
	for id: StringName in EXPECTED_PIECES:
		assert_true(catalog.has_item(id), "'%s' is a catalog item" % id)
		if not catalog.has_item(id):
			continue
		var piece: PieceData = catalog.get_item(id) as PieceData
		assert_not_null(piece, "'%s' is a PieceData" % id)
		if piece == null:
			continue
		assert_eq(piece.name_key, EXPECTED_PIECES[id], "name key of %s" % id)
		assert_not_null(piece.icon, "'%s' has an icon" % id)


func test_r_011_02_piece_names_translated_es_en() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for id: StringName in EXPECTED_PIECES:
			var name_key: StringName = EXPECTED_PIECES[id]
			var text: String = translations[0].get_message(name_key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, name_key])


func test_r_011_02_every_piece_file_in_catalog() -> void:
	var catalog: DataCatalog = load(CATALOG_PATH) as DataCatalog
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var checked: int = 0
	for file: String in DirAccess.get_files_at(PIECES_DIR):
		if not file.ends_with(".tres"):
			continue
		checked += 1
		var piece: PieceData = load(PIECES_DIR.path_join(file)) as PieceData
		assert_not_null(piece, "%s is a PieceData" % file)
		assert_true(catalog.items.has(piece), "%s is listed in the catalog" % file)
	assert_eq(checked, EXPECTED_PIECES.size(), "one file per basic piece of PMV §2.2")


func test_r_015_01_basic_pieces_slot_and_modifiers() -> void:
	for id: StringName in EXPECTED_SLOTS:
		var piece: PieceData = _load_piece(id)
		if piece == null:
			fail_test("%s.tres is missing" % id)
			continue
		assert_eq(piece.slot_type, EXPECTED_SLOTS[id], "slot of %s" % id)
		var expected: Dictionary = EXPECTED_SETS[id]
		assert_eq(piece.modifiers.size(), expected.size(), "%s: one modifier per value of its row" % id)
		for modifier: StatModifier in piece.modifiers:
			assert_not_null(modifier, "%s has no empty modifier" % id)
			if modifier == null:
				continue
			assert_eq(modifier.op, StatModifier.Op.SET, "%s sets %s (plan D3)" % [id, modifier.stat])
			assert_true(expected.has(modifier.stat), "%s sets an expected stat: %s" % [id, modifier.stat])
			var value: float = expected.get(modifier.stat, -1.0)
			assert_almost_eq(modifier.value, value, 0.0001, "%s %s (BALANCE §4.2)" % [id, modifier.stat])


func test_r_015_01_every_piece_modifier_names_a_base_stat() -> void:
	var base: RobotBaseStatsData = load(BASE_STATS_PATH) as RobotBaseStatsData
	var catalog: DataCatalog = load(CATALOG_PATH) as DataCatalog
	if base == null or catalog == null:
		fail_test("robot_base_stats.tres or data_catalog.tres is missing")
		return
	var stats: Dictionary[StringName, float] = base.to_stats()
	for item: ItemData in catalog.items:
		var piece: PieceData = item as PieceData
		if piece == null:
			continue
		for modifier: StatModifier in piece.modifiers:
			assert_not_null(modifier, "'%s' has no empty modifier" % piece.id)
			if modifier != null:
				assert_true(stats.has(modifier.stat), "'%s' modifies a base stat: %s" % [piece.id, modifier.stat])


func test_r_015_41_starting_pieces_match_balance() -> void:
	var robot: Robot = (load("res://scenes/entities/robot.tscn") as PackedScene).instantiate() as Robot
	var equipment: EquipmentComponent = robot.get_node("%Equipment") as EquipmentComponent
	var ids: Array[String] = []
	for piece: PieceData in equipment.starting_pieces:
		ids.append(String(piece.id))
	ids.sort()
	var expected: Array[String] = ["basic_core", "basic_legs"]
	assert_eq(ids, expected, "basic Core and basic legs, one arm (BALANCE §4.2 Equipo inicial)")
	robot.free()
