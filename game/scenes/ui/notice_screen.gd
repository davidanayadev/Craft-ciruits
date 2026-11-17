class_name NoticeScreen
extends UIScreen
## A full-screen notice that cannot be closed (spec 010, plan D11): a save of a
## newer version of the game blocks it until the player updates (R-010-55).
## Neither Escape nor "back" closes it; the main menu of ACTION_PLAN 4.2 will
## offer a way out.

const SCREEN_ID := &"notice"
## Translation key of the text to show.
const CONTEXT_MESSAGE := &"message"

@onready var _message: Label = %Message


func setup(context: Dictionary) -> void:
	var message_key: StringName = context.get(CONTEXT_MESSAGE, &"")
	if message_key.is_empty():
		push_error("NoticeScreen '%s': opened without a message key." % name)
	# A translation key: the label translates its own text.
	_message.text = String(message_key)


## It stays open.
func handle_back() -> bool:
	return true
