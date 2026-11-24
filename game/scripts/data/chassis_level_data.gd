class_name ChassisLevelData
extends Resource
## Chassis level table (BALANCE.md §6.1): the only place where the XP
## thresholds, the inventory slots per level and the number of levels live
## (R-014-01). ChassisLevelSystem turns a total XP into a level with it.

const FIRST_LEVEL := 1

## Total (accumulated) XP to reach each level, level 1 first (BALANCE §6.1).
@export var xp_required: Array[int] = []
## Inventory slots at each level, level 1 first (BALANCE §6.1).
@export var inventory_slots: Array[int] = []


func get_level_count() -> int:
	return inventory_slots.size()


## Level outside 1..get_level_count() → push_error and 0.
func get_inventory_slots(level: int) -> int:
	return _value_at(inventory_slots, level)


## Total XP to reach level; outside 1..get_level_count() → push_error and 0.
func get_xp_required(level: int) -> int:
	return _value_at(xp_required, level)


## Empty when valid: same size, at least one level, first threshold 0 (R-014-02),
## thresholds strictly increasing, slots never decreasing (plan 014 D8).
func validate() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if inventory_slots.is_empty():
		problems.append("there are no levels")
	if xp_required.size() != inventory_slots.size():
		problems.append("xp_required and inventory_slots differ in size")
	if not xp_required.is_empty() and xp_required[0] != 0:
		problems.append("the first level does not start at 0 XP")
	if not _is_increasing(xp_required):
		problems.append("xp_required does not increase with the level")
	if not _is_non_decreasing(inventory_slots):
		problems.append("inventory_slots decreases with the level")
	return problems


func _value_at(values: Array[int], level: int) -> int:
	var index: int = level - FIRST_LEVEL
	if index < 0 or index >= values.size():
		push_error(
			"ChassisLevelData: level %d is outside %d..%d."
			% [level, FIRST_LEVEL, get_level_count()]
		)
		return 0
	return values[index]


static func _is_increasing(values: Array[int]) -> bool:
	for i: int in range(1, values.size()):
		if values[i] <= values[i - 1]:
			return false
	return true


static func _is_non_decreasing(values: Array[int]) -> bool:
	for i: int in range(1, values.size()):
		if values[i] < values[i - 1]:
			return false
	return true
