class_name InventoryAddResult
extends ActionResult
## Result of adding to an inventory (spec 005). ok means everything entered: a
## failure for lack of room may still have added a part (R-005-05).

## What was not added, one stack per offered stack that did not fit whole, in the
## order offered. Empty when ok. A rejected add_stacks() (ERR_INVALID_REQUEST) returns
## everything offered; a rejected add() or take_from() has no stacks to return.
var leftovers: Array[ItemStack] = []


static func added_all() -> InventoryAddResult:
	var result: InventoryAddResult = InventoryAddResult.new()
	result.ok = true
	return result


static func not_added(key: StringName, p_leftovers: Array[ItemStack]) -> InventoryAddResult:
	var result: InventoryAddResult = InventoryAddResult.new()
	result.error_key = key
	result.leftovers = p_leftovers
	return result
