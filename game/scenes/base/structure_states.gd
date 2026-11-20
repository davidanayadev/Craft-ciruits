class_name StructureStates
extends Node
## The state of the placed structures that have one (spec 012, plan D5): an
## InventoryComponent per chest and a WindGeneratorComponent per generator,
## kept by uid in a dictionary (never looked up by node name). Child of
## BaseStructures under World, so it outlives the base scene; BaseStructures
## saves it inside its own part (plan D6). None of its nodes is in the
## persistent group.

const CHESTS_KEY := "chests"
const GENERATORS_KEY := "generators"

## uid → InventoryComponent or WindGeneratorComponent.
var _states: Dictionary[String, Node] = {}


## Nothing for a structure with no state (the charging station). A uid that
## already has a state → push_error, no change.
func create_for(uid: String, structure: StructureData, now_unix: int) -> void:
	if _states.has(uid):
		push_error("StructureStates '%s': '%s' already has a state." % [name, uid])
		return
	var chest: StorageChestData = structure as StorageChestData
	var generator: WindGeneratorData = structure as WindGeneratorData
	if chest != null:
		_add_state(uid, _new_chest_contents(chest))
	elif generator != null:
		var component: WindGeneratorComponent = WindGeneratorComponent.new()
		component.start(generator, now_unix)
		_add_state(uid, component)


## null when uid is not a chest.
func get_chest_contents(uid: String) -> InventoryComponent:
	return _states.get(uid) as InventoryComponent


## null when uid is not a generator.
func get_generator(uid: String) -> WindGeneratorComponent:
	return _states.get(uid) as WindGeneratorComponent


## {chests: {uid: InventoryComponent.to_save_data()}, generators: {uid: {...}}},
## JSON types only (R-012-39). Capacities and generator numbers are data, never
## saved (R-012-40).
func to_data() -> Dictionary:
	var chests: Dictionary = {}
	var generators: Dictionary = {}
	for uid: String in _states:
		var contents: InventoryComponent = get_chest_contents(uid)
		if contents != null:
			chests[uid] = contents.to_save_data()
		else:
			generators[uid] = get_generator(uid).to_save_data()
	return {CHESTS_KEY: chests, GENERATORS_KEY: generators}


## Drops every state and makes one per placed uid that needs it, then fills it
## from data. An entry that is not valid, whose uid is not placed or is placed as
## another kind → push_error and skipped: its structure starts new (R-012-42).
## Missing keys → every state new (R-012-43). Only state signals (R-012-41).
func load_data(data: Dictionary, placed: Dictionary[String, StructureData], now_unix: int) -> void:
	clear()
	for uid: String in placed:
		create_for(uid, placed[uid], now_unix)
	_load_chests(_part(data, CHESTS_KEY))
	_load_generators(_part(data, GENERATORS_KEY))


## Every state leaves the tree at once, then is freed (plan D5).
func clear() -> void:
	for state: Node in _states.values():
		remove_child(state)
		state.queue_free()
	_states.clear()


func _add_state(uid: String, state: Node) -> void:
	state.name = uid
	add_child(state)
	_states[uid] = state


func _new_chest_contents(chest: StorageChestData) -> InventoryComponent:
	var contents: InventoryComponent = InventoryComponent.new()
	if chest.container == null:
		push_error("StructureStates '%s': chest '%s' has no container data." % [name, chest.id])
		return contents
	contents.set_slot_count(chest.container.slot_count)
	return contents


## The saved part under key; missing → {} (an older World); not a dictionary → reported.
func _part(data: Dictionary, key: String) -> Dictionary:
	var part: Variant = data.get(key, {})
	if part is Dictionary:
		return part
	push_error("StructureStates '%s': saved '%s' is not a dictionary; ignored." % [name, key])
	return {}


func _load_chests(entries: Dictionary) -> void:
	for key: Variant in entries:
		var uid: String = str(key)
		var contents: InventoryComponent = get_chest_contents(uid)
		var entry: Variant = entries[key]
		var fields: Dictionary = entry if entry is Dictionary else {}
		if contents == null or InventoryComponent.get_saved_slot_count(fields) < 0:
			push_error("StructureStates '%s': saved chest '%s' %s is skipped." % [name, uid, entry])
			continue
		contents.from_save_data(fields)


func _load_generators(entries: Dictionary) -> void:
	for key: Variant in entries:
		var uid: String = str(key)
		var generator: WindGeneratorComponent = get_generator(uid)
		var entry: Variant = entries[key]
		var fields: Dictionary = entry if entry is Dictionary else {}
		if generator == null or not generator.load_save_data(fields):
			push_error("StructureStates '%s': saved generator '%s' %s is skipped." % [name, uid, entry])
