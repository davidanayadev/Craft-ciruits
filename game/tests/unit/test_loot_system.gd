extends GutTest
## LootSystem (spec 004): rolls a loot table once with a given RNG, every
## quantity inside its range and items rolled as 0 left out (R-004-23), and
## rejects tables with broken entries (R-004-26).
## Hand-made tables: the real ones are checked in test_data_catalog.gd.

const ROLL_SEED := 2026
const ROLLS := 1000


func _new_item(id: StringName) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = id
	return item


func _new_entry(item: ItemData, min_quantity: int, max_quantity: int) -> LootEntryData:
	var entry: LootEntryData = LootEntryData.new()
	entry.item = item
	entry.min_quantity = min_quantity
	entry.max_quantity = max_quantity
	return entry


func _new_table(entries: Array[LootEntryData]) -> LootTableData:
	var table: LootTableData = LootTableData.new()
	table.entries = entries
	return table


func _new_rng(rng_seed: int = ROLL_SEED) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func test_r_004_23_quantities_in_range() -> void:
	var common: ItemData = _new_item(&"common")
	var rare: ItemData = _new_item(&"rare")
	var table: LootTableData = _new_table([_new_entry(common, 2, 5), _new_entry(rare, 0, 2)])
	var rng: RandomNumberGenerator = _new_rng()
	var seen: Dictionary[ItemData, Dictionary] = {common: {}, rare: {}}
	var out_of_range: int = 0
	for i: int in ROLLS:
		for stack: ItemStack in LootSystem.roll(table, rng):
			seen[stack.item][stack.quantity] = true
			var low: int = 2 if stack.item == common else 1
			var high: int = 5 if stack.item == common else 2
			if stack.quantity < low or stack.quantity > high:
				out_of_range += 1
	assert_eq(out_of_range, 0, "every rolled quantity is inside its range")
	assert_eq(seen[common].size(), 4, "2, 3, 4 and 5 all come up: both ends are included")
	assert_eq(seen[rare].size(), 2, "1 and 2 come up (0 is left out)")


func test_r_004_23_stacks_follow_table_order() -> void:
	var first: ItemData = _new_item(&"first")
	var second: ItemData = _new_item(&"second")
	var table: LootTableData = _new_table([_new_entry(first, 3, 3), _new_entry(second, 1, 1)])
	var stacks: Array[ItemStack] = LootSystem.roll(table, _new_rng())
	assert_eq(stacks.size(), 2, "one stack per entry")
	if stacks.size() != 2:
		return
	assert_same(stacks[0].item, first, "first entry first")
	assert_eq(stacks[0].quantity, 3)
	assert_same(stacks[1].item, second, "second entry second")
	assert_eq(stacks[1].quantity, 1)


func test_r_004_23_zero_left_out() -> void:
	var nothing: ItemData = _new_item(&"nothing")
	var something: ItemData = _new_item(&"something")
	var table: LootTableData = _new_table([_new_entry(nothing, 0, 0), _new_entry(something, 1, 1)])
	var stacks: Array[ItemStack] = LootSystem.roll(table, _new_rng())
	assert_eq(stacks.size(), 1, "the item rolled as 0 is not delivered")
	if stacks.size() == 1:
		assert_same(stacks[0].item, something)


func test_r_004_23_same_seed_same_loot() -> void:
	var table: LootTableData = _new_table(
		[_new_entry(_new_item(&"a"), 0, 9), _new_entry(_new_item(&"b"), 0, 9)]
	)
	var first: Array[int] = _quantities(LootSystem.roll(table, _new_rng(7)))
	var second: Array[int] = _quantities(LootSystem.roll(table, _new_rng(7)))
	assert_eq(first, second, "the same RNG seed gives the same contents")


func test_r_004_26_valid_table_has_no_problems() -> void:
	var table: LootTableData = _new_table([_new_entry(_new_item(&"a"), 0, 2)])
	assert_eq(LootSystem.validate(table).size(), 0)


func test_r_004_26_validate_rejects_bad_entries() -> void:
	var item: ItemData = _new_item(&"a")
	var no_item: LootTableData = _new_table([_new_entry(null, 1, 2)])
	assert_eq(LootSystem.validate(no_item).size(), 1, "entry without item")
	var negative: LootTableData = _new_table([_new_entry(item, -1, 2)])
	assert_eq(LootSystem.validate(negative).size(), 1, "negative quantity")
	var inverted: LootTableData = _new_table([_new_entry(item, 3, 2)])
	assert_eq(LootSystem.validate(inverted).size(), 1, "minimum above maximum")
	var empty_slot: LootTableData = _new_table([null])
	assert_eq(LootSystem.validate(empty_slot).size(), 1, "empty entry slot")
	var several: LootTableData = _new_table([_new_entry(null, 1, 2), _new_entry(item, 3, 2)])
	assert_eq(LootSystem.validate(several).size(), 2, "one message per problem")


func test_r_004_26_roll_invalid_reports_error() -> void:
	var table: LootTableData = _new_table([_new_entry(_new_item(&"a"), 3, 2)])
	table.resource_name = "broken_table"
	var stacks: Array[ItemStack] = LootSystem.roll(table, _new_rng())
	assert_eq(stacks.size(), 0, "an invalid table gives no loot")
	assert_push_error("broken_table")


func test_r_004_26_roll_without_table_reports_error() -> void:
	var stacks: Array[ItemStack] = LootSystem.roll(null, _new_rng())
	assert_eq(stacks.size(), 0, "no table, no loot")
	assert_push_error("LootSystem")


func _quantities(stacks: Array[ItemStack]) -> Array[int]:
	var quantities: Array[int] = []
	for stack: ItemStack in stacks:
		quantities.append(stack.quantity)
	return quantities
