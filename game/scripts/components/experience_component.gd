class_name ExperienceComponent
extends Node
## Total XP of one player (spec 007): per-player state (constitution P4), never
## in an autoload. It only accumulates until spec 013 applies the chassis
## levels through xp_changed.
## It reads no autoload: the catalog and the uids come by parameter, so it is
## testable with hand-made catalogs.

signal xp_changed(total: int)

## Save contract (spec 010, architecture §10.2).
const SAVE_KEY := &"experience"
const _TOTAL_KEY := "total"

var _total: int = 0


## Adds amount XP. Negative → push_error, no change. Zero changes nothing.
func add_xp(amount: int) -> void:
	if amount < 0:
		push_error("ExperienceComponent '%s': add_xp() got a negative amount (%d)." % [name, amount])
		return
	if amount == 0:
		return
	_total += amount
	xp_changed.emit(_total)


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
## 008). xp_changed only if it changed.
func reset() -> void:
	if _total == 0:
		return
	_total = 0
	xp_changed.emit(_total)


func get_total() -> int:
	return _total


func get_save_key() -> StringName:
	return SAVE_KEY


func to_save_data() -> Dictionary:
	return {_TOTAL_KEY: _total}


## xp_changed when the total changes; a level-up is never replayed on load
## (R-010-09, D15). Missing, fractional or negative → push_error, no change.
func from_save_data(data: Dictionary) -> void:
	var value: Variant = data.get(_TOTAL_KEY)
	var total: int = SaveFields.to_int(value, -1)
	if total < 0:
		push_error("ExperienceComponent '%s': invalid saved total in %s; no change." % [name, data])
		return
	if total == _total:
		return
	_total = total
	xp_changed.emit(_total)
