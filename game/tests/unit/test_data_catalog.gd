extends GutTest
## Items and catalog (spec 004): the three materials match BALANCE §2
## (R-004-18), DataCatalog and DataRegistry return items by id and report
## unknown ids (R-004-19), and the catalog has no repeated ids and lists every
## item file (R-004-20). Loot tables match BALANCE §2.1 and only use catalog
## items (R-004-22), and none has a broken entry (R-004-26). Every loot entry
## fits in one slot (R-005-17) and every item has an icon (R-005-31).
## Enemies are listed and returned by id the same way (spec 006, R-006-04).
## The expected values mirror BALANCE.md §2 and §2.1; update both together.

const ITEMS_DIR := "res://resources/items"
const ENEMIES_DIR := "res://resources/enemies"
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
const EXPECTED_ENEMY_IDS: Array[StringName] = [&"zombie_slow", &"zombie_fast"]


func _new_item(id: StringName) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = id
	return item


func _new_catalog(ids: Array[StringName]) -> DataCatalog:
	var catalog: DataCatalog = DataCatalog.new()
	for id: StringName in ids:
		catalog.items.append(_new_item(id))
	return catalog


func _new_enemy(id: StringName) -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	return enemy


func _new_enemy_catalog(ids: Array[StringName]) -> DataCatalog:
	var catalog: DataCatalog = DataCatalog.new()
	for id: StringName in ids:
		catalog.enemies.append(_new_enemy(id))
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


func test_r_005_17_loot_fits_one_slot_per_entry() -> void:
	# A box gives its contents one slot per rolled stack, so no entry may roll
	# more than one slot holds.
	for table: LootTableData in _load_loot_tables():
		for entry: LootEntryData in table.entries:
			if entry == null or entry.item == null:
				continue
			assert_lte(
				entry.max_quantity,
				entry.item.stack_max,
				"%s: '%s' fits in one slot" % [table.resource_path, entry.item.id]
			)


func test_r_005_31_every_item_has_icon() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	assert_gt(catalog.items.size(), 0, "the catalog has items")
	for item: ItemData in catalog.items:
		if item == null:
			continue
		assert_not_null(item.icon, "'%s' has an icon" % item.id)


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


func test_r_006_04_get_enemy_by_id() -> void:
	var catalog: DataCatalog = _new_enemy_catalog([&"alpha", &"beta"])
	assert_eq(catalog.build_index().size(), 0, "a valid catalog has no problems")
	assert_true(catalog.has_enemy(&"beta"), "beta is in the catalog")
	assert_false(catalog.has_enemy(&"gamma"), "gamma is not in the catalog")
	assert_same(catalog.get_enemy(&"beta"), catalog.enemies[1], "get_enemy returns the listed one")


func test_r_006_04_unknown_enemy_id_reports_error() -> void:
	var catalog: DataCatalog = _new_enemy_catalog([&"alpha"])
	catalog.build_index()
	assert_null(catalog.get_enemy(&"gamma"), "an unknown id returns null")
	assert_push_error("gamma")


func test_r_006_04_items_and_enemies_do_not_share_ids() -> void:
	# Two indexes: an enemy id is not an item id, and the other way round.
	var catalog: DataCatalog = _new_catalog([&"alpha"])
	catalog.enemies.append(_new_enemy(&"beta"))
	assert_eq(catalog.build_index().size(), 0, "a valid catalog has no problems")
	assert_false(catalog.has_item(&"beta"), "an enemy is not an item")
	assert_false(catalog.has_enemy(&"alpha"), "an item is not an enemy")


func test_r_006_04_registry_returns_enemies() -> void:
	for id: StringName in EXPECTED_ENEMY_IDS:
		var enemy: EnemyData = DataRegistry.get_enemy(id)
		assert_not_null(enemy, "DataRegistry returns '%s'" % id)
		if enemy != null:
			assert_eq(enemy.id, id, "the enemy has the requested id")


func test_r_006_04_registry_unknown_enemy_id_reports_error() -> void:
	assert_null(DataRegistry.get_enemy(&"no_such_enemy"), "an unknown id returns null")
	assert_push_error("no_such_enemy")


