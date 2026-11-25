class_name CraftingSystem
extends RefCounted
## Pure crafting rules (spec 009, ACTION_PLAN 2.4) over the slots of an
## inventory, like InventoryRules. It never changes them: it decides, and the
## owner of the inventory writes (InventoryComponent, architecture §3). Spec 011
## adds crafting items, creating pieces and the repair cost and checks.

const ERR_NOT_ENOUGH_MATERIALS := &"ERR_NOT_ENOUGH_MATERIALS"
const ERR_NO_ROOM_FOR_RESULT := &"ERR_NO_ROOM_FOR_RESULT"
const ERR_PIECE_INTACT := &"ERR_PIECE_INTACT"
const ERR_PIECE_BROKEN := &"ERR_PIECE_BROKEN"
const ERR_PIECE_NOT_FOUND := &"ERR_PIECE_NOT_FOUND"
## Scale of RepairTierData.up_to_percent (plan 011 D4); not a gameplay value.
const PERCENT := 100


## Item id → total quantity; repeated ingredients are summed.
static func cost_of(recipe: RecipeData) -> Dictionary[StringName, int]:
	return _sum_ingredients(recipe.ingredients, "recipe '%s'" % recipe.id)


static func can_pay(slots: Array[ItemStack], recipe: RecipeData) -> bool:
	return InventoryRules.can_remove_many(slots, cost_of(recipe))


## For an item recipe: ERR_NOT_ENOUGH_MATERIALS, else ERR_NO_ROOM_FOR_RESULT
## when the result fits nowhere once paid, counting the slot a payment frees,
## else success (R-011-12). Never changes slots: it pays on a deep copy. A
## recipe without result_item → push_error, ERR_INVALID_REQUEST.
static func check_craft(slots: Array[ItemStack], recipe: RecipeData) -> ActionResult:
	if recipe == null or recipe.result_item == null:
		push_error("CraftingSystem: check_craft() needs a recipe with result_item.")
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var cost: Dictionary[StringName, int] = cost_of(recipe)
	if not InventoryRules.can_remove_many(slots, cost):
		return ActionResult.failure(ERR_NOT_ENOUGH_MATERIALS)
	var paid: Array[ItemStack] = _deep_copy(slots)
	InventoryRules.remove_many(paid, cost)
	if InventoryRules.space_for(paid, recipe.result_item) < 1:
		return ActionResult.failure(ERR_NO_ROOM_FOR_RESULT)
	return ActionResult.success()


## One unit of item; a PieceData gets its durability_max and a new
## Uid.generate() (R-011-07).
static func create_result(item: ItemData) -> ItemStack:
	var stack: ItemStack = ItemStack.new(item, 1)
	var piece: PieceData = item as PieceData
	if piece != null:
		stack.durability = piece.durability_max
		stack.uid = Uid.generate()
	return stack


## A PieceData below its maximum durability, 0 included.
static func is_damaged(stack: ItemStack) -> bool:
	if stack == null:
		return false
	var piece: PieceData = stack.item as PieceData
	return piece != null and stack.durability < piece.durability_max


## Item id → quantity of the first tier that covers the piece's durability
## left (plan 011 D4, R-011-16). Empty, with push_error, when the stack is not
## a piece or no tier covers it (bad data).
static func repair_cost(stack: ItemStack, costs: RepairCostData) -> Dictionary[StringName, int]:
	var piece: PieceData = null if stack == null else stack.item as PieceData
	if piece == null or costs == null:
		push_error("CraftingSystem: repair_cost() got no repair costs or a stack that is not a piece.")
		return {}
	for tier: RepairTierData in costs.tiers:
		if tier != null and stack.durability * PERCENT <= tier.up_to_percent * piece.durability_max:
			return _sum_ingredients(tier.ingredients, "repair tier %d%%" % tier.up_to_percent)
	push_error(
		"CraftingSystem: no repair tier covers '%s' at %d/%d."
		% [piece.id, stack.durability, piece.durability_max]
	)
	return {}


## Whether the piece piece_uid of slots can be repaired now, in the order of
## plan 011 D5: not found, then check_repair_stack().
static func check_repair(
	slots: Array[ItemStack], piece_uid: String, costs: RepairCostData
) -> ActionResult:
	var index: int = InventoryRules.index_of_uid(slots, piece_uid)
	if index < 0 or not slots[index].item is PieceData:
		return ActionResult.failure(ERR_PIECE_NOT_FOUND)
	return check_repair_stack(slots[index], slots, costs)


## The rules of check_repair for a piece already found, wherever it is (the
## inventory or the equipment, spec 015 plan D16), paid from payer_slots:
## intact (R-011-17), broken (R-011-18), bad repair data → ERR_INVALID_REQUEST
## (reported), not enough materials (R-011-20), in that order. Not a piece →
## ERR_PIECE_NOT_FOUND.
static func check_repair_stack(
	stack: ItemStack, payer_slots: Array[ItemStack], costs: RepairCostData
) -> ActionResult:
	if stack == null or not stack.item is PieceData:
		return ActionResult.failure(ERR_PIECE_NOT_FOUND)
	if not is_damaged(stack):
		return ActionResult.failure(ERR_PIECE_INTACT)
	if stack.durability <= 0:
		return ActionResult.failure(ERR_PIECE_BROKEN)
	var cost: Dictionary[StringName, int] = repair_cost(stack, costs)
	if cost.is_empty():
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	if not InventoryRules.can_remove_many(payer_slots, cost):
		return ActionResult.failure(ERR_NOT_ENOUGH_MATERIALS)
	return ActionResult.success()


## Item id → total quantity; source names the owner in the error of an empty ingredient.
static func _sum_ingredients(
	ingredients: Array[RecipeIngredientData], source: String
) -> Dictionary[StringName, int]:
	var cost: Dictionary[StringName, int] = {}
	for ingredient: RecipeIngredientData in ingredients:
		if ingredient == null or ingredient.item == null:
			push_error("CraftingSystem: %s has an empty ingredient." % source)
			continue
		var item_id: StringName = ingredient.item.id
		cost[item_id] = cost.get(item_id, 0) + ingredient.quantity
	return cost


## InventoryRules.remove changes stacks in place, so a copy of the array alone
## would still pay from the caller's stacks.
static func _deep_copy(slots: Array[ItemStack]) -> Array[ItemStack]:
	var copies: Array[ItemStack] = []
	for stack: ItemStack in slots:
		copies.append(null if stack == null else stack.copy())
	return copies
