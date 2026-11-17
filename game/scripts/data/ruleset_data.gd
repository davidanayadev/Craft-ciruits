class_name RulesetData
extends Resource
## How a world reacts to a player's death (PMV.md §2.4, §4.5 hook 4). The
## reaction is read from these fields and never from the id, so a new mode is
## another .tres and not another branch.

## snake_case and stable forever: the World file stores it (architecture §8).
@export var id: StringName
## Every inventory stack falls where the player died.
@export var drops_inventory: bool = false
@export var keeps_xp: bool = false
## Applied by spec 014, which creates the equipment slots.
@export var keeps_core: bool = false
## Battery after reappearing, as a fraction of the maximum: 0 < ratio <= 1.
@export var respawn_battery_ratio: float = 0.0


## Empty when valid; one message per problem.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if id.is_empty():
		problems.append("has no id")
	if respawn_battery_ratio <= 0.0 or respawn_battery_ratio > 1.0:
		problems.append("respawn_battery_ratio %f is outside (0, 1]" % respawn_battery_ratio)
	return problems
