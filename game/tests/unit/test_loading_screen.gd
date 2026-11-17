extends GutTest
## LoadingScreen (spec 009, R-009-07): hidden until a travel starts, a title
## from a translation key in ES and EN, and it swallows touches while it shows.

const SCREEN_SCENE := preload("res://scenes/ui/loading_screen.tscn")
const TITLE_KEY := &"LOADING_TITLE"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _screen: LoadingScreen


func before_each() -> void:
	_screen = SCREEN_SCENE.instantiate() as LoadingScreen
	add_child_autofree(_screen)


func test_r_009_07_hidden_until_shown() -> void:
	assert_false(_screen.is_showing(), "hidden at the start")
	_screen.show_loading()
	assert_true(_screen.visible, "shown")
	_screen.hide_loading()
	assert_false(_screen.is_showing(), "hidden again")


func test_r_009_07_texts_are_keys() -> void:
	var title: Label = _screen.get_node("%Title") as Label
	assert_eq(title.text, String(TITLE_KEY), "the title is a translation key")
	assert_ne(title.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated")
	for locale: String in SUPPORTED_LOCALES:
		var text: String = ""
		for translation: Translation in TranslationServer.find_translations(locale, true):
			text = translation.get_message(TITLE_KEY)
			if not text.is_empty():
				break
		assert_ne(text, "", "'%s' has a text for %s" % [locale, TITLE_KEY])


func test_r_009_07_consumes_touches() -> void:
	assert_eq(_screen.mouse_filter, Control.MOUSE_FILTER_STOP, "touches stop at the screen")
