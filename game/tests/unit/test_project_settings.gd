extends GutTest
## Guards the project settings fixed by spec 001 (R-001-14) and the autoloads
## of spec 004: changing one of them from the editor must turn the suite red.

const RENDERER_COMPATIBILITY: String = "gl_compatibility"
## Values of the "Ignore,Warn,Error" hint of every debug/gdscript/warnings/* setting.
const WARNING_LEVEL_ERROR: int = 2
## Values of the "Exclude,Include" hint of debug/gdscript/warnings/directory_rules.
const DIRECTORY_RULE_EXCLUDE: int = 0
const DIRECTORY_RULE_INCLUDE: int = 1
const ADDONS_DIR: String = "res://addons"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const UNSUPPORTED_LOCALE: String = "fr"
const SAMPLE_KEY: StringName = &"APP_TITLE"
const TYPING_WARNINGS: PackedStringArray = [
	"untyped_declaration",
	"unsafe_property_access",
	"unsafe_method_access",
	"unsafe_call_argument",
]


func test_r_001_01_project_name() -> void:
	assert_eq(_get_string("application/config/name"), "CyberScrap")


func test_r_001_01_main_scene_exists() -> void:
	# Without a main scene neither the desktop run nor the exported APK starts.
	var main_scene: String = _get_string("application/run/main_scene")
	assert_ne(main_scene, "", "a main scene is set")
	assert_true(ResourceLoader.exists(main_scene), "the main scene exists")


func test_r_001_02_compatibility_renderer() -> void:
	assert_eq(
		_get_string("rendering/renderer/rendering_method"),
		RENDERER_COMPATIBILITY,
		"desktop renderer",
	)
	assert_eq(
		_get_string("rendering/renderer/rendering_method.mobile"),
		RENDERER_COMPATIBILITY,
		"mobile override",
	)


func test_r_001_03_landscape_1920x1080_expand() -> void:
	# Landscape since 2026-11-14 (decision after the first F0 device test).
	assert_eq(_get_int("display/window/size/viewport_width"), 1920)
	assert_eq(_get_int("display/window/size/viewport_height"), 1080)
	assert_eq(
		_get_int("display/window/handheld/orientation"), DisplayServer.SCREEN_SENSOR_LANDSCAPE
	)
	assert_eq(_get_string("display/window/stretch/mode"), "canvas_items")
	assert_eq(_get_string("display/window/stretch/aspect"), "expand")


func test_r_001_06_typing_warnings_are_errors() -> void:
	for warning: String in TYPING_WARNINGS:
		assert_eq(
			_get_int("debug/gdscript/warnings/" + warning),
			WARNING_LEVEL_ERROR,
			warning,
		)


func test_r_001_06_only_addons_are_excluded_from_warnings() -> void:
	# An exclusion outside addons/ would silently switch the typing errors off for
	# game code. Not an exact match: GUT adds its own rules under addons/ at runtime.
	var rules: Dictionary = ProjectSettings.get_setting("debug/gdscript/warnings/directory_rules")
	assert_eq(_get_rule(rules, ADDONS_DIR), DIRECTORY_RULE_EXCLUDE, "addons/ must stay excluded")
	for path: String in rules:
		if _get_rule(rules, path) == DIRECTORY_RULE_EXCLUDE:
			assert_true(path == ADDONS_DIR or path.begins_with(ADDONS_DIR + "/"), path)


func test_r_001_07_translations_es_en() -> void:
	for locale: String in SUPPORTED_LOCALES:
		# Exact match, and read from the translation itself: tr() would hide a
		# missing language behind the fallback.
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation files loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(SAMPLE_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, SAMPLE_KEY])


func test_r_001_07_unsupported_locale_falls_back_to_english() -> void:
	assert_eq(_get_string("internationalization/locale/fallback"), "en")
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale(UNSUPPORTED_LOCALE)
	var text: String = tr(SAMPLE_KEY)
	TranslationServer.set_locale(original_locale)
	assert_ne(text, String(SAMPLE_KEY), "tr() returns a text, not the key")


func test_r_004_08_19_autoloads_registered() -> void:
	# "*" marks the autoload as enabled (a singleton node under /root).
	assert_eq(_get_string("autoload/GameManager"), "*res://scripts/autoload/game_manager.gd")
	assert_eq(_get_string("autoload/DataRegistry"), "*res://scripts/autoload/data_registry.gd")


func _get_rule(rules: Dictionary, path: String) -> int:
	var decision: int = rules.get(path, DIRECTORY_RULE_INCLUDE)
	return decision


# get_setting() returns a Variant, and unsafe_call_argument (an error in this
# project) rejects passing one straight to GUT's asserts.
func _get_string(setting: String) -> String:
	var value: String = ProjectSettings.get_setting(setting)
	return value


func _get_int(setting: String) -> int:
	var value: int = ProjectSettings.get_setting(setting)
	return value
