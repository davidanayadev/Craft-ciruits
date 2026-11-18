class_name BenchEntry
extends HBoxContainer
## One row of the bench screen (spec 011): Icon, Name, Detail (optional),
## Cost, Notice and ActionButton. It only shows; its section decides whether
## the action can be done (set_blocked) and what pressing it does.

## The action button was pressed.
signal pressed

const COST_ENTRY_KEY := &"BUILD_COST_ENTRY"
const FONT_SIZE := 36
const SEPARATION := 24
const ICON_SIZE := Vector2(64, 64)
const BUTTON_SIZE := Vector2(220, 88)

var _notice: Label = null
var _button: Button = null


## icon null hides it (structures have none) and so does an empty detail. The
## cost shows as "Scrap x4, Cables x2" in the current language.
func setup(
	icon: Texture2D,
	name_key: StringName,
	detail: String,
	cost: Dictionary[StringName, int],
	button_key: StringName
) -> void:
	add_theme_constant_override(&"separation", SEPARATION)
	add_child(_new_icon(icon))
	add_child(_new_label(&"Name", String(name_key), true))
	var detail_label: Label = _new_label(&"Detail", detail, false)
	detail_label.visible = not detail.is_empty()
	add_child(detail_label)
	add_child(_new_label(&"Cost", _cost_text(cost), false))
	_notice = _new_label(&"Notice", "", true)
	_notice.visible = false
	add_child(_notice)
	_button = _new_button(button_key)
	add_child(_button)


## &"" enables the button and hides the notice; otherwise disables it and
## shows the reason, a translation key.
func set_blocked(reason: StringName) -> void:
	_button.disabled = not reason.is_empty()
	_notice.text = String(reason)
	_notice.visible = not reason.is_empty()


## An instance method: tr() needs an object.
func _cost_text(cost: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in cost:
		var item_name: String = tr(DataRegistry.get_item(item_id).name_key)
		parts.append(tr(COST_ENTRY_KEY) % [item_name, cost[item_id]])
	return ", ".join(parts)


func _new_icon(icon: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = icon
	rect.visible = icon != null
	rect.custom_minimum_size = ICON_SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


## translated: the text is a key the label translates itself; otherwise it
## is already translated and shown as it is.
func _new_label(node_name: StringName, text: String, translated: bool) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.auto_translate_mode = (
		Node.AUTO_TRANSLATE_MODE_ALWAYS if translated else Node.AUTO_TRANSLATE_MODE_DISABLED
	)
	return label


func _new_button(text_key: StringName) -> Button:
	var button: Button = Button.new()
	button.name = "ActionButton"
	button.text = String(text_key)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override(&"font_size", FONT_SIZE)
	button.pressed.connect(pressed.emit)
	return button
