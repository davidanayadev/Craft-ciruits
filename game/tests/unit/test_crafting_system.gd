extends GutTest
## CraftingSystem (spec 009, plan §3): pure cost and "can pay" over an
## Array[ItemStack], like InventoryRules. Covers R-009-62 (cost_of sums repeated
## ingredients; can_pay) and R-009-39 (the missing-materials key). Removing the
## ingredients belongs to InventoryComponent.remove_many (see
## test_inventory_component.gd). Items and recipes are built by hand.


func _item(id: StringName, stack_max: int = 10) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = id
	item.stack_max = stack_max
	return item


func _ingredient(item: ItemData, quantity: int) -> RecipeIngredientData:
	var ingredient: RecipeIngredientData = RecipeIngredientData.new()
	ingredient.item = item
	ingredient.quantity = quantity
	return ingredient


func _recipe(ingredients: Array[RecipeIngredientData]) -> RecipeData:
	var recipe: RecipeData = RecipeData.new()
	recipe.id = &"test_recipe"
	recipe.station = RecipeData.Station.WORKBENCH
	recipe.tier = 1
	recipe.ingredients = ingredients
	return recipe


func _slots(item: ItemData, quantities: Array[int]) -> Array[ItemStack]:
	var slots: Array[ItemStack] = []
	for quantity: int in quantities:
		slots.append(null if quantity == 0 else ItemStack.new(item, quantity))
	return slots


func _quantities(slots: Array[ItemStack]) -> Array[int]:
	var result: Array[int] = []
	for stack: ItemStack in slots:
		result.append(0 if stack == null else stack.quantity)
	return result


func test_r_009_39_error_key() -> void:
	assert_eq(CraftingSystem.ERR_NOT_ENOUGH_MATERIALS, &"ERR_NOT_ENOUGH_MATERIALS")


func test_r_009_62_cost_of() -> void:
	var scrap: ItemData = _item(&"scrap")
	var cables: ItemData = _item(&"cables")
	var recipe: RecipeData = _recipe([_ingredient(scrap, 4), _ingredient(cables, 2)])
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	assert_eq(cost.size(), 2)
	assert_eq(cost[&"scrap"], 4)
	assert_eq(cost[&"cables"], 2)


func test_r_009_62_repeated_ingredient() -> void:
	var scrap: ItemData = _item(&"scrap")
	var cables: ItemData = _item(&"cables")
	var recipe: RecipeData = _recipe(
		[_ingredient(scrap, 3), _ingredient(cables, 1), _ingredient(scrap, 2)]
	)
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	assert_eq(cost.size(), 2, "one entry per item")
	assert_eq(cost[&"scrap"], 5, "3 + 2")
	assert_eq(cost[&"cables"], 1)
	# can_pay uses the summed cost: 4 scrap are not enough for 3 + 2.
	var slots: Array[ItemStack] = _slots(scrap, [4])
	slots.append(ItemStack.new(cables, 1))
	assert_false(CraftingSystem.can_pay(slots, recipe), "4 scrap < 5")
	slots[0].quantity = 5
	assert_true(CraftingSystem.can_pay(slots, recipe), "5 scrap is enough")


func test_r_009_62_exact() -> void:
	var scrap: ItemData = _item(&"scrap")
	var recipe: RecipeData = _recipe([_ingredient(scrap, 4)])
	var slots: Array[ItemStack] = _slots(scrap, [3, 1])
	assert_true(CraftingSystem.can_pay(slots, recipe), "exactly the cost, split over two stacks")
	assert_eq(_quantities(slots), [3, 1] as Array[int], "can_pay changes nothing")


func test_r_009_62_surplus() -> void:
	var scrap: ItemData = _item(&"scrap")
	var recipe: RecipeData = _recipe([_ingredient(scrap, 4)])
	var slots: Array[ItemStack] = _slots(scrap, [10, 7])
	assert_true(CraftingSystem.can_pay(slots, recipe))
	assert_eq(_quantities(slots), [10, 7] as Array[int])


func test_r_009_62_insufficient() -> void:
	var scrap: ItemData = _item(&"scrap")
	var cables: ItemData = _item(&"cables")
	var recipe: RecipeData = _recipe([_ingredient(scrap, 4), _ingredient(cables, 2)])
	var short: Array[ItemStack] = _slots(scrap, [3])
	short.append(ItemStack.new(cables, 2))
	assert_false(CraftingSystem.can_pay(short, recipe), "one scrap short")
	var missing_kind: Array[ItemStack] = _slots(scrap, [10])
	assert_false(CraftingSystem.can_pay(missing_kind, recipe), "no cables at all")
	var empty: Array[ItemStack] = _slots(scrap, [0, 0, 0])
	assert_false(CraftingSystem.can_pay(empty, recipe), "empty inventory")
	assert_eq(_quantities(short), [3, 2] as Array[int], "can_pay changes nothing")
