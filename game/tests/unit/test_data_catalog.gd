extends GutTest
## Items and catalog (spec 004): the three materials match BALANCE §2
## (R-004-18), DataCatalog and DataRegistry return items by id and report
## unknown ids (R-004-19), and the catalog has no repeated ids and lists every
## item file (R-004-20). Loot tables match BALANCE §2.1 and only use catalog
## items (R-004-22), and none has a broken entry (R-004-26). Every loot entry
## fits in one slot (R-005-17) and every item has an icon (R-005-31).
## Enemies are listed and returned by id the same way (spec 006, R-006-04).
## Spec 009: zones indexed by zone_id with one BASE zone (R-009-01), structures
## (R-009-24) and recipes whose references exist (R-009-61).
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


# --- Zones, structures and recipes (spec 009) --------------------------------

const ZONES_DIR := "res://resources/zones"
const STRUCTURES_DIR := "res://resources/structures"
const RECIPES_DIR := "res://resources/recipes"


func _new_zone(zone_id: Vector2i, kind: ZoneData.Kind) -> ZoneData:
	var zone: ZoneData = ZoneData.new()
	zone.zone_id = zone_id
	zone.kind = kind
	return zone


## Every .tres of directory loaded as a Resource of class_name; other files skipped.
func _resources_in(directory: String, script_class: StringName) -> Array[Resource]:
	var found: Array[Resource] = []
	for file: String in DirAccess.get_files_at(directory):
		if not file.ends_with(".tres"):
			continue
		var resource: Resource = load(directory.path_join(file))
		var script: Script = resource.get_script() as Script
		if script != null and script.get_global_name() == script_class:
			found.append(resource)
	return found


func test_r_009_01_zones_indexed_by_zone_id() -> void:
	var catalog: DataCatalog = DataCatalog.new()
	catalog.zones.append(_new_zone(Vector2i(0, 0), ZoneData.Kind.FARM))
	catalog.zones.append(_new_zone(Vector2i(0, -1), ZoneData.Kind.BASE))
	assert_eq(catalog.build_index().size(), 0, "a valid zone list has no problems")
	assert_true(catalog.has_zone(Vector2i(0, 0)), "the farm zone is found by zone_id")
	assert_false(catalog.has_zone(Vector2i(5, 5)), "an unlisted zone_id is not found")
	assert_same(catalog.get_zone(Vector2i(0, -1)), catalog.zones[1], "get_zone returns the listed one")
	assert_same(catalog.get_base_zone(), catalog.zones[1], "get_base_zone returns the BASE zone")
	var repeated: DataCatalog = DataCatalog.new()
	repeated.zones.append(_new_zone(Vector2i(0, -1), ZoneData.Kind.BASE))
	repeated.zones.append(_new_zone(Vector2i(0, -1), ZoneData.Kind.FARM))
	var problems: PackedStringArray = repeated.build_index()
	assert_eq(problems.size(), 1, "one problem for the repeated zone id")
	if problems.size() == 1:
		assert_eq(problems[0], "zones[1] repeats the zone id (0, -1)")


func test_r_009_01_unknown_zone_reports_error() -> void:
	var catalog: DataCatalog = DataCatalog.new()
	catalog.zones.append(_new_zone(Vector2i(0, -1), ZoneData.Kind.BASE))
	catalog.build_index()
	assert_null(catalog.get_zone(Vector2i(9, 9)), "an unknown zone_id returns null")
	assert_push_error("unknown zone id (9, 9)")


func test_r_009_01_exactly_one_base_zone() -> void:
	var none: DataCatalog = DataCatalog.new()
	none.zones.append(_new_zone(Vector2i(0, 0), ZoneData.Kind.FARM))
	var none_problems: PackedStringArray = none.build_index()
	assert_eq(none_problems.size(), 1, "a zone list without BASE is a problem")
	if none_problems.size() == 1:
		assert_eq(none_problems[0], "zones has 0 BASE zones instead of 1")
	assert_null(none.get_base_zone(), "no base zone → null")
	assert_push_error("there is no BASE zone")
	var two: DataCatalog = DataCatalog.new()
	two.zones.append(_new_zone(Vector2i(0, -1), ZoneData.Kind.BASE))
	two.zones.append(_new_zone(Vector2i(1, -1), ZoneData.Kind.BASE))
	assert_eq(two.build_index().size(), 1, "two BASE zones are a problem")
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var base_count: int = 0
	for zone: ZoneData in catalog.zones:
		if zone != null and zone.kind == ZoneData.Kind.BASE:
			base_count += 1
	assert_eq(base_count, 1, "the game catalog has exactly one BASE zone")
	var base: ZoneData = catalog.get_base_zone()
	assert_not_null(base, "the catalog returns its base")
	if base != null:
		assert_eq(base.zone_id, Vector2i(0, -1), "the base is zone (0, -1)")


