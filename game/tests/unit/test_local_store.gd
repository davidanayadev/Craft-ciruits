extends GutTest
## LocalStore (spec 010): demo store with no purchases (R-010-59), reachable
## through GameManager.get_store() (R-010-58), with no save or file access of
## its own (R-010-60).

const SUPPORTED_LOCALES: Array[String] = ["es", "en"]
const LOCAL_STORE_PATH := "res://scripts/services/local_store.gd"
const EXPECTED_TEXT: Dictionary = {
	"es": "Las compras no están disponibles en la demo",
	"en": "Purchases are not available in the demo",
}

var _store: LocalStore


func before_each() -> void:
	_store = LocalStore.new()


func test_r_010_59_always_demo() -> void:
	assert_eq(LocalStore.ERR_STORE_DEMO, &"ERR_STORE_DEMO", "error key constant")
	for id: StringName in [&"", &"remove_ads", &"unlock_full", &"anything"]:
		assert_false(_store.has_entitlement(id), "no entitlement for '%s'" % id)


func test_r_010_59_purchase_fails_deferred() -> void:
	watch_signals(_store)
	_store.purchase(&"unlock_full")
	assert_signal_not_emitted(_store, "purchase_finished", "not during the call")
	await wait_for_signal(_store.purchase_finished, 2.0)
	assert_signal_emit_count(_store, "purchase_finished", 1, "emitted once afterwards")
	var params: Array = get_signal_parameters(_store, "purchase_finished", 0)
	assert_eq(params.size(), 2, "two parameters")
	if params.size() != 2:
		return
	var sku: StringName = params[0]
	var result: ActionResult = params[1]
	assert_eq(sku, &"unlock_full", "the requested sku")
	assert_not_null(result, "a result")
	if result == null:
		return
	assert_false(result.ok, "the purchase fails")
	assert_eq(result.error_key, LocalStore.ERR_STORE_DEMO, "demo error key")
	assert_false(_store.has_entitlement(&"unlock_full"), "still no entitlement")


func test_r_010_59_restore_succeeds_deferred_and_changes_nothing() -> void:
	watch_signals(_store)
	_store.restore()
	assert_signal_not_emitted(_store, "restore_finished", "not during the call")
	await wait_for_signal(_store.restore_finished, 2.0)
	assert_signal_emit_count(_store, "restore_finished", 1, "emitted once afterwards")
	var params: Array = get_signal_parameters(_store, "restore_finished", 0)
	assert_eq(params.size(), 1, "one parameter")
	if params.size() != 1:
		return
	var result: ActionResult = params[0]
	assert_not_null(result, "a result")
	if result == null:
		return
	assert_true(result.ok, "restoring nothing is a success")
	assert_false(_store.has_entitlement(&"unlock_full"), "nothing was restored")


func test_r_010_59_error_key_translated() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		var text: String = ""
		for translation: Translation in translations:
			text = translation.get_message(&"ERR_STORE_DEMO")
			if not text.is_empty():
				break
		var expected: String = EXPECTED_TEXT[locale]
		assert_eq(text, expected, "ERR_STORE_DEMO in %s" % locale)


func test_r_010_58_game_manager_exposes_store() -> void:
	var store: IStore = GameManager.get_store()
	assert_not_null(store, "GameManager has a store")
	if store == null:
		return
	assert_true(store is LocalStore, "the MVP store is a LocalStore")
	var again: IStore = GameManager.get_store()
	assert_true(store == again, "always the same instance")


func test_r_010_60_store_touches_no_save() -> void:
	var source: String = FileAccess.get_file_as_string(LOCAL_STORE_PATH)
	assert_ne(source, "", "local_store.gd is readable")
	assert_false(source.contains("SaveManager"), "no SaveManager reference")
	assert_false(source.contains("FileAccess"), "no file access")
