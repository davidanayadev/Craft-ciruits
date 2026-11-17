extends GutTest
## R-001-08: one InputMap action per PMV control, each one playable from a PC
## keyboard. This list is the executable spec of the action names (plan 001 §6, P2).
## Spec 009 adds confirm (Enter) for the placement mode on PC (R-009-40, R-009-56).

const ACTIONS: Array[StringName] = [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
	&"run",
	&"attack",
	&"use_consumable",
	&"interact",
	&"open_storage",
	&"pause",
	&"confirm",
]


func test_r_001_08_actions_exist_with_keyboard_binding() -> void:
	for action: StringName in ACTIONS:
		assert_true(InputMap.has_action(action), "action '%s' exists" % action)
		assert_true(_has_keyboard_binding(action), "action '%s' has a keyboard binding" % action)


func _has_keyboard_binding(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return true
	return false


func test_r_009_40_confirm_action() -> void:
	assert_true(InputMap.has_action(&"confirm"), "confirm exists")
	var keys: Array[Key] = []
	for event: InputEvent in InputMap.action_get_events(&"confirm"):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			keys.append(key_event.physical_keycode)
	assert_true(keys.has(KEY_ENTER), "Enter confirms")
	assert_true(keys.has(KEY_KP_ENTER), "and the keypad Enter")