func test_r_009_01_every_zone_tres_listed() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	# zones/ also holds the navmesh and the MeshLibrary: only ZoneData counts.
	var files: Array[Resource] = _resources_in(ZONES_DIR, &"ZoneData")
	assert_eq(files.size(), 2, "the green zone and the base")
	for zone: Resource in files:
		assert_true(catalog.zones.has(zone), "%s is listed in the catalog" % zone.resource_path)
	var problems: PackedStringArray = catalog.build_index()
	assert_eq(problems.size(), 0, "catalog problems: %s" % problems)


func test_r_009_01_registry_returns_zones() -> void:
	var green: ZoneData = DataRegistry.get_zone(Vector2i(0, 0))
	assert_not_null(green, "DataRegistry returns the green zone")
	var base: ZoneData = DataRegistry.get_base_zone()
	assert_not_null(base, "DataRegistry returns the base")
	if base != null:
		assert_eq(base.kind, ZoneData.Kind.BASE, "the registry's base is a BASE zone")


func test_r_009_24_structures_listed() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var files: Array[Resource] = _resources_in(STRUCTURES_DIR, &"StructureData")
	assert_gt(files.size(), 0, "there is at least one structure file")
	for structure: Resource in files:
		assert_true(catalog.structures.has(structure), "%s is listed" % structure.resource_path)
	assert_true(catalog.has_structure(&"charging_station"), "the charging station is listed")
	assert_same(
		DataRegistry.get_structure(&"charging_station"),
		catalog.get_structure(&"charging_station"),
		"DataRegistry returns the same structure"
	)
	assert_null(catalog.get_structure(&"nope"), "an unknown structure id returns null")
	assert_push_error("unknown structure id 'nope'")


func test_r_009_61_recipes_listed_and_refs_exist() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var files: Array[Resource] = _resources_in(RECIPES_DIR, &"RecipeData")
	assert_gt(files.size(), 0, "there is at least one recipe file")
	for file: Resource in files:
		assert_true(catalog.recipes.has(file), "%s is listed" % file.resource_path)
	assert_eq(catalog.get_recipes().size(), catalog.recipes.size(), "get_recipes lists every recipe")
	for recipe: RecipeData in catalog.get_recipes():
		for ingredient: RecipeIngredientData in recipe.ingredients:
			assert_not_null(ingredient, "%s has no empty ingredient" % recipe.id)
			if ingredient == null or ingredient.item == null:
				fail_test("%s has an ingredient without item" % recipe.id)
				continue
			assert_true(catalog.has_item(ingredient.item.id), "%s: catalog item" % recipe.id)
			assert_gt(ingredient.quantity, 0, "%s: positive quantity" % recipe.id)
		if recipe.result_structure != null:
			assert_true(
				catalog.has_structure(recipe.result_structure.id), "%s: catalog structure" % recipe.id
			)
	assert_true(catalog.has_recipe(&"charging_station"), "the station recipe is listed")
	assert_same(
		DataRegistry.get_recipe(&"charging_station"),
		catalog.get_recipe(&"charging_station"),
		"DataRegistry returns the same recipe"
	)


## Spec 010 (R-010-19): a World created by the game takes the catalog's
## new_world_ruleset, the NORMAL one, and it is one of the listed rulesets.
func test_r_010_19_new_world_ruleset_is_normal() -> void:
	var catalog: DataCatalog = load(CATALOG_PATH) as DataCatalog
	assert_not_null(catalog, "data_catalog.tres is a DataCatalog")
	if catalog == null:
		return
	var ruleset: RulesetData = catalog.new_world_ruleset
	assert_not_null(ruleset, "it names a ruleset")
	if ruleset == null:
		return
	assert_eq(ruleset.resource_path, "res://resources/rulesets/normal.tres", "the NORMAL ruleset")
	assert_true(catalog.rulesets.has(ruleset), "listed in rulesets")


# --- Recipes with an item result and repair costs (spec 011) ------------------
# The expected repair tiers mirror BALANCE.md §4.3.2; update both together.

