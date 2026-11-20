extends GutTest
## Structure data (spec 009, R-009-24): the charging station is the first
## StructureData, with the footprint of BALANCE §5.6, and structures do not
## rotate. The expected values mirror BALANCE.md §5.6; update both together.

const STATION_PATH := "res://resources/structures/charging_station.tres"


func test_r_009_24_charging_station_footprint() -> void:
	var station: StructureData = load(STATION_PATH) as StructureData
	assert_not_null(station, "charging_station.tres exists and is a StructureData")
	if station == null:
		return
	assert_eq(station.id, &"charging_station", "stable id")
	assert_eq(station.name_key, &"STRUCTURE_CHARGING_STATION", "name key")
	assert_eq(station.footprint, Vector2i(1, 1), "footprint 1x1 (BALANCE §5.6)")


func test_r_009_24_no_rotation_field() -> void:
	# No rotation in the MVP (BALANCE §5.6): neither the data nor the saved state has one.
	var names: Array[String] = []
	for property: Dictionary in StructureData.new().get_property_list():
		var property_name: String = property["name"]
		names.append(property_name)
	for forbidden: String in ["rotation", "orientation", "facing"]:
		assert_false(names.has(forbidden), "StructureData has no '%s'" % forbidden)


# --- Wind generator and storage chest (spec 012) ------------------------------
# The expected values mirror BALANCE.md §1.3, §5.2, §5.4 and §5.6; update both together.

const CATALOG_PATH := "res://resources/data_catalog.tres"
const GENERATOR_PATH := "res://resources/structures/wind_generator.tres"
const CHEST_PATH := "res://resources/structures/storage_chest.tres"
const CONTAINER_PATH := "res://resources/config/container.tres"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
## id → [name_key, footprint] (BALANCE §5.6).
const EXPECTED_NEW_STRUCTURES: Dictionary[StringName, Array] = {
	&"wind_generator": [&"STRUCTURE_WIND_GENERATOR", Vector2i(2, 2)],
	&"storage_chest": [&"STRUCTURE_STORAGE_CHEST", Vector2i(1, 1)],
}
## id → most in the base; 0 = no limit (BALANCE §5.2, §5.3, §5.4).
const EXPECTED_LIMITS: Dictionary[StringName, int] = {
	&"storage_chest": 5,
	&"wind_generator": 1,
	&"charging_station": 0,
}


func test_r_012_01_generator_and_chest_listed() -> void:
	var catalog: DataCatalog = load(CATALOG_PATH) as DataCatalog
	assert_not_null(catalog, "data_catalog.tres is a DataCatalog")
	if catalog == null:
		return
	for id: StringName in EXPECTED_NEW_STRUCTURES:
		assert_true(catalog.has_structure(id), "'%s' is a catalog structure" % id)
		if not catalog.has_structure(id):
			continue
		var structure: StructureData = catalog.get_structure(id)
		var name_key: StringName = EXPECTED_NEW_STRUCTURES[id][0]
		var footprint: Vector2i = EXPECTED_NEW_STRUCTURES[id][1]
		assert_eq(structure.name_key, name_key, "name key of %s" % id)
		assert_eq(structure.footprint, footprint, "footprint of %s (BALANCE §5.6)" % id)
		assert_not_null(structure.scene, "%s has a scene" % id)
	assert_true(
		catalog.get_structure(&"wind_generator") is WindGeneratorData, "the generator is a WindGeneratorData"
	)
	assert_true(catalog.get_structure(&"storage_chest") is StorageChestData, "the chest is a StorageChestData")


func test_r_012_01_names_translated_es_en() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for id: StringName in EXPECTED_NEW_STRUCTURES:
			var name_key: StringName = EXPECTED_NEW_STRUCTURES[id][0]
			var text: String = translations[0].get_message(name_key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, name_key])


func test_r_012_03_limits_match_balance() -> void:
	for id: StringName in EXPECTED_LIMITS:
		var structure: StructureData = load("res://resources/structures/%s.tres" % id) as StructureData
		assert_not_null(structure, "%s.tres is a StructureData" % id)
		if structure != null:
			assert_eq(structure.max_count, EXPECTED_LIMITS[id], "most %s in the base (BALANCE §5)" % id)


func test_r_012_04_generator_data_matches_balance() -> void:
	var generator: WindGeneratorData = load(GENERATOR_PATH) as WindGeneratorData
	assert_not_null(generator, "wind_generator.tres is a WindGeneratorData")
	if generator == null:
		return
	assert_eq(generator.max_battery_bonus, 20.0, "+20 maximum battery (BALANCE §5.2)")
	assert_eq(generator.seconds_per_battery, 4 * 3600, "one battery every 4 h (BALANCE §5.2)")
	assert_eq(generator.max_stored, 3, "at most 3 stored (BALANCE §5.2)")
	assert_gte(generator.seconds_per_battery, 1, "a period of at least 1 s (plan D7)")
	assert_gte(generator.max_stored, 1, "holds at least one (plan D7)")
	assert_not_null(generator.battery_item, "it makes an item")
	if generator.battery_item != null:
		assert_eq(generator.battery_item.id, &"portable_battery", "it makes portable batteries")
		assert_true(generator.battery_item is ConsumableData, "a consumable")


func test_r_012_06_chest_capacity_matches_balance() -> void:
	var chest: StorageChestData = load(CHEST_PATH) as StorageChestData
	assert_not_null(chest, "storage_chest.tres is a StorageChestData")
	if chest == null:
		return
	assert_same(chest.container, load(CONTAINER_PATH), "the chest reads container.tres")
	if chest.container != null:
		assert_eq(chest.container.slot_count, 4, "4 slots per chest (BALANCE §1.3, §5.4)")
