class_name ExperienceComponent
extends Node
## Total XP and chassis level of one player (specs 007 and 014): per-player
## state (constitution P4), never in an autoload. The level is derived from the
## total with ChassisLevelSystem and the table its entity gives it
## (set_level_table); it is never saved, only the total is (R-014-15).
## Only this owner knows whether the total changed by a gain (add_xp: may emit
## the fact level_up) or by a load (from_save_data: state signals only), which
## is why the level lives here (plan 014 D1). The level never goes down: XP that
## goes down keeps it and reports an error (R-014-11).
## It reads no autoload: the catalog, the table and the uids come by
## parameter, so it is testable with hand-made data.

signal xp_changed(total: int)
## State: the chassis level now (R-014-10); on a level-up and on every valid load.
signal level_changed(level: int)
## Fact: the level went up (R-014-07); once per gain, with the final level,
## after level_changed. Never on load (R-014-17).
signal level_up(new_level: int)

## Save contract (spec 010, architecture §10.2).
const SAVE_KEY := &"experience"
const _TOTAL_KEY := "total"

var _total: int = 0
var _level: int = ChassisLevelData.FIRST_LEVEL
var _levels: ChassisLevelData = null


## The level table; the level is recomputed from the current total, emitting
## level_changed only if it went up and never level_up. It never goes down: the
## inventory cannot lose slots (R-014-11). Robot calls it in _ready().
func set_level_table(levels: ChassisLevelData) -> void:
	_levels = levels
	var level: int = maxi(_level, _computed_level())
	if level == _level:
		return
	_level = level
	level_changed.emit(_level)


## ChassisLevelData.FIRST_LEVEL until a table and XP raise it.
func get_level() -> int:
	return _level


## Adds amount XP: xp_changed, then, if the level went up, level_changed and
## level_up with the final level (plan 014 D4). Negative → push_error, no
## change. Zero changes nothing.
func add_xp(amount: int) -> void:
	if amount < 0:
		push_error("ExperienceComponent '%s': add_xp() got a negative amount (%d)." % [name, amount])
		return
	if amount == 0:
		return
	_total += amount
	xp_changed.emit(_total)
	var level: int = _computed_level()
	if level <= _level:
		return
	_level = level
	level_changed.emit(_level)
	level_up.emit(_level)


## Adds the XP of a killed enemy when the killer is this component's owner.
## An enemy id that is not in the catalog → push_error, no change.
func reward_kill(
	enemy_id: StringName, killer_uid: String, owner_uid: String, catalog: DataCatalog
) -> void:
	if killer_uid.is_empty() or killer_uid != owner_uid:
		return
	if catalog == null or not catalog.has_enemy(enemy_id):
		push_error(
			"ExperienceComponent '%s': no XP for the kill of '%s', it is not in the catalog."
			% [name, enemy_id]
		)
		return
	add_xp(catalog.get_enemy(enemy_id).xp_reward)


## Total back to 0, for a ruleset that does not keep the XP on death (spec
## 008). xp_changed only if it changed; the level stays, with push_error (R-014-11).
func reset() -> void:
	if _total == 0:
		return
	_report_lower_total(0)
	_total = 0
	xp_changed.emit(_total)


func get_total() -> int:
	return _total


func get_save_key() -> StringName:
	return SAVE_KEY


func to_save_data() -> Dictionary:
	return {_TOTAL_KEY: _total}


## Every valid load emits xp_changed and level_changed once each, also when
## nothing changed, and never level_up (R-014-17, plan 014 D7). A lower total
## keeps the level, with push_error (R-014-11). Missing, fractional or
## negative → push_error, no change and no signal.
func from_save_data(data: Dictionary) -> void:
	var value: Variant = data.get(_TOTAL_KEY)
	var total: int = SaveFields.to_int(value, -1)
	if total < 0:
		push_error("ExperienceComponent '%s': invalid saved total in %s; no change." % [name, data])
		return
	if total < _total:
		_report_lower_total(total)
	else:
		_level = maxi(_level, ChassisLevelSystem.level_for_xp(total, _levels))
	_total = total
	xp_changed.emit(_total)
	level_changed.emit(_level)


## Without a table, or with an invalid one, ChassisLevelSystem reports it and
## the level stays at the first one (plan 014 D9).
func _computed_level() -> int:
	return ChassisLevelSystem.level_for_xp(_total, _levels)


func _report_lower_total(total: int) -> void:
	push_error(
		"ExperienceComponent '%s': the XP goes down from %d to %d; level %d and its slots stay."
		% [name, _total, total, _level]
	)
