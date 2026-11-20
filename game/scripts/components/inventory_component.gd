class_name InventoryComponent
extends Node
## Owner and only writer of a set of item slots (spec 005, architecture §9.3):
## the robot's inventory, the contents of a loot box or of a dropped item and,
## later, chests. It
## validates each request, delegates the stacking to InventoryRules and reports
## the outcome as an ActionResult. Per-entity state (constitution P4).
##
## add, add_stacks and take_from store copies: a stack the caller passes in is
## never kept, so nobody can change the slots through it.
##
## Pieces (spec 011) are unique: every path that moves a stack keeps its
## durability and uid (R-011-09), and a piece only enters with a valid uid and
## durability (InventoryRules.is_valid_stack, plan 011 D1). It also crafts and
## repairs, the decision being CraftingSystem's (architecture §3).

## Once per operation that changed slots or slot count; never without a change.
signal inventory_changed
## Something offered to this inventory did not fit (part or all). Not emitted for rejected requests.
signal overflowed(leftovers: Array[ItemStack])

const ERR_INVALID_REQUEST := ActionResult.ERR_INVALID_REQUEST
const ERR_NOT_ENOUGH_ITEMS := &"ERR_NOT_ENOUGH_ITEMS"
const MSG_INVENTORY_FULL := &"MSG_INVENTORY_FULL"
## Save contract (spec 010, architecture §10.2).
const SAVE_KEY := &"inventory"
const _SLOTS_KEY := "slots"

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


## Empties it and leaves it with count slots, for a container that is reused
## (a pooled dropped item, spec 008). What it held is gone: move it out first.
## count < 0 → push_error, ERR_INVALID_REQUEST and no change.
func clear(count: int) -> ActionResult:
	if count < 0:
		push_error("InventoryComponent '%s': cannot clear to %d slots." % [name, count])
		return ActionResult.failure(ERR_INVALID_REQUEST)
	if is_empty() and _slots.size() == count:
		return ActionResult.success()
	_slots.clear()
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


## quantity <= 0, unknown id or a piece (it needs a uid, R-011-07) → push_error
## naming the item, ERR_INVALID_REQUEST, no change.
## Not everything fits → adds what fits, MSG_INVENTORY_FULL with the leftover.
func add(item_id: StringName, quantity: int) -> InventoryAddResult:
	if not _is_valid_request(item_id, quantity, "add"):
		return InventoryAddResult.not_added(ERR_INVALID_REQUEST, [])
	if catalog.get_item(item_id) is PieceData:
		push_error(
			"InventoryComponent '%s': add() cannot create the piece '%s'; it needs a uid."
			% [name, item_id]
		)
		return InventoryAddResult.not_added(ERR_INVALID_REQUEST, [])
	var stacks: Array[ItemStack] = [ItemStack.new(catalog.get_item(item_id), quantity)]
	return _add_valid_stacks(stacks)


## Same rules for several stacks as one operation: validates all first, one
## inventory_changed. A piece stack that is not valid with the catalog's item
## (InventoryRules.is_valid_stack) is rejected like an unknown id (R-011-07).
func add_stacks(stacks: Array[ItemStack]) -> InventoryAddResult:
	for stack: ItemStack in stacks:
		if stack == null or stack.item == null:
			push_error("InventoryComponent '%s': add_stacks() got an empty stack." % name)
			return InventoryAddResult.not_added(ERR_INVALID_REQUEST, _copies_of(stacks))
		if not _is_valid_request(stack.item.id, stack.quantity, "add"):
			return InventoryAddResult.not_added(ERR_INVALID_REQUEST, _copies_of(stacks))
		if not InventoryRules.is_valid_stack(_with_catalog_item(stack, stack.quantity)):
			push_error(
				"InventoryComponent '%s': add_stacks() got an invalid piece '%s' (quantity %d, durability %d, uid '%s')."
				% [name, stack.item.id, stack.quantity, stack.durability, stack.uid]
			)
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


