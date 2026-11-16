class_name ExperienceComponent
extends Node
## Total XP of one player (spec 007): per-player state (constitution P4), never
## in an autoload. It only accumulates until spec 013 applies the chassis
## levels through xp_changed.
## It reads no autoload: the catalog and the uids come by parameter, so it is
## testable with hand-made catalogs.

signal xp_changed(total: int)

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


func get_total() -> int:
	return _total