## up_to_percent → {item id → quantity}, ascending (BALANCE §4.3.2).
const EXPECTED_REPAIR_TIERS: Array[Array] = [
	[25, {&"iron": 3, &"cables": 2}],
	[100, {&"iron": 2, &"cables": 1}],
]


func test_r_011_03_every_recipe_has_one_result() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	assert_gt(catalog.recipes.size(), 0, "the catalog has recipes")
	for recipe: RecipeData in catalog.recipes:
		if recipe == null:
			fail_test("the catalog lists an empty recipe")
			continue
		var results: int = (
			(1 if recipe.result_structure != null else 0) + (1 if recipe.result_item != null else 0)
		)
		assert_eq(results, 1, "%s has exactly one result" % recipe.id)


func test_r_011_05_recipes_workbench_tier_1_no_requires() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	for recipe: RecipeData in catalog.recipes:
		if recipe == null:
			continue
		assert_eq(recipe.station, RecipeData.Station.WORKBENCH, "%s is made at the workbench" % recipe.id)
		assert_eq(recipe.tier, 1, "%s is tier 1" % recipe.id)
		assert_eq(recipe.requires.size(), 0, "%s has no requirements" % recipe.id)


func test_r_011_05_recipe_items_in_catalog() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	for recipe: RecipeData in catalog.recipes:
		if recipe == null:
			continue
		for ingredient: RecipeIngredientData in recipe.ingredients:
			if ingredient == null or ingredient.item == null:
				fail_test("%s has an empty ingredient" % recipe.id)
				continue
			assert_true(catalog.items.has(ingredient.item), "%s: '%s' is listed" % [recipe.id, ingredient.item.id])
		if recipe.result_item != null:
			assert_true(
				catalog.items.has(recipe.result_item),
				"%s: result '%s' is listed" % [recipe.id, recipe.result_item.id]
			)
	for id: StringName in [&"basic_arms", &"basic_legs", &"basic_core"]:
		assert_true(catalog.has_recipe(id), "the recipe of %s is listed" % id)


func test_r_011_06_repair_costs_match_balance() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null:
		fail_test("data_catalog.tres is missing")
		return
	var costs: RepairCostData = catalog.repair_costs
	assert_not_null(costs, "the catalog names the repair costs")
	if costs == null:
		return
	assert_eq(costs.tiers.size(), EXPECTED_REPAIR_TIERS.size(), "one tier per row of BALANCE §4.3.2")
	for i: int in mini(costs.tiers.size(), EXPECTED_REPAIR_TIERS.size()):
		var tier: RepairTierData = costs.tiers[i]
		assert_not_null(tier, "tier %d is set" % i)
		if tier == null:
			continue
		var expected_percent: int = EXPECTED_REPAIR_TIERS[i][0]
		var expected_cost: Dictionary = EXPECTED_REPAIR_TIERS[i][1]
		assert_eq(tier.up_to_percent, expected_percent, "tier %d covers up to %d%%" % [i, expected_percent])
		var cost: Dictionary[StringName, int] = {}
		for ingredient: RecipeIngredientData in tier.ingredients:
			if ingredient == null or ingredient.item == null:
				fail_test("tier %d has an empty ingredient" % i)
				continue
			assert_true(catalog.items.has(ingredient.item), "tier %d: '%s' is listed" % [i, ingredient.item.id])
			cost[ingredient.item.id] = cost.get(ingredient.item.id, 0) + ingredient.quantity
		assert_eq(cost.size(), expected_cost.size(), "tier %d: one entry per material" % i)
		for item_id: StringName in expected_cost:
			var quantity: int = expected_cost[item_id]
			var listed: int = cost.get(item_id, 0)
			assert_eq(listed, quantity, "tier %d: %s (BALANCE §4.3.2)" % [i, item_id])


func test_r_011_06_repair_tiers_ascending_up_to_100() -> void:
	var catalog: DataCatalog = _load_catalog()
	if catalog == null or catalog.repair_costs == null:
		fail_test("the catalog has no repair costs")
		return
	var tiers: Array[RepairTierData] = catalog.repair_costs.tiers
	assert_gt(tiers.size(), 0, "there is at least one tier")
	var previous: int = 0
	for tier: RepairTierData in tiers:
		if tier == null:
			fail_test("a repair tier is empty")
			continue
		assert_gt(tier.up_to_percent, previous, "tiers ascend")
		previous = tier.up_to_percent
	assert_eq(previous, CraftingSystem.PERCENT, "the last tier covers up to 100%")