## Several items at once, all or nothing (paying a recipe, spec 009): every
## id known and every quantity > 0, otherwise push_error, ERR_INVALID_REQUEST
## and no change; any amount not held → ERR_NOT_ENOUGH_ITEMS and no change.
## One inventory_changed.
func remove_many(amounts: Dictionary[StringName, int]) -> ActionResult:
	for item_id: StringName in amounts:
		if not _knows(item_id) or amounts[item_id] <= 0:
			push_error(
				"InventoryComponent '%s': cannot remove %s (unknown item or quantity <= 0)."
				% [name, amounts]
			)
			return ActionResult.failure(ERR_INVALID_REQUEST)
	if not InventoryRules.can_remove_many(_slots, amounts):
		return ActionResult.failure(ERR_NOT_ENOUGH_ITEMS)
	if amounts.is_empty():
		return ActionResult.success()
	InventoryRules.remove_many(_slots, amounts)
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
	_settle_take(source, amounts)
	return _report_leftovers(leftovers)


## take_from() for a part of one slot: moves quantity of source's slot_index
## into this inventory, as much as fits; source loses exactly what entered and
## keeps the rest (spec 008). Same invalid requests as take_from(), plus an
## empty slot or a quantity outside 1..its stack (InventoryRules.can_split).
func take_amount_from(
	source: InventoryComponent, slot_index: int, quantity: int
) -> InventoryAddResult:
	var leaving: ItemStack = null
	if source != null and source != self:
		leaving = InventoryRules.split(source.get_slots(), slot_index, quantity)
	if leaving == null or not _knows(leaving.item.id):
		push_error(
			"InventoryComponent '%s': invalid take_amount_from() request for %d of slot %d."
			% [name, quantity, slot_index]
		)
		return InventoryAddResult.not_added(ERR_INVALID_REQUEST, [])
	var leftover: int = InventoryRules.add_stack(_slots, _with_catalog_item(leaving, leaving.quantity))
	var amounts: Array[int] = []
	amounts.resize(source.get_slot_count())
	amounts.fill(0)
	amounts[slot_index] = leaving.quantity - leftover
	_settle_take(source, amounts)
	var leftovers: Array[ItemStack] = []
	if leftover > 0:
		leftovers.append(_with_catalog_item(leaving, leftover))
	return _report_leftovers(leftovers)


## InventoryRules.move_to_slot between these slots and target's (target == self
## allowed, spec 012). The rule runs on copies and both sides are written before
## any signal: one inventory_changed per inventory that changed, this one first.
## No target, or an item the other side's catalog does not know → push_error,
## ERR_INVALID_REQUEST, no change. Writing target's slots is a declared deviation
## from architecture §3 rule 3 (plan 012 D12): the same class validates both sides.
func move_to_slot(
	from_index: int, target: InventoryComponent, to_index: int, quantity: int
) -> ActionResult:
	if not _is_valid_counterpart(target, from_index, to_index, "move_to_slot"):
		return ActionResult.failure(ERR_INVALID_REQUEST)
	var mine: Array[ItemStack] = _copies_of(_slots)
	var theirs: Array[ItemStack] = mine if target == self else _copies_of(target._slots)
	var result: ActionResult = InventoryRules.move_to_slot(mine, from_index, theirs, to_index, quantity)
	if result.ok:
		_commit_with(target, mine, theirs)
	return result


## InventoryRules.transfer into target (never self, spec 012, R-012-30). Same
## signals and invalid requests as move_to_slot().
func transfer_to(target: InventoryComponent, from_index: int, quantity: int) -> ActionResult:
	if target == self:
		push_error("InventoryComponent '%s': transfer_to() into itself." % name)
		return ActionResult.failure(ERR_INVALID_REQUEST)
	if not _is_valid_counterpart(target, from_index, -1, "transfer_to"):
		return ActionResult.failure(ERR_INVALID_REQUEST)
	var mine: Array[ItemStack] = _copies_of(_slots)
	var theirs: Array[ItemStack] = _copies_of(target._slots)
	var result: ActionResult = InventoryRules.transfer(mine, from_index, theirs, quantity)
	if result.ok:
		_commit_with(target, mine, theirs)
	return result


