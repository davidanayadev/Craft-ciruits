extends GutTest
## WindGeneratorComponent (spec 012): the state of one placed generator, its
## collection into an inventory and its save entry (R-012-16 to R-012-20,
## R-012-39). Everything is made by hand: a period of 100 s, at most 3, and a
## battery item that stacks 5.

const PERIOD := 100
const MAX_STORED := 3
const START := 1_000
const BATTERY_ID := &"portable_battery"

var _catalog: DataCatalog
var _config: WindGeneratorData


func before_each() -> void:
	var battery: ConsumableData = ConsumableData.new()
	battery.id = BATTERY_ID
	battery.stack_max = 5
	var scrap: ItemData = ItemData.new()
	scrap.id = &"scrap"
	scrap.stack_max = 10
	_catalog = DataCatalog.new()
	_catalog.items.append(battery)
	_catalog.items.append(scrap)
	_config = WindGeneratorData.new()
	_config.seconds_per_battery = PERIOD
	_config.max_stored = MAX_STORED
	_config.battery_item = battery


func _generator(now: int = START) -> WindGeneratorComponent:
	var generator: WindGeneratorComponent = WindGeneratorComponent.new()
	add_child_autofree(generator)
	generator.start(_config, now)
	return generator


func _inventory(slot_count: int) -> InventoryComponent:
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.catalog = _catalog
	add_child_autofree(inventory)
	assert_true(inventory.set_slot_count(slot_count).ok)
	return inventory


func test_r_012_18_starts_empty_counting_now() -> void:
	var generator: WindGeneratorComponent = _generator()
	assert_eq(generator.get_stored(START), 0, "built empty")
	assert_eq(generator.get_seconds_to_next(START), PERIOD, "its first period starts now")
	assert_eq(generator.get_stored(START + PERIOD), 1, "one battery after a period")
	assert_eq(generator.get_stored(START + 9 * PERIOD), MAX_STORED, "never above the maximum")
	assert_eq(generator.get_seconds_to_next(START + 9 * PERIOD), -1, "full")


func test_reading_changes_nothing() -> void:
	var generator: WindGeneratorComponent = _generator()
	watch_signals(generator)
	var _first: int = generator.get_stored(START + 2 * PERIOD)
	assert_eq(generator.to_save_data(), {"stored": 0, "since_unix": START}, "reading does not settle")
	assert_signal_emit_count(generator, "generator_changed", 0)


func test_r_012_20_collect_moves_what_fits() -> void:
	var generator: WindGeneratorComponent = _generator()
	var inventory: InventoryComponent = _inventory(2)
	assert_true(inventory.add(&"scrap", 10).ok)
	assert_true(inventory.add(BATTERY_ID, 4).ok)
	watch_signals(generator)
	var now: int = START + 10 * PERIOD
	var result: ActionResult = generator.collect(inventory, now)
	assert_true(result.ok, "one battery moved")
	assert_eq(inventory.count(BATTERY_ID), 5, "as much as fits")
	assert_eq(generator.get_stored(now), 2, "the rest stays in the generator")
	var since: int = generator.to_save_data()["since_unix"]
	assert_eq(since, now, "taken from full: the next period starts now")
	assert_signal_emit_count(generator, "generator_changed", 1)


func test_r_012_20_collect_everything() -> void:
	var generator: WindGeneratorComponent = _generator()
	var inventory: InventoryComponent = _inventory(2)
	var now: int = START + 2 * PERIOD + 10
	assert_true(generator.collect(inventory, now).ok)
	assert_eq(inventory.count(BATTERY_ID), 2, "both batteries moved")
	assert_eq(generator.get_stored(now), 0, "empty")
	assert_eq(generator.get_seconds_to_next(now), PERIOD - 10, "the period in progress goes on")


func test_r_012_20_nothing_fits_no_change() -> void:
	var generator: WindGeneratorComponent = _generator()
	var inventory: InventoryComponent = _inventory(1)
	assert_true(inventory.add(&"scrap", 3).ok)
	watch_signals(generator)
	watch_signals(inventory)
	var now: int = START + 3 * PERIOD
	var result: ActionResult = generator.collect(inventory, now)
	assert_false(result.ok, "nothing fits")
	assert_eq(result.error_key, InventoryComponent.MSG_INVENTORY_FULL)
	assert_eq(generator.to_save_data(), {"stored": 0, "since_unix": START}, "the generator did not change")
	assert_eq(generator.get_stored(now), MAX_STORED, "it still holds them")
	assert_signal_emit_count(generator, "generator_changed", 0)
	assert_signal_emit_count(inventory, "inventory_changed", 0)
	assert_signal_emit_count(inventory, "overflowed", 1, "the inventory full notice of R-005-20")


func test_r_012_20_empty_refused() -> void:
	var generator: WindGeneratorComponent = _generator()
	var inventory: InventoryComponent = _inventory(2)
	watch_signals(generator)
	var result: ActionResult = generator.collect(inventory, START + PERIOD - 1)
	assert_false(result.ok, "nothing to collect")
	assert_eq(result.error_key, WindGeneratorComponent.MSG_GENERATOR_EMPTY)
	assert_true(inventory.is_empty(), "nothing moved")
	assert_signal_emit_count(generator, "generator_changed", 0)


func test_collect_without_inventory_rejected() -> void:
	var generator: WindGeneratorComponent = _generator()
	var result: ActionResult = generator.collect(null, START + PERIOD)
	assert_eq(result.error_key, ActionResult.ERR_INVALID_REQUEST)
	assert_push_error("no inventory")


func test_r_012_39_save_round_trip() -> void:
	var generator: WindGeneratorComponent = _generator()
	var inventory: InventoryComponent = _inventory(1)
	assert_true(generator.collect(inventory, START + PERIOD + 20).ok)
	var saved: Dictionary = generator.to_save_data()
	assert_eq(saved, {"stored": 0, "since_unix": START + PERIOD}, "stored and the start of the period in progress")
	var json: Variant = JSON.parse_string(JSON.stringify(saved))
	var copy: WindGeneratorComponent = WindGeneratorComponent.new()
	add_child_autofree(copy)
	copy.config = _config
	watch_signals(copy)
	assert_true(copy.load_save_data(json as Dictionary), "a valid entry, also with JSON floats")
	assert_eq(copy.to_save_data(), saved, "the same state")
	assert_signal_emit_count(copy, "generator_changed", 1, "a state signal on load")


func test_r_012_42_bad_entry_rejected() -> void:
	var bad_entries: Array[Dictionary] = [
		{},
		{"stored": -1, "since_unix": START},
		{"stored": MAX_STORED + 1, "since_unix": START},
		{"stored": 1.5, "since_unix": START},
		{"stored": 1, "since_unix": "soon"},
		{"stored": 1, "since_unix": 10.5},
		{"stored": 1},
	]
	for entry: Dictionary in bad_entries:
		var generator: WindGeneratorComponent = _generator()
		watch_signals(generator)
		assert_false(generator.load_save_data(entry), "%s is not valid" % entry)
		assert_eq(generator.to_save_data(), {"stored": 0, "since_unix": START}, "%s: no change" % entry)
		assert_signal_emit_count(generator, "generator_changed", 0)
