class_name LootSystem
extends RefCounted
## Loot rolls (spec 004, BALANCE.md §2.1) and the piece an enemy may drop (spec
## 016, BALANCE §3.2). Pure rules: the table and the RNG come by parameter, so
## the caller decides the seed.


## Empty when valid; one message per problem (empty slot, no item, negative
## quantity, minimum above maximum).
static func validate(table: LootTableData) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for i: int in table.entries.size():
		var entry: LootEntryData = table.entries[i]
		if entry == null:
			problems.append("entries[%d] is empty" % i)
			continue
		if entry.item == null:
			problems.append("entries[%d] has no item" % i)
		if entry.min_quantity < 0 or entry.max_quantity < 0:
			problems.append("entries[%d] has a negative quantity" % i)
		elif entry.min_quantity > entry.max_quantity:
			problems.append("entries[%d] has its minimum above its maximum" % i)
	return problems


## One rng.randi_range(min, max) per entry, in table order (uniform, both ends
## included); quantities of 0 are left out. That order is a contract with
## saved worlds: the same seed must keep giving the same loot.
## Invalid table → push_error naming the table and no loot.
static func roll(table: LootTableData, rng: RandomNumberGenerator) -> Array[ItemStack]:
	var stacks: Array[ItemStack] = []
	if table == null:
		push_error("LootSystem: roll() got no loot table.")
		return stacks
	var problems: PackedStringArray = validate(table)
	if not problems.is_empty():
		push_error("LootSystem: invalid loot table %s: %s." % [_describe(table), problems])
		return stacks
	for entry: LootEntryData in table.entries:
		var quantity: int = rng.randi_range(entry.min_quantity, entry.max_quantity)
		if quantity > 0:
			stacks.append(ItemStack.new(entry.item, quantity))
	return stacks


## Empty when valid; one message per problem: chance outside 0..100 and, when
## chance > 0, durability outside 1..100, no pieces, an empty piece slot or a
## piece with durability_max < 1 (spec 016).
static func validate_piece_drop(drop: PieceDropData) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if drop.chance_percent < 0 or drop.chance_percent > CraftingSystem.PERCENT:
		problems.append("chance_percent %d is outside 0..100" % drop.chance_percent)
	if drop.chance_percent <= 0:
		return problems
	if drop.durability_percent < 1 or drop.durability_percent > CraftingSystem.PERCENT:
		problems.append("durability_percent %d is outside 1..100" % drop.durability_percent)
	if drop.pieces.is_empty():
		problems.append("there are no pieces to drop")
	for i: int in drop.pieces.size():
		var piece: PieceData = drop.pieces[i]
		if piece == null:
			problems.append("pieces[%d] is empty" % i)
		elif piece.durability_max < 1:
			problems.append("pieces[%d] has no durability" % i)
	return problems


## One rng.randi_range(1, CraftingSystem.PERCENT); at or below chance_percent,
## one rng.randi_range(0, pieces.size() - 1) picks the piece. A new unique stack
## (CraftingSystem.create_result) with durability_percent of its
## durability_max, at least 1; null when no piece drops. That order is a
## contract with saved worlds. Invalid drop → push_error naming it, null and no
## RNG call.
static func roll_piece(drop: PieceDropData, rng: RandomNumberGenerator) -> ItemStack:
	if drop == null:
		push_error("LootSystem: roll_piece() got no piece drop.")
		return null
	var problems: PackedStringArray = validate_piece_drop(drop)
	if not problems.is_empty():
		push_error("LootSystem: invalid piece drop %s: %s." % [_describe(drop), problems])
		return null
	if rng.randi_range(1, CraftingSystem.PERCENT) > drop.chance_percent:
		return null
	var piece: PieceData = drop.pieces[rng.randi_range(0, drop.pieces.size() - 1)]
	var stack: ItemStack = CraftingSystem.create_result(piece)
	# Whole points, rounded down on purpose; never 0, which is a broken piece.
	@warning_ignore("integer_division")
	var durability: int = piece.durability_max * drop.durability_percent / CraftingSystem.PERCENT
	stack.durability = clampi(durability, 1, piece.durability_max)
	return stack


## roll(table) when table is not null, then roll_piece(piece_drop) when it is
## not null, with the same rng; the piece goes last. Both null → empty. Without
## a piece drop it makes exactly the RNG calls of roll(), so the drop of a
## zombie stays what it was before pieces could drop (R-016-22).
static func roll_enemy_drop(
	table: LootTableData, piece_drop: PieceDropData, rng: RandomNumberGenerator
) -> Array[ItemStack]:
	var stacks: Array[ItemStack] = []
	if table != null:
		stacks = roll(table, rng)
	if piece_drop != null:
		var piece: ItemStack = roll_piece(piece_drop, rng)
		if piece != null:
			stacks.append(piece)
	return stacks


static func _describe(resource: Resource) -> String:
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return "'%s'" % resource.resource_name