## Pays the recipe and adds its result (CraftingSystem.create_result) in one
## step, one inventory_changed (R-011-13, R-011-15). No recipe, no result_item,
## a result_structure, or a result this catalog does not know → push_error,
## ERR_INVALID_REQUEST, no change. A CraftingSystem.check_craft refusal → its
## key, no change (R-011-14).
func craft(recipe: RecipeData) -> ActionResult:
	if (
		recipe == null or recipe.result_item == null or recipe.result_structure != null
		or not _knows(recipe.result_item.id)
	):
		push_error("InventoryComponent '%s': craft() needs an item recipe of this catalog." % name)
		return ActionResult.failure(ERR_INVALID_REQUEST)
	var checked: ActionResult = CraftingSystem.check_craft(_slots, recipe)
	if not checked.ok:
		return checked
	InventoryRules.remove_many(_slots, CraftingSystem.cost_of(recipe))
	var made: ItemStack = CraftingSystem.create_result(catalog.get_item(recipe.result_item.id))
	var leftover: int = InventoryRules.add_stack(_slots, made)
	assert(leftover == 0, "check_craft guarantees a slot for the result once paid")
	inventory_changed.emit()
	return ActionResult.success()


## Pays CraftingSystem.repair_cost and sets the piece piece_uid to its maximum
## durability, keeping its uid and slot, in one step (R-011-19). Unknown uid →
## push_error and ERR_PIECE_NOT_FOUND; any other CraftingSystem.check_repair
## refusal → its key; no change either way (R-011-20). costs null →
## push_error, ERR_INVALID_REQUEST.
func repair(piece_uid: String, costs: RepairCostData) -> ActionResult:
	if costs == null:
		push_error("InventoryComponent '%s': repair() got no repair costs." % name)
		return ActionResult.failure(ERR_INVALID_REQUEST)
	var checked: ActionResult = CraftingSystem.check_repair(_slots, piece_uid, costs)
	if not checked.ok:
		if checked.error_key == CraftingSystem.ERR_PIECE_NOT_FOUND:
			push_error("InventoryComponent '%s': no piece with uid '%s' to repair." % [name, piece_uid])
		return checked
	var piece: ItemStack = _slots[InventoryRules.index_of_uid(_slots, piece_uid)]
	InventoryRules.remove_many(_slots, CraftingSystem.repair_cost(piece, costs))
	piece.durability = (piece.item as PieceData).durability_max
	inventory_changed.emit()
	return ActionResult.success()


func get_save_key() -> StringName:
	return SAVE_KEY


## Every slot in order, null when empty; the slot count is not saved, it
## comes from the chassis level on load (R-010-24).
func to_save_data() -> Dictionary:
	var slots: Array = []
	for stack: ItemStack in _slots:
		slots.append(null if stack == null else {
			"item_id": String(stack.item.id),
			"quantity": stack.quantity,
			"durability": stack.durability,
			"uid": stack.uid,
		})
	return {_SLOTS_KEY: slots}


## How many slots saved data lists; -1 when it has no slot list. A container
## sized by its contents (an opened box) sizes itself with it before loading.
static func get_saved_slot_count(data: Dictionary) -> int:
	var saved: Variant = data.get(_SLOTS_KEY)
	return (saved as Array).size() if saved is Array else -1


## Replaces every slot, keeping the slot count; one inventory_changed and
## never overflowed (R-010-09). A bad slot (unknown item, quantity outside
## 1..stack_max, wrong field, an invalid piece, R-011-11) → push_error and it
## stays empty, the rest loads
## (R-010-11); saved slots beyond the count are lost, reported. No slot list
## → push_error, no change.
func from_save_data(data: Dictionary) -> void:
	var saved: Variant = data.get(_SLOTS_KEY)
	if not saved is Array:
		push_error("InventoryComponent '%s': no saved slot list in %s; no change." % [name, data])
		return
	var entries: Array = saved
	if entries.size() > _slots.size():
		push_error(
			"InventoryComponent '%s': %d saved slots for %d slots; the extra ones are lost."
			% [name, entries.size(), _slots.size()]
		)
	var loaded: Array[ItemStack] = []
	loaded.resize(_slots.size())
	for index: int in mini(entries.size(), _slots.size()):
		loaded[index] = _stack_from_save(entries[index], index)
	_slots = loaded
	inventory_changed.emit()


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
		var leftover: int = InventoryRules.add_stack(_slots, _with_catalog_item(stack, stack.quantity))
		changed = changed or leftover < stack.quantity
		if leftover > 0:
			leftovers.append(_with_catalog_item(stack, leftover))
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
		var leftover: int = InventoryRules.add_stack(_slots, _with_catalog_item(stack, stack.quantity))
		amounts[index] = stack.quantity - leftover
		if leftover > 0:
			leftovers.append(_with_catalog_item(stack, leftover))
	return leftovers


