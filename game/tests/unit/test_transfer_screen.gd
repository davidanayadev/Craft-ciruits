extends GutTest
## TransferScreen (spec 008): hidden until played (R-008-29), a translated
## title (R-008-29), it swallows touches (R-008-29), lasts the duration of
## death.tres (R-008-04) and ends once (R-008-31). Time comes by parameter.

const SCREEN_SCENE := preload("res://scenes/ui/transfer_screen.tscn")
const DEFAULT_CONFIG_PATH := "res://resources/config/death.tres"
const TITLE_KEY := &"TRANSFER_TITLE"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const CUSTOM_DURATION_S := 0.75
const STEP_S := 0.25
const EPSILON_S := 0.01

var _screen: TransferScreen


func before_each() -> void:
	_screen = SCREEN_SCENE.instantiate() as TransferScreen
	add_child_autofree(_screen)
	watch_signals(_screen)


func _config(duration_s: float) -> DeathConfigData:
	var config: DeathConfigData = DeathConfigData.new()
	config.transfer_duration_s = duration_s
	return config


func test_r_008_29_hidden_until_played() -> void:
	assert_false(_screen.visible, "hidden at the start")
	assert_false(_screen.is_playing(), "not playing")
	_screen.play()
	assert_true(_screen.visible, "shown by play()")
	assert_true(_screen.is_playing(), "playing")


func test_r_008_29_title_translated_es_en() -> void:
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, String(TITLE_KEY), "the title is a translation key")
	assert_ne(title.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(TITLE_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, TITLE_KEY])


func test_r_008_29_consumes_touches() -> void:
	assert_eq(_screen.mouse_filter, Control.MOUSE_FILTER_STOP, "touches stop at the screen")
	assert_eq(_screen.anchor_left, 0.0, "it starts at the left edge")
	assert_eq(_screen.anchor_top, 0.0, "and the top edge")
	assert_eq(_screen.anchor_right, 1.0, "it covers the whole width")
	assert_eq(_screen.anchor_bottom, 1.0, "and the whole height")


func test_r_008_04_default_config_is_death_tres() -> void:
	var expected: DeathConfigData = load(DEFAULT_CONFIG_PATH) as DeathConfigData
	assert_not_null(_screen.config, "the scene has a config")
	assert_eq(_screen.config.resource_path, DEFAULT_CONFIG_PATH, "it is death.tres")
	_screen.play()
	_screen.advance(expected.transfer_duration_s - EPSILON_S)
	assert_true(_screen.is_playing(), "still playing just before the duration of death.tres")
	_screen.advance(EPSILON_S)
	assert_false(_screen.is_playing(), "done at the duration of death.tres")


func test_r_008_04_duration_from_config() -> void:
	_screen.config = _config(CUSTOM_DURATION_S)
	_screen.play()
	_screen.advance(CUSTOM_DURATION_S - EPSILON_S)
	assert_true(_screen.is_playing(), "not over just before the custom duration")
	_screen.advance(EPSILON_S)
	assert_false(_screen.is_playing(), "over at the custom duration")
	assert_signal_emit_count(_screen, "finished", 1)


func test_r_008_31_finished_once_after_duration() -> void:
	_screen.config = _config(CUSTOM_DURATION_S)
	_screen.play()
	_screen.advance(STEP_S)
	_screen.advance(STEP_S)
	assert_signal_not_emitted(_screen, "finished", "not finished before the duration")
	_screen.advance(STEP_S)
	assert_signal_emit_count(_screen, "finished", 1, "finished exactly at the duration")
	assert_false(_screen.visible, "hidden afterwards")
	assert_false(_screen.is_playing(), "not playing afterwards")
	_screen.advance(STEP_S)
	_screen.advance(STEP_S)
	assert_signal_emit_count(_screen, "finished", 1, "further time emits nothing")
	_screen.play()
	assert_true(_screen.visible, "it can play again")
	_screen.advance(CUSTOM_DURATION_S)
	assert_signal_emit_count(_screen, "finished", 2, "and finishes again")


func test_r_008_31_play_without_config_reports_error() -> void:
	_screen.config = null
	_screen.play()
	assert_push_error("TransferScreen")
	assert_false(_screen.visible, "stays hidden")
	assert_false(_screen.is_playing(), "does not play")