func test_r_006_04_repeated_or_empty_enemy_ids_reported() -> void:
	var repeated: DataCatalog = _new_enemy_catalog([&"alpha", &"beta", &"alpha"])
	assert_eq(repeated.build_index().size(), 1, "one problem for the repeated id")
	var empty_id: DataCatalog = _new_enemy_catalog([&"alpha", &""])
	assert_eq(empty_id.build_index().size(), 1, "one problem for the empty id")
	var missing: DataCatalog = _new_enemy_catalog([&"alpha"])
	missing.enemies.append(null)
	assert_eq(missing.build_index().size(), 1, "one problem for the empty slot")


func test_r_006_04_every_enemy_file_in_catalog() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var files: PackedStringArray = DirAccess.get_files_at(ENEMIES_DIR)
	assert_eq(files.size(), EXPECTED_ENEMY_IDS.size(), "one file per enemy of the catalog")
	for file: String in files:
		var enemy: EnemyData = load(ENEMIES_DIR.path_join(file)) as EnemyData
		assert_not_null(enemy, "%s is an EnemyData" % file)
		assert_true(catalog.enemies.has(enemy), "%s is listed in the catalog" % file)


# --- Rulesets (spec 008, R-008-01) ------------------------------------------

const RULESETS_DIR := "res://resources/rulesets"


func _new_ruleset(id: StringName) -> RulesetData:
	var ruleset: RulesetData = RulesetData.new()
	ruleset.id = id
	return ruleset


func _new_ruleset_catalog(ids: Array[StringName]) -> DataCatalog:
	var catalog: DataCatalog = DataCatalog.new()
	for id: StringName in ids:
		catalog.rulesets.append(_new_ruleset(id))
	return catalog


func test_r_008_01_get_ruleset_by_id() -> void:
	var catalog: DataCatalog = _new_ruleset_catalog([&"alpha", &"beta"])
	assert_eq(catalog.build_index().size(), 0, "a valid catalog has no problems")
	assert_true(catalog.has_ruleset(&"beta"), "beta is in the catalog")
	assert_false(catalog.has_ruleset(&"gamma"), "gamma is not in the catalog")
	assert_same(catalog.get_ruleset(&"beta"), catalog.rulesets[1], "get_ruleset returns the listed one")
	assert_false(catalog.has_item(&"beta"), "a ruleset is not an item")
	assert_false(catalog.has_enemy(&"beta"), "a ruleset is not an enemy")


func test_r_008_01_unknown_ruleset_reports_error() -> void:
	var catalog: DataCatalog = _new_ruleset_catalog([&"alpha"])
	catalog.build_index()
	assert_null(catalog.get_ruleset(&"gamma"), "an unknown id returns null")
	assert_push_error("gamma")


func test_r_008_01_every_ruleset_file_in_catalog() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var checked: int = 0
	for file: String in DirAccess.get_files_at(RULESETS_DIR):
		if not file.ends_with(".tres"):
			continue
		checked += 1
		var ruleset: RulesetData = load(RULESETS_DIR.path_join(file)) as RulesetData
		assert_not_null(ruleset, "%s is a RulesetData" % file)
		assert_true(catalog.rulesets.has(ruleset), "%s is listed in the catalog" % file)
	assert_gt(checked, 0, "there is at least one ruleset file")
	var problems: PackedStringArray = catalog.build_index()
	assert_eq(problems.size(), 0, "catalog problems: %s" % problems)


func test_r_008_01_repeated_or_empty_ruleset_ids_reported() -> void:
	var repeated: DataCatalog = _new_ruleset_catalog([&"alpha", &"beta", &"alpha"])
	var repeated_problems: PackedStringArray = repeated.build_index()
	assert_eq(repeated_problems.size(), 1, "one problem for the repeated id")
	if repeated_problems.size() == 1:
		assert_eq(repeated_problems[0], "rulesets[2] repeats the id 'alpha'")
	var empty_id: DataCatalog = _new_ruleset_catalog([&"alpha", &""])
	var empty_problems: PackedStringArray = empty_id.build_index()
	assert_eq(empty_problems.size(), 1, "one problem for the empty id")
	if empty_problems.size() == 1:
		assert_string_contains(empty_problems[0], "rulesets[1] (")
		assert_string_contains(empty_problems[0], ") has no id")
	var missing: DataCatalog = _new_ruleset_catalog([&"alpha"])
	missing.rulesets.append(null)
	var missing_problems: PackedStringArray = missing.build_index()
	assert_eq(missing_problems.size(), 1, "one problem for the empty slot")
	if missing_problems.size() == 1:
		assert_eq(missing_problems[0], "rulesets[1] is empty")
