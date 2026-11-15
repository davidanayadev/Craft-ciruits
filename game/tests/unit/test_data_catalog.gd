extends GutTest
## Items and catalog (spec 004): the three materials match BALANCE §2
## (R-004-18), DataCatalog and DataRegistry return items by id and report
## unknown ids (R-004-19), and the catalog has no repeated ids and lists every
## item file (R-004-20). Loot tables match BALANCE §2.1 and only use catalog
## items (R-004-22), and none has a broken entry (R-004-26).
## The expected values mirror BALANCE.md §2 and §2.1; update both together.

const ITEMS_DIR := "res://resources/items"
const CATALOG_PATH := "res://resources/data_catalog.tres"
const LOOT_DIR := "res://resources/loot"
const BASIC_BOX_PATH := "res://resources/loot/basic_box.tres"
## item id → quantity range as (min, max): "Caja básica (zona verde)", BALANCE §2.1.
const EXPECTED_BASIC_BOX: Dictionary[StringName, Vector2i] = {
	&"scrap": Vector2i(2, 5),
	&"cables": Vector2i(0, 2),
	&"iron": Vector2i(0, 1),
}
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const SNAKE_CASE_PATTERN := "^[a-z][a-z0-9]*(_[a-z0-9]+)*$"
## id → [name_key, stack_max] (BALANCE §2).
const EXPECTED_ITEMS: Dictionary[StringName, Array] = {
	&"scrap": [&"ITEM_SCRAP", 99],
	&"cables": [&"ITEM_CABLES", 50],
	&"iron": [&"ITEM_IRON", 50],
}


func _new_item(id: StringName) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = id
	return item


func _new_catalog(ids: Array[StringName]) -> DataCatalog:
	var catalog: DataCatalog = DataCatalog.new()
	for id: StringName in ids:
		catalog.items.append(_new_item(id))
	return catalog


func _load_catalog() -> DataCatalog:
	return load(CATALOG_PATH) as DataCatalog


func test_r_004_18_items_match_balance() -> void:
	var snake_case: RegEx = RegEx.create_from_string(SNAKE_CASE_PATTERN)
	for id: StringName in EXPECTED_ITEMS:
		var item: ItemData = load("%s/%s.tres" % [ITEMS_DIR, id]) as ItemData
		assert_not_null(item, "%s.tres exists and is an ItemData" % id)
		if item == null:
			continue
		var name_key: StringName = EXPECTED_ITEMS[id][0]
		var stack_max: int = EXPECTED_ITEMS[id][1]
		assert_eq(item.id, id, "id of %s.tres" % id)
		assert_not_null(snake_case.search(String(item.id)), "'%s' is snake_case" % item.id)
		assert_eq(item.name_key, name_key, "name key of %s" % id)
		assert_eq(item.stack_max, stack_max, "stack maximum of %s (BALANCE §2)" % id)


func test_r_004_18_item_names_translated_es_en() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for id: StringName in EXPECTED_ITEMS:
			var name_key: StringName = EXPECTED_ITEMS[id][0]
			var text: String = translations[0].get_message(name_key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, name_key])


func test_r_004_19_get_item_by_id() -> void:
	var catalog: DataCatalog = _new_catalog([&"alpha", &"beta"])
	assert_eq(catalog.build_index().size(), 0, "a valid catalog has no problems")
	assert_true(catalog.has_item(&"beta"), "beta is in the catalog")
	assert_false(catalog.has_item(&"gamma"), "gamma is not in the catalog")
	assert_same(catalog.get_item(&"beta"), catalog.items[1], "get_item returns the listed resource")


func test_r_004_19_unknown_id_reports_error() -> void:
	var catalog: DataCatalog = _new_catalog([&"alpha"])
	catalog.build_index()
	assert_null(catalog.get_item(&"gamma"), "an unknown id returns null")
	assert_push_error("gamma")


