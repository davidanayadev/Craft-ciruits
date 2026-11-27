extends GutTest
## LootSystem (spec 004): rolls a loot table once with a given RNG, every
## quantity inside its range and items rolled as 0 left out (R-004-23), and
## rejects tables with broken entries (R-004-26).
## Hand-made tables: the real ones are checked in test_data_catalog.gd.
## Spec 016: a piece drop rolls its chance and its piece with the same RNG,
## after the table, and the piece is a new unique stack (R-016-15 to R-016-17).

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


# --- Piece drops (spec 016) ---------------------------------------------------
## Seeds tried when a test needs every outcome to come up.
const PIECE_SEEDS := 300
## Rolls of the share test: fixed seeds 0..n-1, so it is deterministic.
const SHARE_ROLLS := 10000
## Band around 15 % that 10 000 fair rolls fall in (about ±5 standard deviations).
const SHARE_LOW := 0.13
const SHARE_HIGH := 0.17


func _new_piece(id: StringName, durability_max: int = 100) -> PieceData:
	var piece: PieceData = PieceData.new()
	piece.id = id
	piece.stack_max = 1
	piece.durability_max = durability_max
	return piece


func _new_piece_drop(
	chance_percent: int, pieces: Array[PieceData], durability_percent: int
) -> PieceDropData:
	var drop: PieceDropData = PieceDropData.new()
	drop.chance_percent = chance_percent
	drop.pieces = pieces
	drop.durability_percent = durability_percent
	return drop


func _three_pieces() -> Array[PieceData]:
	return [_new_piece(&"arms"), _new_piece(&"legs"), _new_piece(&"core")] as Array[PieceData]


func test_r_016_15_piece_only_at_or_below_chance() -> void:
	var never: PieceDropData = _new_piece_drop(0, _three_pieces(), 50)
	var always: PieceDropData = _new_piece_drop(100, _three_pieces(), 50)
	var never_dropped: int = 0
	var always_dropped: int = 0
	for roll_seed: int in PIECE_SEEDS:
		if LootSystem.roll_piece(never, _new_rng(roll_seed)) != null:
			never_dropped += 1
		if LootSystem.roll_piece(always, _new_rng(roll_seed)) != null:
			always_dropped += 1
	assert_eq(never_dropped, 0, "a 0 % chance never drops a piece")
	assert_eq(always_dropped, PIECE_SEEDS, "a 100 % chance always drops one")


func test_r_016_15_every_piece_can_drop() -> void:
	var drop: PieceDropData = _new_piece_drop(100, _three_pieces(), 50)
	var seen: Dictionary[StringName, int] = {}
	for roll_seed: int in PIECE_SEEDS:
		var stack: ItemStack = LootSystem.roll_piece(drop, _new_rng(roll_seed))
		if stack != null:
			seen[stack.item.id] = seen.get(stack.item.id, 0) + 1
	assert_eq(seen.size(), 3, "each of the three pieces comes up: %s" % seen)
	for id: StringName in seen:
		assert_between(seen[id], PIECE_SEEDS / 5, PIECE_SEEDS / 2, "%s: about a third" % id)


func test_r_016_15_share_close_to_chance() -> void:
	var drop: PieceDropData = _new_piece_drop(15, _three_pieces(), 50)
	var dropped: int = 0
	for roll_seed: int in SHARE_ROLLS:
		if LootSystem.roll_piece(drop, _new_rng(roll_seed)) != null:
			dropped += 1
	var share: float = float(dropped) / SHARE_ROLLS
	assert_between(share, SHARE_LOW, SHARE_HIGH, "a 15 %% chance gives %.3f" % share)


func test_r_016_15_one_rng_call_when_no_piece() -> void:
	var drop: PieceDropData = _new_piece_drop(0, _three_pieces(), 50)
	var rng: RandomNumberGenerator = _new_rng()
	var reference: RandomNumberGenerator = _new_rng()
	LootSystem.roll_piece(drop, rng)
	reference.randi_range(1, CraftingSystem.PERCENT)
	assert_eq(rng.state, reference.state, "only the chance is rolled; the piece is not picked")


func test_r_016_15_two_rng_calls_when_a_piece_drops() -> void:
	var drop: PieceDropData = _new_piece_drop(100, _three_pieces(), 50)
	var rng: RandomNumberGenerator = _new_rng()
	var reference: RandomNumberGenerator = _new_rng()
	LootSystem.roll_piece(drop, rng)
	reference.randi_range(1, CraftingSystem.PERCENT)
	reference.randi_range(0, 2)
	assert_eq(rng.state, reference.state, "the chance, then the piece: that order is a contract")


