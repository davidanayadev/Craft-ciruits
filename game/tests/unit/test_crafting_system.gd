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


# --- Crafting items and repairing pieces (spec 011) ---------------------------

func _piece(id: StringName, durability_max: int = 100) -> PieceData:
	var piece: PieceData = PieceData.new()
	piece.id = id
	piece.stack_max = 1
	piece.durability_max = durability_max
	return piece


func _piece_stack(piece: PieceData, durability: int, stack_uid: String) -> ItemStack:
	var stack: ItemStack = ItemStack.new(piece, 1)
	stack.durability = durability
	stack.uid = stack_uid
	return stack


func _item_recipe(result: ItemData, ingredients: Array[RecipeIngredientData]) -> RecipeData:
	var recipe: RecipeData = _recipe(ingredients)
	recipe.result_item = result
	return recipe


func _tier(up_to_percent: int, ingredients: Array[RecipeIngredientData]) -> RepairTierData:
	var tier: RepairTierData = RepairTierData.new()
	tier.up_to_percent = up_to_percent
	tier.ingredients = ingredients
	return tier


## The tiers of BALANCE §4.3.2 with hand-made items.
func _costs(iron: ItemData, cables: ItemData) -> RepairCostData:
	var costs: RepairCostData = RepairCostData.new()
	costs.tiers = [
		_tier(25, [_ingredient(iron, 3), _ingredient(cables, 2)]),
		_tier(100, [_ingredient(iron, 2), _ingredient(cables, 1)]),
	]
	return costs


## A damaged piece "p" (or intact, or broken) next to plenty of iron and cables.
func _repair_slots(
	piece: PieceData, durability: int, iron: ItemData, cables: ItemData, materials: int = 10
) -> Array[ItemStack]:
	return [
		_piece_stack(piece, durability, "p"),
		ItemStack.new(iron, materials),
		ItemStack.new(cables, materials),
	]


func test_r_011_07_create_result_piece() -> void:
	var arms: PieceData = _piece(&"basic_arms", 80)
	var stack: ItemStack = CraftingSystem.create_result(arms)
	assert_same(stack.item, arms, "the piece")
	assert_eq(stack.quantity, 1, "one unit")
	assert_eq(stack.durability, 80, "at its maximum durability")
	assert_eq(stack.uid.length(), 32, "a uid from Uid.generate()")
	var scrap: ItemData = _item(&"scrap")
	var material: ItemStack = CraftingSystem.create_result(scrap)
	assert_eq(material.quantity, 1, "an item result is one unit")
	assert_eq(material.durability, -1, "a material has no durability")
	assert_eq(material.uid, "", "a material has no uid")


func test_r_011_07_create_result_new_uid_each_time() -> void:
	var arms: PieceData = _piece(&"basic_arms")
	var first: ItemStack = CraftingSystem.create_result(arms)
	var second: ItemStack = CraftingSystem.create_result(arms)
	assert_ne(first.uid, second.uid, "every piece has its own uid")


func test_r_011_12_exact() -> void:
	var scrap: ItemData = _item(&"scrap")
	var recipe: RecipeData = _item_recipe(_piece(&"basic_arms"), [_ingredient(scrap, 4)])
	var slots: Array[ItemStack] = _slots(scrap, [3, 1, 0])
	assert_true(CraftingSystem.check_craft(slots, recipe).ok, "exactly the cost and a free slot")


func test_r_011_12_surplus() -> void:
	var scrap: ItemData = _item(&"scrap")
	var recipe: RecipeData = _item_recipe(_piece(&"basic_arms"), [_ingredient(scrap, 4)])
	var slots: Array[ItemStack] = _slots(scrap, [10, 0])
	assert_true(CraftingSystem.check_craft(slots, recipe).ok, "more than the cost and a free slot")


func test_r_011_12_insufficient() -> void:
	var scrap: ItemData = _item(&"scrap")
	var recipe: RecipeData = _item_recipe(_piece(&"basic_arms"), [_ingredient(scrap, 4)])
	var result: ActionResult = CraftingSystem.check_craft(_slots(scrap, [3, 0]), recipe)
	assert_false(result.ok, "one short")
	assert_eq(result.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS)
	# Missing materials come first: it is what the player can fix in the zone.
	var full_and_short: ActionResult = CraftingSystem.check_craft(_slots(scrap, [3]), recipe)
	assert_eq(full_and_short.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS)


