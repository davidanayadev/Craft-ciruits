extends GutTest
## WindGenerator (spec 012): the placed generator shows what its state holds
## out of the maximum and the time to the next battery, or "full" (R-012-21),
## repainted on generator_changed and by a 1 s presentation Timer, never in
## _process (plan D17). Its blades turn with a looping AnimationPlayer
## (R-012-22). Without a state (the placement preview) it shows nothing and
## nothing fails. Interacting announces `used`. Times come from a FakeTimeService.

const GENERATOR_SCENE := preload("res://scenes/base/wind_generator.tscn")
const GENERATOR_PATH := "res://resources/structures/wind_generator.tres"
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const KEYS: Array[StringName] = [&"PROMPT_COLLECT", &"GENERATOR_STORED", &"GENERATOR_NEXT", &"GENERATOR_FULL"]
const PERIOD := 100
const MAX_STORED := 3
const START := 1_000

var _generator: WindGenerator
var _state: WindGeneratorComponent
var _clock: FakeTimeService
var _battery_inventory: InventoryComponent


func before_each() -> void:
	_generator = GENERATOR_SCENE.instantiate() as WindGenerator
	add_child_autofree(_generator)
	var config: WindGeneratorData = WindGeneratorData.new()
	config.seconds_per_battery = PERIOD
	config.max_stored = MAX_STORED
	config.battery_item = DataRegistry.get_item(&"portable_battery")
	_state = WindGeneratorComponent.new()
	add_child_autofree(_state)
	_state.start(config, START)
	_clock = FakeTimeService.new()
	_clock.now = START
	_battery_inventory = InventoryComponent.new()
	add_child_autofree(_battery_inventory)
	assert_true(_battery_inventory.set_slot_count(2).ok)


func _label() -> Label3D:
	return _generator.get_node("%Label") as Label3D


func _timer() -> Timer:
	return _generator.get_node("%RefreshTimer") as Timer


func _expected(stored: int, seconds_left: int) -> String:
	var second_line: String = (
		tr(&"GENERATOR_FULL") if seconds_left < 0
		else tr(&"GENERATOR_NEXT") % WindGenerator.format_time_left(seconds_left)
	)
	return "%s\n%s" % [tr(&"GENERATOR_STORED") % [stored, MAX_STORED], second_line]


func test_r_012_21_label_shows_stored_and_time_left() -> void:
	_generator.bind_state(_state, _clock)
	assert_eq(_label().text, _expected(0, PERIOD), "0 of 3 and a whole period left")
	_clock.now = START + PERIOD + 30
	_timer().timeout.emit()
	assert_eq(_label().text, _expected(1, PERIOD - 30), "one made, the next one counting")


func test_r_012_21_full_shows_full() -> void:
	_clock.now = START + 10 * PERIOD
	_generator.bind_state(_state, _clock)
	assert_eq(_label().text, _expected(MAX_STORED, -1), "full")


func test_r_012_21_refreshes_on_change() -> void:
	_clock.now = START + 2 * PERIOD
	_generator.bind_state(_state, _clock)
	assert_eq(_label().text, _expected(2, PERIOD))
	assert_true(_state.collect(_battery_inventory, _clock.now).ok)
	assert_eq(_label().text, _expected(0, PERIOD), "repainted when the state changed")


func test_r_012_21_does_not_process() -> void:
	_generator.bind_state(_state, _clock)
	assert_false(_generator.is_processing(), "no _process")
	assert_false(_generator.is_physics_processing(), "no _physics_process")
	assert_eq(_timer().wait_time, 1.0, "a one-second presentation refresh")
	assert_false(_timer().one_shot, "it repeats")


func test_r_012_21_preview_without_state() -> void:
	assert_eq(_label().text, "", "nothing to show without a state")
	_timer().timeout.emit()
	assert_eq(_label().text, "", "still nothing")
	assert_push_error_count(0, "the placement preview fails nothing")


func test_r_012_21_rebinding_follows_the_new_state() -> void:
	_generator.bind_state(_state, _clock)
	var other: WindGeneratorComponent = WindGeneratorComponent.new()
	add_child_autofree(other)
	other.start(_state.config, START - 2 * PERIOD)
	_generator.bind_state(other, _clock)
	assert_eq(_label().text, _expected(2, PERIOD), "the new state")
	assert_true(_state.collect(_battery_inventory, START + PERIOD).ok)
	assert_eq(_label().text, _expected(2, PERIOD), "the old state no longer repaints it")


func test_r_012_21_format_time_left() -> void:
	assert_eq(WindGenerator.format_time_left(0), "0:00:00")
	assert_eq(WindGenerator.format_time_left(3661), "1:01:01")
	assert_eq(WindGenerator.format_time_left(14400), "4:00:00")


func test_r_012_21_keys_translated_es_en() -> void:
	var interactable: InteractableComponent = _generator.get_node("%Interactable") as InteractableComponent
	assert_eq(interactable.prompt_key, &"PROMPT_COLLECT", "prompt key")
	for locale: String in SUPPORTED_LOCALES:
		for key: StringName in KEYS:
			var found: bool = false
			for translation: Translation in TranslationServer.find_translations(locale, true):
				found = found or not translation.get_message(key).is_empty()
			assert_true(found, "%s translated in %s" % [key, locale])


func test_r_012_22_blades_animation_autoplays() -> void:
	var player: AnimationPlayer = _generator.get_node("%BladesAnimation") as AnimationPlayer
	assert_not_null(player, "an AnimationPlayer for the blades")
	if player == null:
		return
	assert_ne(player.autoplay, "", "it starts by itself")
	var animation: Animation = player.get_animation(player.autoplay)
	assert_not_null(animation, "the autoplay animation exists")
	if animation != null:
		assert_eq(animation.loop_mode, Animation.LOOP_LINEAR, "it loops")


func test_r_012_01_scene_of_the_generator_data() -> void:
	var structure: StructureData = load(GENERATOR_PATH) as StructureData
	assert_same(structure.scene, GENERATOR_SCENE, "the StructureData places this scene")
	assert_gt(_generator.find_children("*", "CollisionShape3D", false, false).size(), 0, "it has a body")


func test_r_012_20_interaction_announces_used() -> void:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.set_physics_process(false)
	watch_signals(_generator)
	(_generator.get_node("%Interactable") as InteractableComponent).interact(robot)
	assert_signal_emitted_with_parameters(_generator, "used", [robot])
