extends GutTest
## ItemStack (spec 010, R-010-23): besides item and quantity it carries an
## optional durability (-1 = does not apply) and a uid ("" = none), and copy()
## keeps all four fields without sharing anything with the original.


func _item() -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = &"scrap"
	item.stack_max = 10
	return item


func test_r_010_23_defaults_do_not_apply() -> void:
	var stack: ItemStack = ItemStack.new(_item(), 3)
	assert_eq(stack.durability, -1, "durability -1 means it does not apply")
	assert_eq(stack.uid, "", "no uid by default")
	assert_eq(stack.quantity, 3, "constructor unchanged: quantity")


func test_r_010_23_copy_keeps_all_fields() -> void:
	var item: ItemData = _item()
	var stack: ItemStack = ItemStack.new(item, 4)
	stack.durability = 40
	stack.uid = "abc123"
	var copied: ItemStack = stack.copy()
	assert_same(copied.item, item, "same item resource")
	assert_eq(copied.quantity, 4, "quantity kept")
	assert_eq(copied.durability, 40, "durability kept")
	assert_eq(copied.uid, "abc123", "uid kept")


func test_r_010_23_copy_shares_nothing() -> void:
	var stack: ItemStack = ItemStack.new(_item(), 4)
	stack.durability = 40
	stack.uid = "abc123"
	var copied: ItemStack = stack.copy()
	assert_not_same(copied, stack, "a new object")
	copied.quantity = 1
	copied.durability = 5
	copied.uid = "other"
	assert_eq(stack.quantity, 4, "original quantity untouched")
	assert_eq(stack.durability, 40, "original durability untouched")
	assert_eq(stack.uid, "abc123", "original uid untouched")
