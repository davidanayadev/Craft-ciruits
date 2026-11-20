extends GutTest
## StructureStates (spec 012, plan D5, D6): one InventoryComponent per placed
## chest and one WindGeneratorComponent per placed generator, kept by uid, saved
## as two optional keys (R-012-26, R-012-39 to R-012-43). The structures are the
## real catalog resources; times are made-up numbers (no clock is read).

const CHEST_PATH := "res://resources/structures/storage_chest.tres"
const GENERATOR_PATH := "res://resources/structures/wind_generator.tres"
const STATION_PATH := "res://resources/structures/charging_station.tres"
const NOW := 5_000
const CHEST_UID := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const GENERATOR_UID := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const STATION_UID := "cccccccccccccccccccccccccccccccc"

var _states: StructureStates
var _chest: StorageChestData
var _generator: WindGeneratorData
var _station: StructureData


func before_each() -> void:
	_chest = load(CHEST_PATH) as StorageChestData
	_generator = load(GENERATOR_PATH) as WindGeneratorData
	_station = load(STATION_PATH) as StructureData
	_states = StructureStates.new()
	add_child_autofree(_states)


func _placed() -> Dictionary[String, StructureData]:
	return {CHEST_UID: _chest, GENERATOR_UID: _generator, STATION_UID: _station}


func _create_all() -> void:
	var placed: Dictionary[String, StructureData] = _placed()
	for uid: String in placed:
		_states.create_for(uid, placed[uid], NOW)


func test_r_012_26_chest_has_own_inventory_with_capacity() -> void:
	_create_all()
	var contents: InventoryComponent = _states.get_chest_contents(CHEST_UID)
	assert_not_null(contents, "a chest has its own inventory")
	if contents == null:
		return
	assert_eq(contents.get_slot_count(), _chest.container.slot_count, "with the capacity of its data")
	assert_true(contents.is_empty(), "a new chest is empty")
	_states.create_for("dddddddddddddddddddddddddddddddd", _chest, NOW)
	assert_ne(_states.get_chest_contents("dddddddddddddddddddddddddddddddd"), contents, "each chest its own")
	assert_null(_states.get_chest_contents(GENERATOR_UID), "a generator is not a chest")
	assert_null(_states.get_chest_contents(STATION_UID), "the station has no state")


func test_r_012_18_generator_starts_empty_at_creation() -> void:
	_create_all()
	var generator: WindGeneratorComponent = _states.get_generator(GENERATOR_UID)
	assert_not_null(generator, "a generator has its state")
	if generator == null:
		return
	assert_same(generator.config, _generator, "with its data")
	assert_eq(generator.to_save_data(), {"stored": 0, "since_unix": NOW}, "empty, counting from now")
	assert_null(_states.get_generator(CHEST_UID), "a chest is not a generator")


func test_r_012_39_round_trip() -> void:
	_create_all()
	assert_true(_states.get_chest_contents(CHEST_UID).add(&"scrap", 7).ok)
	var battery_inventory: InventoryComponent = InventoryComponent.new()
	add_child_autofree(battery_inventory)
	assert_true(battery_inventory.set_slot_count(1).ok)
	var later: int = NOW + _generator.seconds_per_battery * 3
	assert_true(_states.get_generator(GENERATOR_UID).collect(battery_inventory, later).ok)
	var data: Dictionary = _states.to_data()
	assert_eq(data.keys(), [StructureStates.CHESTS_KEY, StructureStates.GENERATORS_KEY], "two keys")
	var json: Dictionary = JSON.parse_string(JSON.stringify(data)) as Dictionary
	var restored: StructureStates = StructureStates.new()
	add_child_autofree(restored)
	restored.load_data(json, _placed(), NOW + 99)
	assert_eq(restored.to_data(), data, "the same state after JSON")
	assert_eq(restored.get_chest_contents(CHEST_UID).count(&"scrap"), 7, "the chest's contents")
	assert_eq(
		restored.get_generator(GENERATOR_UID).to_save_data(),
		_states.get_generator(GENERATOR_UID).to_save_data(),
		"the generator's stored count and reference time"
	)
	assert_push_error_count(0)


func test_r_012_40_no_capacity_saved() -> void:
	_create_all()
	var data: Dictionary = _states.to_data()
	var text: String = JSON.stringify(data)
	for forbidden: String in ["slot_count", "capacity", "max_stored", "seconds_per_battery", "bonus"]:
		assert_false(text.contains(forbidden), "'%s' is data, never saved" % forbidden)


func test_r_012_43_missing_keys_start_new() -> void:
	_states.load_data({}, _placed(), NOW)
	assert_not_null(_states.get_chest_contents(CHEST_UID), "a placed chest gets its state")
	assert_true(_states.get_chest_contents(CHEST_UID).is_empty(), "empty")
	assert_eq(
		_states.get_generator(GENERATOR_UID).to_save_data(),
		{"stored": 0, "since_unix": NOW},
		"a placed generator starts counting at load"
	)
	assert_push_error_count(0, "an older World has no such keys: not an error")