## Takes from source what already entered here (amounts per source slot) and
## reports the change of this inventory. Nothing entered → nothing happens.
func _settle_take(source: InventoryComponent, amounts: Array[int]) -> void:
	if not amounts.any(_is_positive):
		return
	if not source.remove_from_slots(amounts).ok:
		push_error(
			"InventoryComponent '%s': '%s' did not give what was taken from it."
			% [name, source.name]
		)
	inventory_changed.emit()


## A target exists and each side knows the item that may enter it: the stack in
## from_index goes to target, the one in to_index (if any) may come back here.
func _is_valid_counterpart(
	target: InventoryComponent, from_index: int, to_index: int, action: String
) -> bool:
	if target == null:
		push_error("InventoryComponent '%s': %s() got no target." % [name, action])
		return false
	var leaving: ItemStack = _slots[from_index] if from_index >= 0 and from_index < _slots.size() else null
	var coming: ItemStack = null
	if to_index >= 0 and to_index < target._slots.size():
		coming = target._slots[to_index]
	if (leaving != null and not target._knows(leaving.item.id)) or (coming != null and not _knows(coming.item.id)):
		push_error("InventoryComponent '%s': %s() moves an item the other side does not know." % [name, action])
		return false
	return true


## Writes the slots a move computed, each with its own catalog's items, then
## signals this inventory and, when it is another one, target.
func _commit_with(target: InventoryComponent, mine: Array[ItemStack], theirs: Array[ItemStack]) -> void:
	_slots = _normalized(mine)
	if target != self:
		target._slots = target._normalized(theirs)
	inventory_changed.emit()
	if target != self:
		target.inventory_changed.emit()


func _normalized(stacks: Array[ItemStack]) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for stack: ItemStack in stacks:
		result.append(null if stack == null else _with_catalog_item(stack, stack.quantity))
	return result


## Null for an empty slot or a bad entry (reported).
func _stack_from_save(entry: Variant, index: int) -> ItemStack:
	if entry == null:
		return null
	var fields: Dictionary = entry if entry is Dictionary else {}
	var item_id: StringName = StringName(str(fields.get("item_id", "")))
	var quantity: int = SaveFields.to_int(fields.get("quantity"), 0)
	var durability: Variant = fields.get("durability", -1)
	var stack_uid: Variant = fields.get("uid", "")
	var valid: bool = (
		_knows(item_id) and quantity >= 1 and quantity <= catalog.get_item(item_id).stack_max
		and SaveFields.is_whole_number(durability) and stack_uid is String
	)
	var stack: ItemStack = null
	if valid:
		stack = ItemStack.new(catalog.get_item(item_id), quantity)
		stack.durability = SaveFields.to_int(durability, -1)
		stack.uid = stack_uid
	if stack == null or not InventoryRules.is_valid_stack(stack):
		push_error("InventoryComponent '%s': saved slot %d %s is lost." % [name, index, entry])
		return null
	return stack


## A copy of stack with quantity and this catalog's item, so a foreign
## ItemData with a known id is stored as the catalog's one (R-005-11).
func _with_catalog_item(stack: ItemStack, quantity: int) -> ItemStack:
	var copy: ItemStack = stack.copy()
	copy.item = catalog.get_item(stack.item.id)
	copy.quantity = quantity
	return copy


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
