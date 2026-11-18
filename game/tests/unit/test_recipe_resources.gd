extends GutTest
## Recipe data (spec 009, R-009-61): the charging station recipe costs what
## BALANCE §5.3 says, is built at the workbench, tier 1, with no requirements.
## The expected values mirror BALANCE.md §5.3; update both together.

const RECIPE_PATH := "res://resources/recipes/charging_station.tres"
const STATION_PATH := "res://resources/structures/charging_station.tres"


func test_r_009_61_charging_station_recipe() -> void:
	var recipe: RecipeData = load(RECIPE_PATH) as RecipeData
	assert_not_null(recipe, "charging_station.tres exists and is a RecipeData")
	if recipe == null:
		return
	assert_eq(recipe.id, &"charging_station", "stable id")
	assert_eq(recipe.station, RecipeData.Station.WORKBENCH, "built at the repair bench")
	assert_eq(recipe.tier, 1, "tier 1")
	assert_eq(recipe.requires.size(), 0, "no requirements")
	assert_same(recipe.result_structure, load(STATION_PATH), "it builds the charging station")
	assert_eq(recipe.ingredients.size(), 1, "one ingredient")
	if recipe.ingredients.size() != 1 or recipe.ingredients[0] == null:
		return
	var ingredient: RecipeIngredientData = recipe.ingredients[0]
	assert_not_null(ingredient.item, "the ingredient has an item")
	if ingredient.item != null:
		assert_eq(ingredient.item.id, &"scrap", "made of scrap (BALANCE §5.3)")
	assert_eq(ingredient.quantity, 4, "4 scrap (BALANCE §5.3)")


# --- Piece recipes (spec 011, R-011-04) --------------------------------------
# The expected values mirror BALANCE.md §4.3.1; update both together.

## recipe id → {item id → quantity} (BALANCE §4.3.1).
const EXPECTED_PIECE_RECIPES: Dictionary[StringName, Dictionary] = {
	&"basic_arms": {&"scrap": 4, &"cables": 2},
	&"basic_legs": {&"scrap": 4, &"iron": 2},
	&"basic_core": {&"scrap": 6, &"cables": 3, &"iron": 2},
}


func test_r_011_04_piece_recipes_match_balance() -> void:
	for id: StringName in EXPECTED_PIECE_RECIPES:
		var recipe: RecipeData = load("res://resources/recipes/%s.tres" % id) as RecipeData
		assert_not_null(recipe, "%s.tres exists and is a RecipeData" % id)
		if recipe == null:
			continue
		assert_eq(recipe.id, id, "stable id")
		assert_null(recipe.result_structure, "%s builds no structure" % id)
		assert_not_null(recipe.result_item, "%s makes an item" % id)
		if recipe.result_item != null:
			assert_eq(recipe.result_item.id, id, "%s makes the piece of the same id" % id)
			assert_true(recipe.result_item is PieceData, "%s makes a piece" % id)
		var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
		var expected: Dictionary = EXPECTED_PIECE_RECIPES[id]
		assert_eq(cost.size(), expected.size(), "%s: one ingredient per material" % id)
		for item_id: StringName in expected:
			var quantity: int = expected[item_id]
			var held: int = cost.get(item_id, 0)
			assert_eq(held, quantity, "%s: %s (BALANCE §4.3.1)" % [id, item_id])
