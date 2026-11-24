class_name ChassisLevelSystem
extends RefCounted
## Chassis level of a total XP (spec 014, ACTION_PLAN 2.7): pure, with the
## ChassisLevelData table by parameter, so it is testable with hand-made tables
## and the number of levels comes from the table (R-014-01).


## Highest level whose total-XP threshold is <= total_xp (accumulated XP,
## R-014-03); above the last threshold, the last level (R-014-04). Negative XP,
## a null table or one whose validate() is not empty → push_error and
## ChassisLevelData.FIRST_LEVEL (R-014-05).
static func level_for_xp(total_xp: int, levels: ChassisLevelData) -> int:
	if not _is_valid_input(total_xp, levels):
		return ChassisLevelData.FIRST_LEVEL
	var level: int = ChassisLevelData.FIRST_LEVEL
	for index: int in levels.xp_required.size():
		if levels.xp_required[index] > total_xp:
			break
		level = ChassisLevelData.FIRST_LEVEL + index
	return level


## XP to add to total_xp to reach the threshold of the next level; 0 at the
## last level. Same invalid inputs as level_for_xp() → push_error and 0 (R-014-20).
static func xp_to_next_level(total_xp: int, levels: ChassisLevelData) -> int:
	if not _is_valid_input(total_xp, levels):
		return 0
	var level: int = level_for_xp(total_xp, levels)
	if level >= levels.get_level_count():
		return 0
	return levels.get_xp_required(level + 1) - total_xp


static func _is_valid_input(total_xp: int, levels: ChassisLevelData) -> bool:
	if total_xp < 0:
		push_error("ChassisLevelSystem: negative total XP (%d)." % total_xp)
		return false
	if levels == null:
		push_error("ChassisLevelSystem: no chassis level table.")
		return false
	var problems: PackedStringArray = levels.validate()
	if not problems.is_empty():
		push_error("ChassisLevelSystem: invalid chassis level table: %s." % problems)
		return false
	return true
