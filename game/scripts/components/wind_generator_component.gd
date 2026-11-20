class_name WindGeneratorComponent
extends Node
## State of one placed wind generator (spec 012): the batteries it holds and the
## start of the period in progress. The rules are WindGeneratorRules'; the time
## always comes by parameter (R-012-19). Owned by StructureStates under World,
## so it outlives the base scene (plan D5). It is not in the persistent group:
## BaseStructures saves it inside its own part.

## State signal: what it holds or its reference time changed.
signal generator_changed

const MSG_GENERATOR_EMPTY := &"MSG_GENERATOR_EMPTY"
const _STORED_KEY := "stored"
const _SINCE_KEY := "since_unix"

var config: WindGeneratorData

var _stored: int = 0
var _since_unix: int = 0


## Built at now_unix: 0 stored, its first period starts now (R-012-18).
func start(p_config: WindGeneratorData, now_unix: int) -> void:
	config = p_config
	_stored = 0
	_since_unix = now_unix


## Batteries held at now_unix. Reading settles nothing (plan D7).
func get_stored(now_unix: int) -> int:
	return WindGeneratorRules.settle(_stored, _since_unix, now_unix, config).stored


## Seconds until the next battery; -1 when full.
func get_seconds_to_next(now_unix: int) -> int:
	return WindGeneratorRules.seconds_to_next(_stored, _since_unix, now_unix, config)


## Settles and moves what fits into inventory as config.battery_item (plan D8);
## the rest stays. ok when any moved, with one generator_changed. Nothing held
## → MSG_GENERATOR_EMPTY; nothing fits → MSG_INVENTORY_FULL (the inventory
## reports overflowed); no change either way. No inventory → push_error.
func collect(inventory: InventoryComponent, now_unix: int) -> ActionResult:
	if inventory == null or config == null or config.battery_item == null:
		push_error("WindGeneratorComponent '%s': collect() got no inventory or has no battery item." % name)
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var settled: WindGeneratorRules.Settled = WindGeneratorRules.settle(_stored, _since_unix, now_unix, config)
	if settled.stored == 0:
		return ActionResult.failure(MSG_GENERATOR_EMPTY)
	var added: InventoryAddResult = inventory.add(config.battery_item.id, settled.stored)
	if not added.ok and added.error_key != InventoryComponent.MSG_INVENTORY_FULL:
		return added
	var moved: int = settled.stored - _total(added.leftovers)
	if moved == 0:
		return ActionResult.failure(InventoryComponent.MSG_INVENTORY_FULL)
	var after: WindGeneratorRules.Settled = WindGeneratorRules.after_taking(settled, moved, now_unix, config)
	_stored = after.stored
	_since_unix = after.since_unix
	generator_changed.emit()
	return ActionResult.success()


## {stored, since_unix}, JSON types only (R-012-39).
func to_save_data() -> Dictionary:
	return {_STORED_KEY: _stored, _SINCE_KEY: _since_unix}


## false and no change for a bad entry: stored outside 0..max_stored or a time
## that is not a whole number; StructureStates reports it (R-012-42). A valid
## one emits generator_changed, never a fact (R-012-41).
func load_save_data(data: Dictionary) -> bool:
	var stored: Variant = data.get(_STORED_KEY)
	var since: Variant = data.get(_SINCE_KEY)
	if config == null or not SaveFields.is_whole_number(stored) or not SaveFields.is_whole_number(since):
		return false
	var count: int = SaveFields.to_int(stored, -1)
	if count < 0 or count > config.max_stored:
		return false
	_stored = count
	_since_unix = SaveFields.to_int(since, 0)
	generator_changed.emit()
	return true


static func _total(stacks: Array[ItemStack]) -> int:
	var total: int = 0
	for stack: ItemStack in stacks:
		total += stack.quantity
	return total
