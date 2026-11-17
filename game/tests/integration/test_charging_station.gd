extends GutTest
## Charging station (spec 009): a placeable structure with PROMPT_RECHARGE
## (R-009-46); interacting leaves the player's battery at 100 % of its maximum
## at no cost (R-009-47), through BatteryComponent.recharge_full and its usual
## signal (R-009-48), and announces player_recharged once (R-009-49). A
## disabled interactable recharges nothing (R-009-50).

const STATION_SCENE := preload("res://scenes/base/charging_station.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const STATION_PATH := "res://resources/structures/charging_station.tres"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _station: ChargingStation
var _robot: Robot


func before_each() -> void:
	_station = STATION_SCENE.instantiate() as ChargingStation
	add_child_autofree(_station)
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)


func _interactable() -> InteractableComponent:
	return _station.get_node("%Interactable") as InteractableComponent


func test_r_009_46_prompt_recharge() -> void:
	assert_eq(_interactable().prompt_key, &"PROMPT_RECHARGE", "prompt key")
	for locale: String in SUPPORTED_LOCALES:
		var text: String = ""
		for translation: Translation in TranslationServer.find_translations(locale, true):
			text = translation.get_message(&"PROMPT_RECHARGE")
			if not text.is_empty():
				break
		assert_ne(text, "", "PROMPT_RECHARGE translated in %s" % locale)
	var structure: StructureData = load(STATION_PATH) as StructureData
	assert_same(structure.scene, STATION_SCENE, "the StructureData places this scene")
	var shapes: Array[Node] = _station.find_children("*", "CollisionShape3D", false, false)
	assert_gt(shapes.size(), 0, "the station has collision (question 7)")


func test_r_009_47_recharges_to_maximum() -> void:
	_robot.battery.consume(63.0)
	_robot.inventory.add(&"scrap", 3)
	_interactable().interact(_robot)
	assert_eq(_robot.battery.get_current(), _robot.battery.get_maximum(), "100 % of the maximum")
	assert_eq(_robot.inventory.count(&"scrap"), 3, "no cost per use")
	_robot.battery.consume(10.0)
	_interactable().interact(_robot)
	assert_eq(_robot.battery.get_current(), _robot.battery.get_maximum(), "again, no limit of uses")


func test_r_009_48_through_battery_method() -> void:
	_robot.battery.consume(20.0)
	watch_signals(_robot.battery)
	_interactable().interact(_robot)
	assert_signal_emit_count(_robot.battery, "battery_changed", 1, "the usual change signal")
	assert_signal_emitted_with_parameters(
		_robot.battery,
		"battery_changed",
		[_robot.battery.get_maximum(), _robot.battery.get_maximum()]
	)
	var source: String = FileAccess.get_file_as_string("res://scenes/base/charging_station.gd")
	assert_true(source.contains("recharge_full()"), "the station asks the battery to recharge")


func test_r_009_49_player_recharged_once() -> void:
	_robot.battery.consume(20.0)
	watch_signals(EventBus)
	_interactable().interact(_robot)
	assert_signal_emit_count(EventBus, "player_recharged", 1, "once per recharge")
	assert_signal_emitted_with_parameters(EventBus, "player_recharged", [_robot.player_uid])


func test_r_009_50_disabled_station_does_nothing() -> void:
	_robot.battery.consume(20.0)
	# BaseStructures switches it off through its InteractableComponent.
	_interactable().enabled = false
	_interactable().interact(_robot)
	assert_lt(_robot.battery.get_current(), _robot.battery.get_maximum(), "no recharge while off")
	_interactable().enabled = true
	_interactable().interact(_robot)
	assert_eq(_robot.battery.get_current(), _robot.battery.get_maximum(), "back on")


func test_r_009_47_non_player_interactor_reports_error() -> void:
	var stranger: Node3D = Node3D.new()
	add_child_autofree(stranger)
	watch_signals(EventBus)
	_interactable().interact(stranger)
	assert_signal_not_emitted(EventBus, "player_recharged", "only players recharge")
	assert_push_error("not a player")
