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


## Spec 008: player_died and player_respawned carry the player's uid (R-008-25, R-008-31).
func _signal_info_of(signal_name: String) -> Dictionary:
	for info: Dictionary in EventBus.get_signal_list():
		if info["name"] == signal_name:
			return info
	return {}


func _assert_player_uid_signal(signal_name: String) -> void:
	var info: Dictionary = _signal_info_of(signal_name)
	assert_false(info.is_empty(), "EventBus declares %s" % signal_name)
	if info.is_empty():
		return
	var args: Array = info["args"]
	assert_eq(args.size(), 1, "one argument")
	if args.size() != 1:
		return
	var first: Dictionary = args[0]
	var first_name: String = first["name"]
	var first_type: int = first["type"]
	assert_eq(first_name, "player_uid", "the player uid")
	assert_eq(first_type, TYPE_STRING, "typed as String")


func test_r_008_25_player_died_signature() -> void:
	_assert_player_uid_signal("player_died")
	watch_signals(EventBus)
	EventBus.player_died.emit(KILLER_UID)
	assert_signal_emitted_with_parameters(EventBus, "player_died", [KILLER_UID])


func test_r_008_31_player_respawned_signature() -> void:
	_assert_player_uid_signal("player_respawned")
	watch_signals(EventBus)
	EventBus.player_respawned.emit(KILLER_UID)
	assert_signal_emitted_with_parameters(EventBus, "player_respawned", [KILLER_UID])


## Spec 009: zone_changed (R-009-03), structure_built (R-009-35) and
## player_recharged (R-009-49), architecture §7.
func _assert_one_arg_signal(signal_name: String, arg_name: String, arg_type: int) -> void:
	var info: Dictionary = _signal_info_of(signal_name)
	assert_false(info.is_empty(), "EventBus declares %s" % signal_name)
	if info.is_empty():
		return
	var args: Array = info["args"]
	assert_eq(args.size(), 1, "%s has one argument" % signal_name)
	if args.size() != 1:
		return
	var first: Dictionary = args[0]
	var first_name: String = first["name"]
	var first_type: int = first["type"]
	assert_eq(first_name, arg_name, "%s: argument name" % signal_name)
	assert_eq(first_type, arg_type, "%s: argument type" % signal_name)


func test_r_009_03_zone_changed_signature() -> void:
	_assert_one_arg_signal("zone_changed", "zone_id", TYPE_VECTOR2I)
	watch_signals(EventBus)
	EventBus.zone_changed.emit(Vector2i(0, -1))
	assert_signal_emitted_with_parameters(EventBus, "zone_changed", [Vector2i(0, -1)])


func test_r_009_35_structure_built_signature() -> void:
	_assert_one_arg_signal("structure_built", "structure_uid", TYPE_STRING)


func test_r_009_49_player_recharged_signature() -> void:
	_assert_one_arg_signal("player_recharged", "player_uid", TYPE_STRING)


## Spec 010: structure_moved (R-010-31, architecture §7).
func test_r_010_31_structure_moved_signature() -> void:
	_assert_one_arg_signal("structure_moved", "structure_uid", TYPE_STRING)