func test_r_004_19_registry_loads_catalog() -> void:
	var catalog: DataCatalog = DataRegistry.get_catalog()
	assert_not_null(catalog, "DataRegistry loaded the catalog at start-up")
	if catalog == null:
		return
	assert_eq(catalog.resource_path, CATALOG_PATH, "it is data_catalog.tres")
	for id: StringName in EXPECTED_ITEMS:
		var item: ItemData = DataRegistry.get_item(id)
		assert_not_null(item, "DataRegistry returns '%s'" % id)
		if item != null:
			assert_eq(item.id, id, "the item has the requested id")


func test_r_004_19_registry_unknown_id_reports_error() -> void:
	assert_null(DataRegistry.get_item(&"no_such_item"), "an unknown id returns null")
	assert_push_error("no_such_item")


func test_r_004_20_repeated_or_empty_ids_are_reported() -> void:
	var repeated: DataCatalog = _new_catalog([&"alpha", &"beta", &"alpha"])
	assert_eq(repeated.build_index().size(), 1, "one problem for the repeated id")
	var empty_id: DataCatalog = _new_catalog([&"alpha", &""])
	assert_eq(empty_id.build_index().size(), 1, "one problem for the empty id")
	var missing: DataCatalog = _new_catalog([&"alpha"])
	missing.items.append(null)
	assert_eq(missing.build_index().size(), 1, "one problem for the empty slot")


func test_r_004_20_no_repeated_ids() -> void:
	var catalog: DataCatalog = _load_catalog()
	assert_not_null(catalog, "data_catalog.tres exists and is a DataCatalog")
	if catalog == null:
		return
	var problems: PackedStringArray = catalog.build_index()
	assert_eq(problems.size(), 0, "catalog problems: %s" % problems)


func test_r_004_20_every_item_file_in_catalog() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var files: PackedStringArray = DirAccess.get_files_at(ITEMS_DIR)
	assert_eq(files.size(), EXPECTED_ITEMS.size(), "one file per material of BALANCE §2")
	for file: String in files:
		var item: ItemData = load(ITEMS_DIR.path_join(file)) as ItemData
		assert_not_null(item, "%s is an ItemData" % file)
		assert_true(catalog.items.has(item), "%s is listed in the catalog" % file)


func test_r_004_22_basic_box_matches_balance() -> void:
	var table: LootTableData = load(BASIC_BOX_PATH) as LootTableData
	assert_not_null(table, "basic_box.tres exists and is a LootTableData")
	if table == null:
		return
	assert_eq(table.entries.size(), EXPECTED_BASIC_BOX.size(), "one entry per material")
	for entry: LootEntryData in table.entries:
		if entry == null or entry.item == null:
			fail_test("basic_box.tres has an entry without item")
			continue
		assert_true(EXPECTED_BASIC_BOX.has(entry.item.id), "'%s' is in BALANCE §2.1" % entry.item.id)
		if not EXPECTED_BASIC_BOX.has(entry.item.id):
			continue
		var expected: Vector2i = EXPECTED_BASIC_BOX[entry.item.id]
		assert_eq(entry.min_quantity, expected.x, "minimum of %s" % entry.item.id)
		assert_eq(entry.max_quantity, expected.y, "maximum of %s" % entry.item.id)


func test_r_004_22_loot_items_in_catalog() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	for table: LootTableData in _load_loot_tables():
		for entry: LootEntryData in table.entries:
			if entry == null or entry.item == null:
				continue
			assert_true(
				catalog.items.has(entry.item),
				"%s: '%s' is a catalog item" % [table.resource_path, entry.item.id]
			)


func test_r_004_26_all_loot_tables_valid() -> void:
	var tables: Array[LootTableData] = _load_loot_tables()
	assert_gt(tables.size(), 0, "there is at least one loot table")
	for table: LootTableData in tables:
		var problems: PackedStringArray = LootSystem.validate(table)
		assert_eq(problems.size(), 0, "%s: %s" % [table.resource_path, problems])


func _load_loot_tables() -> Array[LootTableData]:
	var tables: Array[LootTableData] = []
	for file: String in DirAccess.get_files_at(LOOT_DIR):
		var table: LootTableData = load(LOOT_DIR.path_join(file)) as LootTableData
		assert_not_null(table, "%s is a LootTableData" % file)
		if table != null:
			tables.append(table)
	return tables
