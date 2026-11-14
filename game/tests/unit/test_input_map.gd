extends GutTest
## R-001-08: one InputMap action per PMV control, each one playable from a PC
## keyboard. This list is the executable spec of the action names (plan 001 §6, P2).

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
