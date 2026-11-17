class_name CraftingSystem
extends RefCounted
## Pure crafting rules (spec 009, ACTION_PLAN 2.4) over the slots of an
## inventory, like InventoryRules. It never removes anything: the owner of the
## inventory pays with InventoryComponent.remove_many (architecture §3).
## Spec 011 adds pieces and repair on top.

const ERR_NOT_ENOUGH_MATERIALS := &"ERR_NOT_ENOUGH_MATERIALS"


## Item id → total quantity; repeated ingredients are summed.
static func cost_of(recipe: RecipeData) -> Dictionary[StringName, int]:
	var cost: Dictionary[StringName, int] = {}
	for ingredient: RecipeIngredientData in recipe.ingredients:
		if ingredient == null or ingredient.item == null:
			push_error("CraftingSystem: recipe '%s' has an empty ingredient." % recipe.id)
			continue
		var item_id: StringName = ingredient.item.id
		cost[item_id] = cost.get(item_id, 0) + ingredient.quantity
	return cost


static func can_pay(slots: Array[ItemStack], recipe: RecipeData) -> bool:
	return InventoryRules.can_remove_many(slots, cost_of(recipe))
