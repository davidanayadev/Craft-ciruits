extends GutTest
## Exit point (spec 009): an InteractableComponent with the PROMPT_TRAVEL key
## (R-009-10) whose destination is data of the instance, a ZoneData, never a
## literal in a script (R-009-12). Interacting asks to travel there.

const EXIT_SCENE := preload("res://scenes/zones/exit_point.tscn")
const BASE_ZONE_PATH := "res://resources/zones/base.tres"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _exit: ExitPoint
var _traveller: Node3D


func before_each() -> void:
	_exit = EXIT_SCENE.instantiate() as ExitPoint
	_exit.destination = load(BASE_ZONE_PATH) as ZoneData
	add_child_autofree(_exit)
	_traveller = Node3D.new()
	add_child_autofree(_traveller)


func _interactable() -> InteractableComponent:
	return _exit.get_node("%Interactable") as InteractableComponent


func test_r_009_10_prompt_travel() -> void:
	var interactable: InteractableComponent = _interactable()
	assert_not_null(interactable, "the exit point has an InteractableComponent")
	if interactable == null:
		return
	assert_eq(interactable.prompt_key, &"PROMPT_TRAVEL", "prompt key")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		var text: String = ""
		for translation: Translation in translations:
			text = translation.get_message(&"PROMPT_TRAVEL")
			if not text.is_empty():
				break
		assert_ne(text, "", "PROMPT_TRAVEL translated in %s" % locale)


func test_r_009_11_interacting_requests_travel() -> void:
	watch_signals(_exit)
	_interactable().interact(_traveller)
	assert_signal_emit_count(_exit, "travel_requested", 1, "one request per interaction")
	assert_signal_emitted_with_parameters(_exit, "travel_requested", [_exit.destination, _traveller])


func test_r_009_12_destination_is_exported() -> void:
	var exported: bool = false
	for property: Dictionary in _exit.get_property_list():
		var property_name: String = property["name"]
		var usage: int = property["usage"]
		if property_name == "destination" and usage & PROPERTY_USAGE_EDITOR:
			exported = true
	assert_true(exported, "the destination is an exported field of the instance")
	var source: String = FileAccess.get_file_as_string("res://scenes/zones/exit_point.gd")
	assert_false(source.contains("Vector2i("), "no zone id literal in the script")


func test_r_009_12_without_destination_reports_error() -> void:
	_exit.destination = null
	watch_signals(_exit)
	_interactable().interact(_traveller)
	assert_signal_not_emitted(_exit, "travel_requested", "no destination, no travel")
	assert_push_error("destination")
