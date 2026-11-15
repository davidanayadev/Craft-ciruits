class_name LootSystem
extends RefCounted
## Loot rolls (spec 004, BALANCE.md §2.1). Pure rules: the table and the RNG
## come by parameter, so the caller decides the seed.


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


static func _describe(table: LootTableData) -> String:
	if not table.resource_path.is_empty():
		return table.resource_path
	return "'%s'" % table.resource_name