func test_r_011_12_full_inventory() -> void:
	var scrap: ItemData = _item(&"scrap")
	var cables: ItemData = _item(&"cables")
	var recipe: RecipeData = _item_recipe(_piece(&"basic_arms"), [_ingredient(scrap, 4)])
	var slots: Array[ItemStack] = _slots(scrap, [5])
	slots.append(ItemStack.new(cables, 1))
	var result: ActionResult = CraftingSystem.check_craft(slots, recipe)
	assert_false(result.ok, "no slot frees and none is empty")
	assert_eq(result.error_key, CraftingSystem.ERR_NO_ROOM_FOR_RESULT)


func test_r_011_12_payment_frees_the_slot() -> void:
	var scrap: ItemData = _item(&"scrap")
	var cables: ItemData = _item(&"cables")
	var recipe: RecipeData = _item_recipe(
		_piece(&"basic_arms"), [_ingredient(scrap, 4), _ingredient(cables, 2)]
	)
	var slots: Array[ItemStack] = _slots(scrap, [6])
	slots.append(ItemStack.new(cables, 2))
	assert_true(CraftingSystem.check_craft(slots, recipe).ok, "paying the cables empties their slot")


func test_r_011_12_check_does_not_change_slots() -> void:
	var scrap: ItemData = _item(&"scrap")
	var cables: ItemData = _item(&"cables")
	var recipe: RecipeData = _item_recipe(
		_piece(&"basic_arms"), [_ingredient(scrap, 4), _ingredient(cables, 2)]
	)
	var slots: Array[ItemStack] = _slots(scrap, [6])
	slots.append(ItemStack.new(cables, 2))
	var held_scrap: ItemStack = slots[0]
	CraftingSystem.check_craft(slots, recipe)
	assert_eq(_quantities(slots), [6, 2] as Array[int], "the quantities did not change")
	assert_same(slots[0], held_scrap, "the stacks are the same objects")
	assert_eq(held_scrap.quantity, 6, "the stack itself was not paid from")


func test_r_011_16_repair_cost_tiers() -> void:
	var iron: ItemData = _item(&"iron")
	var cables: ItemData = _item(&"cables")
	var costs: RepairCostData = _costs(iron, cables)
	var arms: PieceData = _piece(&"basic_arms", 100)
	var cheap: Dictionary[StringName, int] = {&"iron": 2, &"cables": 1}
	var dear: Dictionary[StringName, int] = {&"iron": 3, &"cables": 2}
	for durability: int in [99, 26]:
		var cost: Dictionary[StringName, int] = CraftingSystem.repair_cost(
			_piece_stack(arms, durability, "a"), costs
		)
		assert_eq(cost, cheap, "%d/100 → damaged" % durability)
	for durability: int in [25, 1]:
		var cost: Dictionary[StringName, int] = CraftingSystem.repair_cost(
			_piece_stack(arms, durability, "a"), costs
		)
		assert_eq(cost, dear, "%d/100 → very damaged" % durability)
	# Another maximum: the tier is a percent of it (25 % of 40 is 10).
	var other: PieceData = _piece(&"other", 40)
	var at_border: Dictionary[StringName, int] = CraftingSystem.repair_cost(_piece_stack(other, 10, "b"), costs)
	assert_eq(at_border, dear, "10/40 is 25 %")
	var above: Dictionary[StringName, int] = CraftingSystem.repair_cost(_piece_stack(other, 11, "b"), costs)
	assert_eq(above, cheap, "11/40 is above 25 %")


