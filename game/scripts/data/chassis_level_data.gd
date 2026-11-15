class_name ChassisLevelData
extends Resource
## Chassis level table (BALANCE.md §6.1): the only place where the XP
## thresholds and the inventory slots per level live. Spec 005 reads the slots
## of the first level; ACTION_PLAN 2.7 applies the rest.

const FIRST_LEVEL := 1

## Total XP to reach each level, level 1 first (BALANCE §6.1). ACTION_PLAN 2.7 uses it.
@export var xp_required: Array[int] = []
## Inventory slots at each level, level 1 first (BALANCE §6.1).
@export var inventory_slots: Array[int] = []


func get_level_count() -> int:
	return inventory_slots.size()


## Level outside 1..get_level_count() → push_error and 0.
func get_inventory_slots(level: int) -> int:
	var index: int = level - FIRST_LEVEL
	if index < 0 or index >= inventory_slots.size():
		push_error(
			"ChassisLevelData: level %d is outside %d..%d."
			% [level, FIRST_LEVEL, get_level_count()]
		)
		return 0
	return inventory_slots[index]


## Empty when valid: same size in both arrays, at least one level, values increasing.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if inventory_slots.is_empty():
		problems.append("there are no levels")
	if xp_required.size() != inventory_slots.size():
		problems.append("xp_required and inventory_slots differ in size")
	if not _is_increasing(xp_required):
		problems.append("xp_required does not increase with the level")
	if not _is_increasing(inventory_slots):
		problems.append("inventory_slots does not increase with the level")
	return problems


static func _is_increasing(values: Array[int]) -> bool:
	for i: int in range(1, values.size()):
		if values[i] <= values[i - 1]:
			return false
	return true
