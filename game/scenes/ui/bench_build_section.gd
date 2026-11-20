class_name BenchBuildSection
extends VBoxContainer
## Build tab of the bench screen (spec 009 logic, moved by spec 011): one row
## per structure recipe of the workbench, with its name, its cost and a
## "Build" button (R-009-64). The button is disabled with a notice when the
## player cannot pay (R-009-39) or the structure fits nowhere in the base
## (R-009-38), and before both when the base holds the most of that
## structure (spec 012, R-012-08). Picking a recipe is announced; nothing is charged until it is
## placed (R-009-65).

## The player picked recipe; the screen closes and asks the player to build it.
signal build_picked(recipe: RecipeData)

const MSG_BASE_FULL := &"MSG_BASE_FULL"
const BUTTON_KEY := &"BUILD_BUTTON"

var _player: Robot = null
var _structures: BaseStructures = null
var _entries: Dictionary[RecipeData, BenchEntry] = {}


func setup(player: Robot, structures: BaseStructures) -> void:
	_player = player
	_structures = structures
	for recipe: RecipeData in DataRegistry.get_catalog().get_recipes():
		if recipe.station == RecipeData.Station.WORKBENCH and recipe.result_structure != null:
			_add_entry(recipe)
	refresh()


func refresh() -> void:
	for recipe: RecipeData in _entries:
		_entries[recipe].set_blocked(blocking_reason(recipe))


## The reason the recipe cannot be built now; &"" when it can.
func blocking_reason(recipe: RecipeData) -> StringName:
	if _structures.is_at_limit(recipe.result_structure):
		return BaseStructures.MSG_STRUCTURE_LIMIT
	if not CraftingSystem.can_pay(_player.inventory.get_slots(), recipe):
		return CraftingSystem.ERR_NOT_ENOUGH_MATERIALS
	if not _structures.fits_anywhere(recipe.result_structure):
		return MSG_BASE_FULL
	return &""


func _add_entry(recipe: RecipeData) -> void:
	var entry: BenchEntry = BenchEntry.new()
	entry.name = String(recipe.id)
	entry.setup(null, recipe.result_structure.name_key, "", CraftingSystem.cost_of(recipe), BUTTON_KEY)
	entry.pressed.connect(_on_entry_pressed.bind(recipe))
	add_child(entry)
	_entries[recipe] = entry


func _on_entry_pressed(recipe: RecipeData) -> void:
	if blocking_reason(recipe).is_empty():
		build_picked.emit(recipe)