func test_r_016_15_validate_piece_drop() -> void:
	assert_eq(LootSystem.validate_piece_drop(PieceDropData.new()).size(), 0, "0 % and empty is valid")
	var valid: PieceDropData = _new_piece_drop(15, _three_pieces(), 50)
	assert_eq(LootSystem.validate_piece_drop(valid).size(), 0, "a real drop is valid")
	var chance_high: PieceDropData = _new_piece_drop(101, _three_pieces(), 50)
	assert_eq(LootSystem.validate_piece_drop(chance_high).size(), 1, "chance above 100")
	var chance_low: PieceDropData = _new_piece_drop(-1, _three_pieces(), 50)
	assert_eq(LootSystem.validate_piece_drop(chance_low).size(), 1, "negative chance")
	var no_pieces: PieceDropData = _new_piece_drop(15, [] as Array[PieceData], 50)
	assert_eq(LootSystem.validate_piece_drop(no_pieces).size(), 1, "no pieces to drop")
	var hole: PieceDropData = _new_piece_drop(15, [_new_piece(&"arms"), null] as Array[PieceData], 50)
	assert_eq(LootSystem.validate_piece_drop(hole).size(), 1, "an empty piece slot")
	var unbreakable: PieceDropData = _new_piece_drop(
		15, [_new_piece(&"arms", 0)] as Array[PieceData], 50
	)
	assert_eq(LootSystem.validate_piece_drop(unbreakable).size(), 1, "a piece with no durability")
	var zero_durability: PieceDropData = _new_piece_drop(15, _three_pieces(), 0)
	assert_eq(LootSystem.validate_piece_drop(zero_durability).size(), 1, "durability below 1 %")
	var over_durability: PieceDropData = _new_piece_drop(15, _three_pieces(), 101)
	assert_eq(LootSystem.validate_piece_drop(over_durability).size(), 1, "durability above 100 %")
	var several: PieceDropData = _new_piece_drop(15, [] as Array[PieceData], 0)
	assert_eq(LootSystem.validate_piece_drop(several).size(), 2, "one message per problem")


func test_r_016_15_invalid_piece_drop_reports_error() -> void:
	var broken: PieceDropData = _new_piece_drop(100, [] as Array[PieceData], 50)
	broken.resource_name = "broken_piece_drop"
	var rng: RandomNumberGenerator = _new_rng()
	var state: int = rng.state
	assert_null(LootSystem.roll_piece(broken, rng), "an invalid drop gives no piece")
	assert_push_error("broken_piece_drop")
	assert_eq(rng.state, state, "and rolls nothing")
	assert_null(LootSystem.roll_piece(null, _new_rng()), "no drop, no piece")
	assert_push_error("LootSystem")


func test_r_016_16_piece_is_unique_and_damaged() -> void:
	var drop: PieceDropData = _new_piece_drop(100, _three_pieces(), 50)
	var uids: Dictionary[String, bool] = {}
	var rolls: int = 20
	for roll_seed: int in rolls:
		var stack: ItemStack = LootSystem.roll_piece(drop, _new_rng(roll_seed))
		assert_not_null(stack, "seed %d drops a piece" % roll_seed)
		if stack == null:
			continue
		assert_eq(stack.quantity, 1, "one piece")
		assert_eq(stack.durability, 50, "half of its 100 points")
		assert_false(stack.uid.is_empty(), "with a uid")
		assert_true(InventoryRules.is_valid_stack(stack), "a valid unique stack")
		uids[stack.uid] = true
	assert_eq(uids.size(), rolls, "a new uid on every roll")
	var first: ItemStack = LootSystem.roll_piece(drop, _new_rng(0))
	var again: ItemStack = LootSystem.roll_piece(drop, _new_rng(0))
	assert_eq(again.item, first.item, "the same seed gives the same piece")
	assert_ne(again.uid, first.uid, "with another uid: the uid is identity, not gameplay")


func test_r_016_16_durability_never_zero() -> void:
	var small: Array[PieceData] = [_new_piece(&"tiny", 10)]
	var drop: PieceDropData = _new_piece_drop(100, small, 1)
	var stack: ItemStack = LootSystem.roll_piece(drop, _new_rng())
	assert_not_null(stack, "a piece drops")
	if stack != null:
		assert_eq(stack.durability, 1, "1 % of 10 rounds down to 0, kept at 1")
		assert_true(InventoryRules.is_valid_stack(stack), "still a valid stack")


