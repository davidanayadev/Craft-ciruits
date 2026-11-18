class_name BenchCraftSection
extends VBoxContainer
## Craft tab of the bench screen (spec 011): one fixed row per WORKBENCH
## recipe with result_item, named by recipe id, with the icon and name of its
## result, its cost and a "Create" button (R-011-22). The button is disabled
## with the reason of CraftingSystem.check_craft (R-011-23). Creating is a
## request to the bench and happens at once (R-011-15); the rows follow the
## inventory through refresh().

const BUTTON_KEY := &"CRAFT_BUTTON"

var _player: Robot = null
var _bench: RepairBench = null
var _entries: Dictionary[RecipeData, BenchEntry] = {}


func setup(player: Robot, bench: RepairBench) -> void:
	_player = player
	_bench = bench
	for recipe: RecipeData in DataRegistry.get_catalog().get_recipes():
		if recipe.station == RecipeData.Station.WORKBENCH and recipe.result_item != null:
			_add_entry(recipe)
	refresh()


func refresh() -> void:
	for recipe: RecipeData in _entries:
		_entries[recipe].set_blocked(_blocking_reason(recipe))


## &"" when it can be crafted now.
func _blocking_reason(recipe: RecipeData) -> StringName:
	return CraftingSystem.check_craft(_player.inventory.get_slots(), recipe).error_key


func _add_entry(recipe: RecipeData) -> void:
	var item: ItemData = recipe.result_item
	var entry: BenchEntry = BenchEntry.new()
	entry.name = String(recipe.id)
	entry.setup(item.icon, item.name_key, "", CraftingSystem.cost_of(recipe), BUTTON_KEY)
	entry.pressed.connect(_on_entry_pressed.bind(recipe))
	add_child(entry)
	_entries[recipe] = entry


func _on_entry_pressed(recipe: RecipeData) -> void:
	if _blocking_reason(recipe).is_empty():
		_bench.craft(_player, recipe)
