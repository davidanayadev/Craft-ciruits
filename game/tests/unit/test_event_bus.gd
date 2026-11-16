extends GutTest
## EventBus (spec 007): the autoload carries enemy_killed(enemy_id, killer_uid)
## (R-007-17, architecture §7) and holds no state of its own, so no XP or any
## other per-player value can live in it (R-007-19, constitution P4).

const SIGNAL_NAME := "enemy_killed"
const ENEMY_ID := &"zombie_slow"
const KILLER_UID := "0123456789abcdef0123456789abcdef"


func _signal_info() -> Dictionary:
	for info: Dictionary in EventBus.get_signal_list():
		if info["name"] == SIGNAL_NAME:
			return info
	return {}


func test_r_007_17_enemy_killed_signature() -> void:
	var info: Dictionary = _signal_info()
	assert_false(info.is_empty(), "EventBus declares enemy_killed")
	if info.is_empty():
		return
	var args: Array = info["args"]
	assert_eq(args.size(), 2, "two arguments")
	if args.size() != 2:
		return
	var first: Dictionary = args[0]
	var second: Dictionary = args[1]
	var first_name: String = first["name"]
	var first_type: int = first["type"]
	var second_name: String = second["name"]
	var second_type: int = second["type"]
	assert_eq(first_name, "enemy_id", "first: the enemy id")
	assert_eq(first_type, TYPE_STRING_NAME, "typed as StringName")
	assert_eq(second_name, "killer_uid", "second: the killer's uid")
	assert_eq(second_type, TYPE_STRING, "typed as String")


func test_r_007_17_enemy_killed_reaches_listeners() -> void:
	watch_signals(EventBus)
	EventBus.enemy_killed.emit(ENEMY_ID, KILLER_UID)
	assert_signal_emitted_with_parameters(EventBus, SIGNAL_NAME, [ENEMY_ID, KILLER_UID])


func test_r_007_19_bus_holds_no_state() -> void:
	var script: Script = EventBus.get_script() as Script
	assert_not_null(script, "EventBus is a script autoload")
	if script == null:
		return
	var variables: PackedStringArray = PackedStringArray()
	for property: Dictionary in script.get_script_property_list():
		var usage: int = property["usage"]
		var property_name: String = property["name"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			variables.append(property_name)
	assert_eq(variables.size(), 0, "EventBus declares no variables: %s" % variables)
