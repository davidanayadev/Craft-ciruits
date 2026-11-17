extends GutTest
## Repair bench (spec 009): interactable through an InteractableComponent with
## a translation key in ES and EN (R-009-63); interacting is a request the
## base relays (bench_used), never an action of its own.

const BENCH_SCENE := preload("res://scenes/base/repair_bench.tscn")
const BASE_SCENE := preload("res://scenes/base/base.tscn")
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _bench: RepairBench
var _user: Node3D


func before_each() -> void:
	_bench = BENCH_SCENE.instantiate() as RepairBench
	add_child_autofree(_bench)
	_user = Node3D.new()
	add_child_autofree(_user)


func test_r_009_63_interactable_with_key() -> void:
	var interactable: InteractableComponent = _bench.get_node("%Interactable") as InteractableComponent
	assert_not_null(interactable, "the bench has an InteractableComponent")
	if interactable == null:
		return
	assert_eq(interactable.prompt_key, &"PROMPT_USE", "prompt key")
	for locale: String in SUPPORTED_LOCALES:
		var text: String = ""
		for translation: Translation in TranslationServer.find_translations(locale, true):
			text = translation.get_message(&"PROMPT_USE")
			if not text.is_empty():
				break
		assert_ne(text, "", "PROMPT_USE translated in %s" % locale)
	watch_signals(_bench)
	interactable.interact(_user)
	assert_signal_emit_count(_bench, "used", 1, "one request per interaction")
	assert_signal_emitted_with_parameters(_bench, "used", [_user])


func test_r_009_63_base_relays_bench_use() -> void:
	var base: BaseZone = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(base)
	watch_signals(base)
	var bench: Node = base.get_node("%RepairBench")
	(bench.get_node("Interactable") as InteractableComponent).interact(_user)
	assert_signal_emitted_with_parameters(base, "bench_used", [_user])
