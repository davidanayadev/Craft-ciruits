class_name ConsumableRules
extends RefCounted
## Whether a consumable can be used (spec 012, plan D4): pure, over a copy of
## the slots and the battery's numbers, so it is testable without a scene. The
## use goes by slot, never by item id, so no script names `portable_battery`.

const ERR_BATTERY_FULL := &"ERR_BATTERY_FULL"
const ERR_NO_PORTABLE_BATTERY := &"ERR_NO_PORTABLE_BATTERY"
## No slot chosen: the request names none, or there is no consumable.
const NO_SLOT := -1


## ERR_NO_PORTABLE_BATTERY when slot_index holds no ConsumableData (NO_SLOT
## included); else ERR_BATTERY_FULL when current >= maximum; else success
## (R-012-24). An index out of range → push_error, ERR_INVALID_REQUEST.
static func check_use(slots: Array[ItemStack], slot_index: int, current: float, maximum: float) -> ActionResult:
	if slot_index < NO_SLOT or slot_index >= slots.size():
		push_error("ConsumableRules: slot %d is out of range (%d slots)." % [slot_index, slots.size()])
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	if slot_index == NO_SLOT or not _holds_consumable(slots[slot_index]):
		return ActionResult.failure(ERR_NO_PORTABLE_BATTERY)
	if current >= maximum:
		return ActionResult.failure(ERR_BATTERY_FULL)
	return ActionResult.success()


## The first slot holding a ConsumableData, in slot order; NO_SLOT when none (D4).
static func first_consumable_slot(slots: Array[ItemStack]) -> int:
	for index: int in slots.size():
		if _holds_consumable(slots[index]):
			return index
	return NO_SLOT


static func _holds_consumable(stack: ItemStack) -> bool:
	return stack != null and stack.item is ConsumableData
