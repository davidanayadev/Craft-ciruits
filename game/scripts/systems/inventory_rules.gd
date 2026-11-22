class_name InventoryRules
extends RefCounted
## Pure stacking rules (spec 005, architecture §9.3). Slots are an
## Array[ItemStack] where null is an empty slot; the caller owns it and these
## functions change it in place. Items are told apart by id.

## The target holds the same item with no room left (spec 012, R-012-29).
const ERR_SLOT_FULL := &"ERR_SLOT_FULL"
## A swap asked for only part of the origin stack (R-012-33).
const ERR_PARTIAL_SWAP := &"ERR_PARTIAL_SWAP"
## Nothing of a transfer fits on the other side (R-012-30).
const ERR_NO_ROOM := &"ERR_NO_ROOM"


## Room for item: free room in its stacks below stack_max plus empty slots × stack_max.
static func space_for(slots: Array[ItemStack], item: ItemData) -> int:
	if item == null or item.stack_max < 1:
		return 0
	var space: int = 0
	for stack: ItemStack in slots:
		if stack == null:
			space += item.stack_max
		elif stack.item.id == item.id:
			space += maxi(item.stack_max - stack.quantity, 0)
	return space


## Fills that item's stacks below stack_max in slot order, then empty slots in
## slot order. Returns the quantity that did not fit. quantity <= 0 or
## stack_max < 1 → push_error, no change, returns quantity.
## Same as add_stack(slots, ItemStack.new(item, quantity)).
static func add(slots: Array[ItemStack], item: ItemData, quantity: int) -> int:
	if item == null:
		push_error("InventoryRules: add() got no item.")
		return quantity
	return add_stack(slots, ItemStack.new(item, quantity))


## Like add() for one stack: the new slots it fills copy its durability and
## uid (spec 011, R-011-09); the stack itself is never kept. A piece never
## merges because its stack_max is 1 (R-011-08). Returns what did not fit.
static func add_stack(slots: Array[ItemStack], stack: ItemStack) -> int:
	if stack == null or stack.item == null:
		push_error("InventoryRules: add_stack() got no stack or no item.")
		return 0 if stack == null else stack.quantity
	var item: ItemData = stack.item
	if stack.quantity <= 0 or item.stack_max < 1:
		push_error(
			"InventoryRules: cannot add %d of '%s' (stack_max %d)."
			% [stack.quantity, item.id, item.stack_max]
		)
		return stack.quantity
	var remaining: int = _fill_partial_stacks(slots, item, stack.quantity)
	return _fill_empty_slots(slots, stack, remaining)


## True for a stack whose item is not a PieceData: materials keep the rules
## of spec 005. A piece needs quantity 1, durability in 1..durability_max and a
## non-empty uid (plan 011 D1, R-011-11). The caller passes the stack with the
## catalog's item. null → false.
static func is_valid_stack(stack: ItemStack) -> bool:
	if stack == null or stack.item == null:
		return false
	var piece: PieceData = stack.item as PieceData
	if piece == null:
		return true
	return (
		stack.quantity == 1 and stack.durability >= 1 and stack.durability <= piece.durability_max
		and not stack.uid.is_empty()
	)


## Slot holding uid; -1 when none or uid is empty.
static func index_of_uid(slots: Array[ItemStack], uid: String) -> int:
	if uid.is_empty():
		return -1
	for i: int in slots.size():
		if slots[i] != null and slots[i].uid == uid:
			return i
	return -1


## Slots holding a stack (R-013-12).
static func count_used_slots(slots: Array[ItemStack]) -> int:
	var used: int = 0
	for stack: ItemStack in slots:
		if stack != null:
			used += 1
	return used


## Sum of item_id over every slot.
static func count(slots: Array[ItemStack], item_id: StringName) -> int:
	var total: int = 0
	for stack: ItemStack in slots:
		if stack != null and stack.item.id == item_id:
			total += stack.quantity
	return total


## Removes exactly quantity from the last slot towards the first; slots that
## reach 0 become null. Caller checks count() first; quantity above it →
## push_error and no change.
static func remove(slots: Array[ItemStack], item_id: StringName, quantity: int) -> void:
	var held: int = count(slots, item_id)
	if quantity > held:
		push_error(
			"InventoryRules: cannot remove %d of '%s', only %d held." % [quantity, item_id, held]
		)
		return
	var remaining: int = quantity
	for i: int in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			return
		var stack: ItemStack = slots[i]
		if stack == null or stack.item.id != item_id:
			continue
		var taken: int = mini(remaining, stack.quantity)
		stack.quantity -= taken
		remaining -= taken
		if stack.quantity == 0:
			slots[i] = null


## Whether every amount (item id → quantity) is held at once (spec 009).
static func can_remove_many(slots: Array[ItemStack], amounts: Dictionary[StringName, int]) -> bool:
	for item_id: StringName in amounts:
		if count(slots, item_id) < amounts[item_id]:
			return false
	return true


## Removes every amount, each one like remove(). All or nothing: the caller
## checks can_remove_many() first; amounts it rejects → push_error, no change.
static func remove_many(slots: Array[ItemStack], amounts: Dictionary[StringName, int]) -> void:
	if not can_remove_many(slots, amounts):
		push_error("InventoryRules: cannot remove %s, not everything is held." % amounts)
		return
	for item_id: StringName in amounts:
		remove(slots, item_id, amounts[item_id])


