extends GutTest
## Provisional game over screen (R-003-12): hidden until opened, with a restart
## button and texts in ES and EN. Headless cannot click Controls (ADR 0002), so
## the button's pressed signal is emitted by hand; the real tap is verified on
## the device (T-003-08).

const GAME_OVER_SCENE := preload("res://scenes/ui/game_over_screen.tscn")
const TITLE_KEY: StringName = &"GAME_OVER_TITLE"
const RESTART_KEY: StringName = &"GAME_OVER_RESTART"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _screen: GameOverScreen
var _title: Label
var _restart_button: Button


func before_each() -> void:
	_screen = GAME_OVER_SCENE.instantiate() as GameOverScreen
	add_child_autofree(_screen)
	_title = _screen.get_node("%Title") as Label
	_restart_button = _screen.get_node("%RestartButton") as Button
	watch_signals(_screen)


func test_r_003_12_hidden_until_opened() -> void:
	assert_false(_screen.visible, "hidden while the robot is alive")
	_screen.open()
	assert_true(_screen.visible, "open() shows the screen")
	assert_true(_restart_button.has_focus(), "the restart button takes the focus")


func test_r_003_12_restart_button_emits() -> void:
	_screen.open()
	_restart_button.pressed.emit()
	assert_signal_emit_count(_screen, "restart_requested", 1)


func test_r_003_12_texts_in_es_and_en() -> void:
	assert_eq(_title.text, String(TITLE_KEY), "the title is a translation key")
	assert_eq(_restart_button.text, String(RESTART_KEY), "the button is a translation key")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for key: StringName in [TITLE_KEY, RESTART_KEY]:
			var text: String = translations[0].get_message(key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, key])