func test_r_011_16_repair_cost_bad_data() -> void:
	var iron: ItemData = _item(&"iron")
	var costs: RepairCostData = RepairCostData.new()
	costs.tiers = [_tier(25, [_ingredient(iron, 3)])]
	var arms: PieceData = _piece(&"basic_arms", 100)
	var uncovered: Dictionary[StringName, int] = CraftingSystem.repair_cost(_piece_stack(arms, 50, "a"), costs)
	assert_eq(uncovered.size(), 0, "no tier covers 50 %")
	assert_push_error("no repair tier")
	var material: Dictionary[StringName, int] = CraftingSystem.repair_cost(ItemStack.new(iron, 3), costs)
	assert_eq(material.size(), 0, "a material has no repair cost")
	assert_push_error("not a piece")


func test_r_011_17_intact_refused() -> void:
	var iron: ItemData = _item(&"iron")
	var cables: ItemData = _item(&"cables")
	var slots: Array[ItemStack] = _repair_slots(_piece(&"basic_arms", 100), 100, iron, cables)
	var result: ActionResult = CraftingSystem.check_repair(slots, "p", _costs(iron, cables))
	assert_false(result.ok, "an intact piece is not repaired")
	assert_eq(result.error_key, CraftingSystem.ERR_PIECE_INTACT)
	assert_false(CraftingSystem.is_damaged(slots[0]), "an intact piece is not damaged")


func test_r_011_18_broken_refused() -> void:
	var iron: ItemData = _item(&"iron")
	var cables: ItemData = _item(&"cables")
	var slots: Array[ItemStack] = _repair_slots(_piece(&"basic_arms", 100), 0, iron, cables)
	var result: ActionResult = CraftingSystem.check_repair(slots, "p", _costs(iron, cables))
	assert_false(result.ok, "a broken piece is not repaired")
	assert_eq(result.error_key, CraftingSystem.ERR_PIECE_BROKEN)
	assert_true(CraftingSystem.is_damaged(slots[0]), "a piece at 0 counts as damaged")


func test_r_011_20_unknown_uid() -> void:
	var iron: ItemData = _item(&"iron")
	var cables: ItemData = _item(&"cables")
	var costs: RepairCostData = _costs(iron, cables)
	var slots: Array[ItemStack] = _repair_slots(_piece(&"basic_arms", 100), 50, iron, cables)
	var result: ActionResult = CraftingSystem.check_repair(slots, "nope", costs)
	assert_false(result.ok)
	assert_eq(result.error_key, CraftingSystem.ERR_PIECE_NOT_FOUND)
	assert_eq(CraftingSystem.check_repair(slots, "", costs).error_key, CraftingSystem.ERR_PIECE_NOT_FOUND)


func test_r_011_20_repair_check_materials() -> void:
	var iron: ItemData = _item(&"iron")
	var cables: ItemData = _item(&"cables")
	var arms: PieceData = _piece(&"basic_arms", 100)
	var costs: RepairCostData = _costs(iron, cables)
	var enough: Array[ItemStack] = [
		_piece_stack(arms, 50, "p"), ItemStack.new(iron, 2), ItemStack.new(cables, 1)
	]
	assert_true(CraftingSystem.check_repair(enough, "p", costs).ok, "exactly the damaged cost")
	var short: Array[ItemStack] = [
		_piece_stack(arms, 20, "p"), ItemStack.new(iron, 2), ItemStack.new(cables, 1)
	]
	var result: ActionResult = CraftingSystem.check_repair(short, "p", costs)
	assert_false(result.ok, "the very damaged cost is higher")
	assert_eq(result.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS)
	assert_true(CraftingSystem.is_damaged(short[0]), "20/100 is damaged")
	assert_false(CraftingSystem.is_damaged(short[1]), "a material is never damaged")


func test_r_011_12_no_room_key() -> void:
	assert_eq(CraftingSystem.ERR_NO_ROOM_FOR_RESULT, &"ERR_NO_ROOM_FOR_RESULT")


func test_r_011_20_repair_refusal_keys() -> void:
	assert_eq(CraftingSystem.ERR_PIECE_INTACT, &"ERR_PIECE_INTACT")
	assert_eq(CraftingSystem.ERR_PIECE_BROKEN, &"ERR_PIECE_BROKEN")
	assert_eq(CraftingSystem.ERR_PIECE_NOT_FOUND, &"ERR_PIECE_NOT_FOUND")
