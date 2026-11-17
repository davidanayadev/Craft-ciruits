extends GutTest
## NoticeScreen (spec 010, R-010-55, plan D11): a full-screen notice, with its
## text a translation key, that "back" never closes. The message key comes by
## context; a missing one is a reported error.

const SCREEN_SCENE := preload("res://scenes/ui/notice_screen.tscn")
const MESSAGE_KEY := &"MSG_SAVE_NEWER_VERSION"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _screen: NoticeScreen
var _message: Label


func before_each() -> void:
	_screen = SCREEN_SCENE.instantiate() as NoticeScreen
	add_child_autofree(_screen)
	_message = _screen.get_node("%Message") as Label


func test_r_010_55_setup_shows_the_key() -> void:
	_screen.setup({NoticeScreen.CONTEXT_MESSAGE: MESSAGE_KEY})
	assert_eq(_message.text, String(MESSAGE_KEY), "the label holds the translation key")
	assert_ne(_message.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and translates it")


func test_r_010_55_back_does_not_close() -> void:
	_screen.setup({NoticeScreen.CONTEXT_MESSAGE: MESSAGE_KEY})
	watch_signals(_screen)
	var handled: bool = _screen.handle_back()
	assert_true(handled, "back is handled: nothing below it reacts")
	assert_signal_not_emitted(_screen, "close_requested", "and the screen does not ask to close")


func test_r_010_55_missing_key_is_reported() -> void:
	_screen.setup({})
	assert_push_error("opened without a message key")
	assert_eq(_message.text, "", "no text is invented")


func test_r_010_55_key_is_translated() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var text: String = ""
		for translation: Translation in TranslationServer.find_translations(locale, true):
			text = translation.get_message(MESSAGE_KEY)
			if not text.is_empty():
				break
		assert_ne(text, "", "%s in %s" % [MESSAGE_KEY, locale])
