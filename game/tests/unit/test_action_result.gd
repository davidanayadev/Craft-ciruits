extends GutTest
## ActionResult (R-005-14, architecture §9.2): the one result type of every
## action that can fail, and InventoryAddResult, which adds what did not fit.

const ERROR_KEY := &"ERR_SAMPLE"


func _new_stack(quantity: int) -> ItemStack:
	var item: ItemData = ItemData.new()
	item.id = &"sample"
	return ItemStack.new(item, quantity)


func test_r_005_14_success_and_failure() -> void:
	var success: ActionResult = ActionResult.success()
	assert_true(success.ok, "success is ok")
	assert_eq(success.error_key, &"", "success carries no error key")
	var failure: ActionResult = ActionResult.failure(ERROR_KEY)
	assert_false(failure.ok, "failure is not ok")
	assert_eq(failure.error_key, ERROR_KEY, "failure carries its translation key")


func test_r_005_14_added_all_is_a_successful_action_result() -> void:
	var result: InventoryAddResult = InventoryAddResult.added_all()
	assert_true(result is ActionResult, "the UI can read it as an ActionResult")
	assert_true(result.ok, "everything entered")
	assert_eq(result.error_key, &"", "no error key")
	assert_eq(result.leftovers.size(), 0, "nothing left over")


func test_r_005_14_not_added_carries_key_and_leftovers() -> void:
	var leftovers: Array[ItemStack] = [_new_stack(3)]
	var result: InventoryAddResult = InventoryAddResult.not_added(ERROR_KEY, leftovers)
	assert_false(result.ok, "something did not enter")
	assert_eq(result.error_key, ERROR_KEY, "it carries its translation key")
	assert_eq(result.leftovers.size(), 1, "one stack left over")
	assert_same(result.leftovers[0], leftovers[0], "the stack that did not fit")
