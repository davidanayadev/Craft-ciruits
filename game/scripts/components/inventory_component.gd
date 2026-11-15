class_name InventoryComponent
extends Node
## Owner and only writer of a set of item slots (spec 005, architecture §9.3):
## the robot's inventory, the contents of a loot box and, later, chests. It
## validates each request, delegates the stacking to InventoryRules and reports
## the outcome as an ActionResult. Per-entity state (constitution P4).
##
## add, add_stacks and take_from store copies: a stack the caller passes in is
## never kept, so nobody can change the slots through it.

## Once per operation that changed slots or slot count; never without a change.
signal inventory_changed
## Something offered to this inventory did not fit (part or all). Not emitted for rejected requests.
signal overflowed(leftovers: Array[ItemStack])

const ERR_INVALID_REQUEST := &"ERR_INVALID_REQUEST"
const ERR_NOT_ENOUGH_ITEMS := &"ERR_NOT_ENOUGH_ITEMS"
const MSG_INVENTORY_FULL := &"MSG_INVENTORY_FULL"

## Validates ids; DataRegistry's catalog when left null at _ready().
var catalog: DataCatalog

var _slots: Array[ItemStack] = []


func _ready() -> void:
	if catalog == null:
		catalog = DataRegistry.get_catalog()


func get_slot_count() -> int:
	return _slots.size()


## Grows to count slots, keeping contents. count < current → push_error,
## failure ERR_INVALID_REQUEST and no change.
func set_slot_count(count: int) -> ActionResult:
	if count < _slots.size():
		push_error(
			"InventoryComponent '%s': cannot shrink from %d to %d slots."
			% [name, _slots.size(), count]
		)
		return ActionResult.failure(ERR_INVALID_REQUEST)
	if count > _slots.size():
		_slots.resize(count)
		inventory_changed.emit()
	return ActionResult.success()


## Copies, slot order, null for empty: the caller can never change the inventory through them.
func get_slots() -> Array[ItemStack]:
	return _copies_of(_slots)


func is_empty() -> bool:
	for stack: ItemStack in _slots:
		if stack != null:
			return false
	return true


## Unknown id → push_error and 0.
func count(item_id: StringName) -> int:
	if not _knows(item_id):
		push_error("InventoryComponent '%s': count() of unknown item '%s'." % [name, item_id])
		return 0
	return InventoryRules.count(_slots, item_id)


func has(item_id: StringName, quantity: int) -> bool:
	return count(item_id) >= quantity


## quantity <= 0 or unknown id → push_error naming the item, ERR_INVALID_REQUEST, no change.
## Not everything fits → adds what fits, MSG_INVENTORY_FULL with the leftover.
func add(item_id: StringName, quantity: int) -> InventoryAddResult:
	if not _is_valid_request(item_id, quantity, "add"):
		return InventoryAddResult.not_added(ERR_INVALID_REQUEST, [])
	var stacks: Array[ItemStack] = [ItemStack.new(catalog.get_item(item_id), quantity)]
	return _add_valid_stacks(stacks)


## Same rules for several stacks as one operation: validates all first, one inventory_changed.
func add_stacks(stacks: Array[ItemStack]) -> InventoryAddResult:
	for stack: ItemStack in stacks:
		if stack == null or stack.item == null:
			push_error("InventoryComponent '%s': add_stacks() got an empty stack." % name)
			return InventoryAddResult.not_added(ERR_INVALID_REQUEST, _copies_of(stacks))
		if not _is_valid_request(stack.item.id, stack.quantity, "add"):
			return InventoryAddResult.not_added(ERR_INVALID_REQUEST, _copies_of(stacks))
	return _add_valid_stacks(stacks)


## All or nothing: more than held → ERR_NOT_ENOUGH_ITEMS and no change.
func remove(item_id: StringName, quantity: int) -> ActionResult:
	if not _is_valid_request(item_id, quantity, "remove"):
		return ActionResult.failure(ERR_INVALID_REQUEST)
	if InventoryRules.count(_slots, item_id) < quantity:
		return ActionResult.failure(ERR_NOT_ENOUGH_ITEMS)
	InventoryRules.remove(_slots, item_id, quantity)
	inventory_changed.emit()
	return ActionResult.success()


## amounts[i] leaves slot i; size must equal the slot count and each amount must be
## within 0..that slot's quantity, otherwise push_error, ERR_INVALID_REQUEST and no
## change. One signal.
func remove_from_slots(amounts: Array[int]) -> ActionResult:
	if not _are_valid_amounts(amounts):
		push_error(
			"InventoryComponent '%s': remove_from_slots() got amounts that do not match its slots: %s."
			% [name, amounts]
		)
		return ActionResult.failure(ERR_INVALID_REQUEST)
	var changed: bool = false
	for i: int in amounts.size():
		if amounts[i] == 0:
			continue
		changed = true
		_slots[i].quantity -= amounts[i]
		if _slots[i].quantity == 0:
			_slots[i] = null
	if changed:
		inventory_changed.emit()
	return ActionResult.success()