func _describe_drop(stacks: Array[ItemStack]) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	for stack: ItemStack in stacks:
		parts.append("%s x%d d%d" % [stack.item.id, stack.quantity, stack.durability])
	return parts


func test_r_016_17_same_seed_same_drop() -> void:
	var table: LootTableData = _new_table([_new_entry(_new_item(&"scrap"), 2, 4)])
	var drop: PieceDropData = _new_piece_drop(50, _three_pieces(), 50)
	var with_piece: int = 0
	for roll_seed: int in 40:
		var first: Array[ItemStack] = LootSystem.roll_enemy_drop(table, drop, _new_rng(roll_seed))
		var second: Array[ItemStack] = LootSystem.roll_enemy_drop(table, drop, _new_rng(roll_seed))
		assert_eq(_describe_drop(first), _describe_drop(second), "seed %d: same drop" % roll_seed)
		if first.size() == 2:
			with_piece += 1
	assert_gt(with_piece, 0, "some seeds drop a piece, so the comparison covers it")


func test_r_016_17_piece_goes_last() -> void:
	var scrap: ItemData = _new_item(&"scrap")
	var table: LootTableData = _new_table([_new_entry(scrap, 1, 1)])
	var drop: PieceDropData = _new_piece_drop(100, _three_pieces(), 50)
	var stacks: Array[ItemStack] = LootSystem.roll_enemy_drop(table, drop, _new_rng())
	assert_eq(stacks.size(), 2, "the materials and the piece")
	if stacks.size() == 2:
		assert_same(stacks[0].item, scrap, "materials first")
		assert_true(stacks[1].item is PieceData, "the piece last")


func test_r_016_17_zombie_drop_sequence_unchanged() -> void:
	var table: LootTableData = _new_table(
		[_new_entry(_new_item(&"a"), 0, 9), _new_entry(_new_item(&"b"), 0, 9)]
	)
	for roll_seed: int in 20:
		var rng: RandomNumberGenerator = _new_rng(roll_seed)
		var reference: RandomNumberGenerator = _new_rng(roll_seed)
		var stacks: Array[ItemStack] = LootSystem.roll_enemy_drop(table, null, rng)
		var expected: Array[ItemStack] = LootSystem.roll(table, reference)
		assert_eq(_describe_drop(stacks), _describe_drop(expected), "seed %d: as roll()" % roll_seed)
		assert_eq(rng.state, reference.state, "seed %d: the same RNG calls" % roll_seed)


func test_r_016_17_no_table_and_no_piece_drop_nothing() -> void:
	var drop: PieceDropData = _new_piece_drop(100, _three_pieces(), 50)
	assert_eq(LootSystem.roll_enemy_drop(null, null, _new_rng()).size(), 0, "nothing to roll")
	var only_piece: Array[ItemStack] = LootSystem.roll_enemy_drop(null, drop, _new_rng())
	assert_eq(only_piece.size(), 1, "no table: only the piece")
	assert_push_error_count(0)


func test_r_016_14_materials_in_range_every_roll() -> void:
	var robot: EnemyData = load("res://resources/enemies/hostile_robot_basic.tres") as EnemyData
	if robot == null or robot.drop_table == null:
		fail_test("the hostile robot or its drop table is missing")
		return
	# The ranges of its own table (they match BALANCE §2.1 in test_enemy_resources.gd).
	var expected: Dictionary[StringName, Vector2i] = {}
	var combinations: int = 0
	for entry: LootEntryData in robot.drop_table.entries:
		expected[entry.item.id] = Vector2i(entry.min_quantity, entry.max_quantity)
		combinations += entry.max_quantity - entry.min_quantity + 1
	var wrong: int = 0
	var seen: Dictionary[String, bool] = {}
	for roll_seed: int in ROLLS:
		var stacks: Array[ItemStack] = LootSystem.roll(robot.drop_table, _new_rng(roll_seed))
		if stacks.size() != expected.size():
			wrong += 1
			continue
		for stack: ItemStack in stacks:
			var bounds: Vector2i = expected.get(stack.item.id, Vector2i(-1, -1))
			if stack.quantity < bounds.x or stack.quantity > bounds.y:
				wrong += 1
			seen["%s x%d" % [stack.item.id, stack.quantity]] = true
	assert_eq(wrong, 0, "always every material, each within its range (a minimum above 0)")
	assert_eq(seen.size(), combinations, "every quantity of every range comes up")
