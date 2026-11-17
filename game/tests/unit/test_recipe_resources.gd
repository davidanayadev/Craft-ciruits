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
