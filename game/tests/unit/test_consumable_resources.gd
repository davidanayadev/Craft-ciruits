extends GutTest
## Consumable data (spec 012): the portable battery is a catalog item with the
## stack maximum of BALANCE §2, an icon, a name in ES and EN and the battery
## points of BALANCE §1.1 as data (R-012-05). The expected values mirror
## BALANCE.md §1.1 and §2; update both together.

const CATALOG_PATH := "res://resources/data_catalog.tres"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const BATTERY_ID := &"portable_battery"
const BATTERY_NAME_KEY := &"ITEM_PORTABLE_BATTERY"


func test_r_012_05_portable_battery_listed() -> void:
	var catalog: DataCatalog = load(CATALOG_PATH) as DataCatalog
	assert_not_null(catalog, "data_catalog.tres is a DataCatalog")
	if catalog == null:
		return
	assert_true(catalog.has_item(BATTERY_ID), "the portable battery is a catalog item")
	if not catalog.has_item(BATTERY_ID):
		return
	var battery: ConsumableData = catalog.get_item(BATTERY_ID) as ConsumableData
	assert_not_null(battery, "it is a ConsumableData")
	if battery == null:
		return
	assert_true(battery is ItemData, "a consumable is an item")
	assert_eq(battery.name_key, BATTERY_NAME_KEY, "name key")
	assert_eq(battery.stack_max, 5, "stacks 5 (BALANCE §2)")
	assert_not_null(battery.icon, "it has an icon")
	assert_eq(battery.battery_points, 20.0, "+20 points (BALANCE §1.1)")


func test_r_012_05_name_translated_es_en() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(BATTERY_NAME_KEY)
			assert_ne(text, "", "'%s' has a text" % locale)