## Moves the stacks in source's slot_indices into this inventory, in that order, as
## much as fits; source loses exactly what entered (R-005-15). No source, source ==
## self, an index out of range or repeated, or an item this catalog does not know →
## push_error, ERR_INVALID_REQUEST and no change. Nothing fits → MSG_INVENTORY_FULL,
## no change, overflowed on this inventory.
## Both inventories are already written when the source emits inventory_changed, and
## this one emits after it: a listener of either signal sees the two sides consistent.
func take_from(source: InventoryComponent, slot_indices: Array[int]) -> InventoryAddResult:
	if not _is_valid_take(source, slot_indices):
		push_error(
			"InventoryComponent '%s': invalid take_from() request for slots %s."
			% [name, slot_indices]
		)
		return InventoryAddResult.not_added(ERR_INVALID_REQUEST, [])
	var amounts: Array[int] = []
	amounts.resize(source.get_slot_count())
	amounts.fill(0)
	var leftovers: Array[ItemStack] = _take_what_fits(source.get_slots(), slot_indices, amounts)
	if amounts.any(_is_positive):
		if not source.remove_from_slots(amounts).ok:
			push_error(
				"InventoryComponent '%s': '%s' did not give what was taken from it."
				% [name, source.name]
			)
		inventory_changed.emit()
	return _report_leftovers(leftovers)


## First direct child of node that is an InventoryComponent; null when none.
static func find_in(node: Node) -> InventoryComponent:
	for child: Node in node.get_children():
		var inventory: InventoryComponent = child as InventoryComponent
		if inventory != null:
			return inventory
	return null


func _add_valid_stacks(stacks: Array[ItemStack]) -> InventoryAddResult:
	var leftovers: Array[ItemStack] = []
	var changed: bool = false
	for stack: ItemStack in stacks:
		var item: ItemData = catalog.get_item(stack.item.id)
		var leftover: int = InventoryRules.add(_slots, item, stack.quantity)
		changed = changed or leftover < stack.quantity
		if leftover > 0:
			leftovers.append(ItemStack.new(item, leftover))
	if changed:
		inventory_changed.emit()
	return _report_leftovers(leftovers)


## Adds the offered stacks of slot_indices to these slots, as much as fits. Writes in
## amounts how much of each slot entered and returns what did not.
func _take_what_fits(
	offered: Array[ItemStack], slot_indices: Array[int], amounts: Array[int]
) -> Array[ItemStack]:
	var leftovers: Array[ItemStack] = []
	for index: int in slot_indices:
		var stack: ItemStack = offered[index]
		if stack == null:
			continue
		var item: ItemData = catalog.get_item(stack.item.id)
		var leftover: int = InventoryRules.add(_slots, item, stack.quantity)
		amounts[index] = stack.quantity - leftover
		if leftover > 0:
			leftovers.append(ItemStack.new(item, leftover))
	return leftovers


func _report_leftovers(leftovers: Array[ItemStack]) -> InventoryAddResult:
	if leftovers.is_empty():
		return InventoryAddResult.added_all()
	overflowed.emit(_copies_of(leftovers))
	return InventoryAddResult.not_added(MSG_INVENTORY_FULL, leftovers)


func _knows(item_id: StringName) -> bool:
	return catalog != null and catalog.has_item(item_id)


func _is_valid_request(item_id: StringName, quantity: int, action: String) -> bool:
	if _knows(item_id) and quantity > 0:
		return true
	push_error(
		"InventoryComponent '%s': cannot %s %d of item '%s' (unknown item or quantity <= 0)."
		% [name, action, quantity, item_id]
	)
	return false


func _are_valid_amounts(amounts: Array[int]) -> bool:
	if amounts.size() != _slots.size():
		return false
	for i: int in amounts.size():
		var held: int = 0 if _slots[i] == null else _slots[i].quantity
		if amounts[i] < 0 or amounts[i] > held:
			return false
	return true


func _is_valid_take(source: InventoryComponent, slot_indices: Array[int]) -> bool:
	if source == null or source == self:
		return false
	var offered: Array[ItemStack] = source.get_slots()
	var seen: Dictionary[int, bool] = {}
	for index: int in slot_indices:
		if index < 0 or index >= offered.size() or seen.has(index):
			return false
		seen[index] = true
		if offered[index] != null and not _knows(offered[index].item.id):
			return false
	return true


static func _is_positive(amount: int) -> bool:
	return amount > 0


static func _copies_of(stacks: Array[ItemStack]) -> Array[ItemStack]:
	var copies: Array[ItemStack] = []
	for stack: ItemStack in stacks:
		copies.append(null if stack == null else stack.copy())
	return copies
