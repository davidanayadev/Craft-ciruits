class_name BuildScreen
extends UIScreen
## Build screen of the repair bench (spec 009, R-009-64): one entry per
## structure recipe of the workbench, with its name, its cost and a "Build"
## button. The button is disabled with a notice when the player cannot pay
## (R-009-39) or the structure fits nowhere in the base (R-009-38). Picking a
## recipe closes the screen and asks the player to build it; nothing is charged
## until it is placed (R-009-65). Spec 011 brings the full bench screen.

const SCREEN_ID := &"build"
## The Robot that builds.
const CONTEXT_PLAYER := &"player"
## The BaseStructures of the world.
const CONTEXT_BASE := &"base"
const MSG_BASE_FULL := &"MSG_BASE_FULL"
const BUILD_BUTTON_KEY := &"BUILD_BUTTON"
const COST_ENTRY_KEY := &"BUILD_COST_ENTRY"

var _player: Robot = null
var _structures: BaseStructures = null

@onready var _entries: VBoxContainer = %Entries


## Missing or wrong context → push_error, no entries.
func setup(context: Dictionary) -> void:
	_player = context.get(CONTEXT_PLAYER) as Robot
	_structures = context.get(CONTEXT_BASE) as BaseStructures
	if _player == null or _structures == null:
		push_error("BuildScreen: the context needs '%s' and '%s'." % [CONTEXT_PLAYER, CONTEXT_BASE])
		return
	for recipe: RecipeData in DataRegistry.get_catalog().get_recipes():
		if recipe.station == RecipeData.Station.WORKBENCH and recipe.result_structure != null:
			_entries.add_child(_new_entry(recipe))


## The reason the recipe cannot be built now; &"" when it can.
func blocking_reason(recipe: RecipeData) -> StringName:
	if not CraftingSystem.can_pay(_player.inventory.get_slots(), recipe):
		return CraftingSystem.ERR_NOT_ENOUGH_MATERIALS
	if not _structures.fits_anywhere(recipe.result_structure):
		return MSG_BASE_FULL
	return &""


func _new_entry(recipe: RecipeData) -> Control:
	var entry: HBoxContainer = HBoxContainer.new()
	entry.name = String(recipe.id)
	entry.add_theme_constant_override(&"separation", 24)
	entry.add_child(_new_label(&"Name", String(recipe.result_structure.name_key), true))
	entry.add_child(_new_label(&"Cost", _cost_text(recipe), false))
	var reason: StringName = blocking_reason(recipe)
	var notice: Label = _new_label(&"Notice", String(reason), true)
	notice.visible = not reason.is_empty()
	entry.add_child(notice)
	var button: Button = Button.new()
	button.name = "BuildButton"
	button.text = String(BUILD_BUTTON_KEY)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(220, 88)
	button.add_theme_font_size_override(&"font_size", 36)
	button.disabled = not reason.is_empty()
	button.pressed.connect(_on_build_pressed.bind(recipe))
	entry.add_child(button)
	return entry


## "Scrap x4, …" in the current language.
func _cost_text(recipe: RecipeData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	for item_id: StringName in cost:
		var item_name: String = tr(DataRegistry.get_item(item_id).name_key)
		parts.append(tr(COST_ENTRY_KEY) % [item_name, cost[item_id]])
	return ", ".join(parts)


## translated: the text is a key the label translates itself; otherwise it
## is already translated and shown as it is.
func _new_label(node_name: StringName, text: String, translated: bool) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override(&"font_size", 36)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.auto_translate_mode = (
		Node.AUTO_TRANSLATE_MODE_ALWAYS if translated else Node.AUTO_TRANSLATE_MODE_DISABLED
	)
	return label


## Closed first, so the placement screen is not stacked on this one.
func _on_build_pressed(recipe: RecipeData) -> void:
	if not blocking_reason(recipe).is_empty():
		return
	close_requested.emit()
	_player.request_build(recipe)