## Whether quantity can leave slot_index: an occupied slot and 1..its quantity.
static func can_split(slots: Array[ItemStack], slot_index: int, quantity: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size() or slots[slot_index] == null:
		return false
	return quantity >= 1 and quantity <= slots[slot_index].quantity


## Takes quantity out of slot_index and returns it as a new stack with the
## slot's durability and uid; the slot keeps the rest, or becomes null when
## nothing is left. A request can_split() rejects → null and no change.
static func split(slots: Array[ItemStack], slot_index: int, quantity: int) -> ItemStack:
	if not can_split(slots, slot_index, quantity):
		return null
	var stack: ItemStack = slots[slot_index]
	stack.quantity -= quantity
	if stack.quantity == 0:
		slots[slot_index] = null
	var taken: ItemStack = stack.copy()
	taken.quantity = quantity
	return taken


## Same id and neither has a uid: two pieces never merge (R-012-34). null on either side → false.
static func can_merge(a: ItemStack, b: ItemStack) -> bool:
	if a == null or b == null or a.item == null or b.item == null:
		return false
	return a.item.id == b.item.id and a.uid.is_empty() and b.uid.is_empty()


## quantity of from[from_index] to to[to_index]; from and to may be the same array
## (R-012-29). Empty target → placed; can_merge → added up to stack_max, the rest
## stays in the origin (no room → ERR_SLOT_FULL); otherwise the whole stack swaps,
## a part → ERR_PARTIAL_SWAP (R-012-33). Stacks keep durability and uid (R-012-34).
## Index out of range, empty origin, quantity outside 1..its stack or the same slot
## → push_error, ERR_INVALID_REQUEST. Any refusal changes nothing.
static func move_to_slot(
	from: Array[ItemStack], from_index: int, to: Array[ItemStack], to_index: int, quantity: int
) -> ActionResult:
	if not _is_valid_move(from, from_index, to, to_index, quantity):
		push_error(
			"InventoryRules: invalid move of %d from slot %d to slot %d." % [quantity, from_index, to_index]
		)
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var origin: ItemStack = from[from_index]
	var target: ItemStack = to[to_index]
	if target == null:
		to[to_index] = split(from, from_index, quantity)
		return ActionResult.success()
	if can_merge(origin, target):
		return _merge_into(from, from_index, target, quantity)
	if quantity != origin.quantity:
		return ActionResult.failure(ERR_PARTIAL_SWAP)
	from[from_index] = target
	to[to_index] = origin
	return ActionResult.success()


## quantity of from[from_index] into to as add_stack() does (same item first,
## then empty slots), as much as fits; the rest stays in the origin (R-012-30).
## Nothing fits → ERR_NO_ROOM, no change. from and to being the same array, an
## empty origin or a quantity outside 1..its stack → push_error, ERR_INVALID_REQUEST.
static func transfer(
	from: Array[ItemStack], from_index: int, to: Array[ItemStack], quantity: int
) -> ActionResult:
	if is_same(from, to) or not can_split(from, from_index, quantity):
		push_error(
			"InventoryRules: invalid transfer of %d from slot %d." % [quantity, from_index]
		)
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var room: int = space_for(to, from[from_index].item)
	if room <= 0:
		return ActionResult.failure(ERR_NO_ROOM)
	var leftover: int = add_stack(to, split(from, from_index, mini(quantity, room)))
	assert(leftover == 0, "space_for() guarantees room for what leaves")
	return ActionResult.success()


static func _is_valid_move(
	from: Array[ItemStack], from_index: int, to: Array[ItemStack], to_index: int, quantity: int
) -> bool:
	if to_index < 0 or to_index >= to.size():
		return false
	if is_same(from, to) and from_index == to_index:
		return false
	return can_split(from, from_index, quantity)


## Adds as much of the origin as target has room for; the rest stays.
static func _merge_into(
	from: Array[ItemStack], from_index: int, target: ItemStack, quantity: int
) -> ActionResult:
	var moved: int = mini(quantity, target.item.stack_max - target.quantity)
	if moved <= 0:
		return ActionResult.failure(ERR_SLOT_FULL)
	split(from, from_index, moved)
	target.quantity += moved
	return ActionResult.success()


static func _fill_partial_stacks(slots: Array[ItemStack], item: ItemData, quantity: int) -> int:
	var remaining: int = quantity
	for stack: ItemStack in slots:
		if remaining == 0:
			break
		if stack == null or stack.item.id != item.id or stack.quantity >= item.stack_max:
			continue
		var moved: int = mini(remaining, item.stack_max - stack.quantity)
		stack.quantity += moved
		remaining -= moved
	return remaining


## Each new slot is a copy of template with its own quantity.
static func _fill_empty_slots(slots: Array[ItemStack], template: ItemStack, quantity: int) -> int:
	var remaining: int = quantity
	for i: int in slots.size():
		if remaining == 0:
			break
		if slots[i] != null:
			continue
		var moved: int = mini(remaining, template.item.stack_max)
		var filled: ItemStack = template.copy()
		filled.quantity = moved
		slots[i] = filled
		remaining -= moved
	return remaining
