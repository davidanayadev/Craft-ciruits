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