func test_r_012_42_invalid_entry_skipped() -> void:
	var data: Dictionary = {
		StructureStates.CHESTS_KEY: {CHEST_UID: {"no_slots": []}},
		StructureStates.GENERATORS_KEY: {GENERATOR_UID: {"stored": 99, "since_unix": NOW}},
	}
	_states.load_data(data, _placed(), NOW + 10)
	assert_true(_states.get_chest_contents(CHEST_UID).is_empty(), "the chest starts new")
	assert_eq(
		_states.get_generator(GENERATOR_UID).to_save_data(),
		{"stored": 0, "since_unix": NOW + 10},
		"the generator starts new"
	)
	assert_push_error_count(2, "each bad entry is reported")


func test_r_012_42_valid_entries_kept_next_to_invalid() -> void:
	var other_chest: String = "dddddddddddddddddddddddddddddddd"
	var placed: Dictionary[String, StructureData] = _placed()
	placed[other_chest] = _chest
	var data: Dictionary = {
		StructureStates.CHESTS_KEY: {
			CHEST_UID: "not a dictionary",
			other_chest: {"slots": [{"item_id": "iron", "quantity": 2, "durability": -1, "uid": ""}, null, null, null]},
		},
	}
	_states.load_data(data, placed, NOW)
	assert_eq(_states.get_chest_contents(other_chest).count(&"iron"), 2, "the valid entry loads")
	assert_true(_states.get_chest_contents(CHEST_UID).is_empty(), "the bad one starts new")
	assert_push_error_count(1)


func test_r_012_42_entry_for_unplaced_uid_skipped() -> void:
	var stranger: String = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	var data: Dictionary = {
		StructureStates.CHESTS_KEY: {stranger: {"slots": [null, null, null, null]}},
		StructureStates.GENERATORS_KEY: {stranger: {"stored": 1, "since_unix": NOW}},
	}
	_states.load_data(data, _placed(), NOW)
	assert_null(_states.get_chest_contents(stranger), "no state for a structure that is not placed")
	assert_null(_states.get_generator(stranger), "no state for a structure that is not placed")
	assert_push_error_count(2)


func test_r_012_42_entry_of_other_kind_skipped() -> void:
	var data: Dictionary = {
		StructureStates.CHESTS_KEY: {GENERATOR_UID: {"slots": [null, null, null, null]}, STATION_UID: {"slots": []}},
		StructureStates.GENERATORS_KEY: {CHEST_UID: {"stored": 1, "since_unix": NOW}},
	}
	_states.load_data(data, _placed(), NOW)
	assert_null(_states.get_chest_contents(GENERATOR_UID), "a generator never becomes a chest")
	assert_null(_states.get_generator(CHEST_UID), "a chest never becomes a generator")
	assert_not_null(_states.get_generator(GENERATOR_UID), "the generator still has its own state")
	assert_push_error_count(3)


func test_r_012_42_parts_that_are_not_dictionaries_reported() -> void:
	_states.load_data({StructureStates.CHESTS_KEY: [], StructureStates.GENERATORS_KEY: 3}, _placed(), NOW)
	assert_not_null(_states.get_chest_contents(CHEST_UID), "the placed chest still gets a new state")
	assert_push_error_count(2)


func test_load_replaces_previous_states() -> void:
	_create_all()
	var old_contents: InventoryComponent = _states.get_chest_contents(CHEST_UID)
	assert_true(old_contents.add(&"scrap", 3).ok)
	var only_chest: Dictionary[String, StructureData] = {CHEST_UID: _chest}
	_states.load_data({}, only_chest, NOW)
	assert_ne(_states.get_chest_contents(CHEST_UID), old_contents, "a new state")
	assert_true(_states.get_chest_contents(CHEST_UID).is_empty(), "with nothing from before")
	assert_null(_states.get_generator(GENERATOR_UID), "a structure no longer placed has no state")
	assert_false(old_contents.is_inside_tree(), "the old state left the tree at once")


func test_r_012_41_load_emits_no_facts() -> void:
	watch_signals(EventBus)
	_states.load_data(
		{
			StructureStates.CHESTS_KEY: {CHEST_UID: {"slots": [{"item_id": "scrap", "quantity": 1, "durability": -1, "uid": ""}, null, null, null]}},
			StructureStates.GENERATORS_KEY: {GENERATOR_UID: {"stored": 2, "since_unix": NOW}},
		},
		_placed(),
		NOW
	)
	assert_signal_not_emitted(EventBus, "structure_built")
	assert_signal_not_emitted(EventBus, "batteries_collected")
	assert_signal_not_emitted(EventBus, "chest_closed")
