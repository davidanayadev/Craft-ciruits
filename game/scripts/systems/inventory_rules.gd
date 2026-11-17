class_name InventoryRules
extends RefCounted
## Pure stacking rules (spec 005, architecture §9.3). Slots are an
## Array[ItemStack] where null is an empty slot; the caller owns it and these
## functions change it in place. Items are told apart by id.


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
static func add(slots: Array[ItemStack], item: ItemData, quantity: int) -> int:
	if item == null:
		push_error("InventoryRules: add() got no item.")
		return quantity
	if quantity <= 0 or item.stack_max < 1:
		push_error(
			"InventoryRules: cannot add %d of '%s' (stack_max %d)."
			% [quantity, item.id, item.stack_max]
		)
		return quantity
	var remaining: int = _fill_partial_stacks(slots, item, quantity)
	return _fill_empty_slots(slots, item, remaining)


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


## Whether quantity can leave slot_index: an occupied slot and 1..its quantity.
static func can_split(slots: Array[ItemStack], slot_index: int, quantity: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size() or slots[slot_index] == null:
		return false
	return quantity >= 1 and quantity <= slots[slot_index].quantity


## Takes quantity out of slot_index and returns it as a new stack; the slot
## keeps the rest, or becomes null when nothing is left. A request can_split()
## rejects → null and no change.
static func split(slots: Array[ItemStack], slot_index: int, quantity: int) -> ItemStack:
	if not can_split(slots, slot_index, quantity):
		return null
	var stack: ItemStack = slots[slot_index]
	stack.quantity -= quantity
	if stack.quantity == 0:
		slots[slot_index] = null
	return ItemStack.new(stack.item, quantity)


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


static func _fill_empty_slots(slots: Array[ItemStack], item: ItemData, quantity: int) -> int:
	var remaining: int = quantity
	for i: int in slots.size():
		if remaining == 0:
			break
		if slots[i] != null:
			continue
		var moved: int = mini(remaining, item.stack_max)
		slots[i] = ItemStack.new(item, moved)
		remaining -= moved
	return remaining
