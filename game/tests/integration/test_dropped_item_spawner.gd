extends GutTest
## DroppedItemSpawner (spec 008): items keep a position local to their zone
## (R-008-10), go back to the pool when emptied (R-008-14) and come clean from
## it (R-008-18), record the clock when they fall (R-008-20), expire without
## giving anything (R-008-22) and are independent of each other (R-008-32).
## Spec 010: the spawner is saved with the world, as spec 008 describes an item,
## discards expired items on loading and restores the rest when its zone is bound
## (R-010-09, R-010-11, R-010-29, R-010-30). Spec 011: pieces keep durability
## and uid when thrown, picked up, saved and loaded; a bad piece stack is lost (R-011-09 to R-011-11).

const DROPPED_ITEM_SCENE := preload("res://scenes/entities/dropped_item.tscn")
const CONFIG_PATH := "res://resources/config/dropped_items.tres"
const ZONE := Vector2i(3, 4)
const ZONE_ORIGIN := Vector3(40.0, 0.0, -25.0)
const START_TIME := 1000

var _world: Node3D
var _pool: ObjectPool
var _spawner: DroppedItemSpawner
var _zone_root: Node3D
var _clock: FakeTimeService
var _config: DroppedItemConfigData


func before_each() -> void:
	_config = load(CONFIG_PATH) as DroppedItemConfigData
	_clock = FakeTimeService.new()
	_clock.now = START_TIME
	_world = Node3D.new()
	add_child_autofree(_world)
	_pool = ObjectPool.new()
	_pool.scene = DROPPED_ITEM_SCENE
	_world.add_child(_pool)
	_spawner = DroppedItemSpawner.new()
	_spawner.pool = _pool
	_spawner.config = _config
	_spawner.time_service = _clock
	_world.add_child(_spawner)
	_zone_root = Node3D.new()
	_zone_root.position = ZONE_ORIGIN
	_world.add_child(_zone_root)
	_spawner.bind_zone(ZONE, _zone_root)


func _new_inventory(slot_count: int) -> InventoryComponent:
	var inventory: InventoryComponent = InventoryComponent.new()
	add_child_autofree(inventory)
	inventory.set_slot_count(slot_count)
	return inventory


func _source_with_loot() -> InventoryComponent:
	var source: InventoryComponent = _new_inventory(5)
	source.add(&"scrap", 6)
	source.add(&"iron", 2)
	return source


func _stack(item_id: StringName, quantity: int) -> ItemStack:
	return ItemStack.new(DataRegistry.get_item(item_id), quantity)


func _pick_up(item: DroppedItem) -> InventoryComponent:
	var picker: Node3D = Node3D.new()
	add_child_autofree(picker)
	var inventory: InventoryComponent = InventoryComponent.new()
	picker.add_child(inventory)
	inventory.set_slot_count(10)
	var interactable: InteractableComponent = item.get_node("%Interactable") as InteractableComponent
	interactable.interact(picker)
	return inventory


func test_r_008_10_position_is_local_to_the_zone() -> void:
	var world_position: Vector3 = Vector3(45.0, 0.0, -20.0)
	var item: DroppedItem = _spawner.drop_inventory(_source_with_loot(), world_position)
	assert_not_null(item, "an item was created")
	if item == null:
		return
	assert_eq(item.global_position, world_position, "it lies at the world position")
	assert_eq(item.local_position, _zone_root.to_local(world_position), "local to the zone")
	assert_eq(item.local_position, world_position - ZONE_ORIGIN, "zone origin subtracted")
	assert_eq(item.zone_id, ZONE, "zone as bound")


func test_r_008_14_emptied_goes_back_to_pool() -> void:
	var item: DroppedItem = _spawner.drop_inventory(_source_with_loot(), Vector3.ZERO)
	var free_before: int = _pool.get_free_count()
	_pick_up(item)
	await wait_physics_frames(2)
	assert_false(_spawner.get_items().has(item), "no longer an active item")
	assert_false(item.is_inside_tree(), "outside the tree")
	assert_gt(_pool.get_free_count(), free_before, "stored in the pool")


func test_r_008_18_reused_item_is_clean() -> void:
	var first: DroppedItem = _spawner.drop_inventory(_source_with_loot(), Vector3.ZERO)
	var first_uid: String = first.uid
	_pick_up(first)
	await wait_physics_frames(2)
	_clock.now = START_TIME + 50
	var one: Array[ItemStack] = [_stack(&"cables", 4)]
	var second: DroppedItem = _spawner.drop_stacks(one, Vector3(1.0, 0.0, 1.0))
	assert_same(second, first, "the pooled instance is reused")
	assert_eq(second.get_contents().get_slot_count(), 1, "one slot")
	var expected: Dictionary[StringName, int] = {&"cables": 4}
	var totals: Dictionary[StringName, int] = {}
	for stack: ItemStack in second.get_contents().get_slots():
		if stack != null:
			totals[stack.item.id] = stack.quantity
	assert_eq(totals, expected, "only the new stack")
	assert_ne(second.uid, first_uid, "another uid")
	assert_ne(second.uid, "", "a real uid")
	assert_eq(second.dropped_at_unix, START_TIME + 50, "the new time")


func test_r_008_18_items_come_from_the_pool() -> void:
	_pool.prewarm(3)
	assert_eq(_pool.get_free_count(), 3, "prewarmed")
	var one: Array[ItemStack] = [_stack(&"scrap", 1)]
	_spawner.drop_stacks(one, Vector3.ZERO)
	assert_eq(_pool.get_free_count(), 2, "the first drop took a stored instance")
	_spawner.drop_stacks(one, Vector3.ZERO)
	_spawner.drop_stacks(one, Vector3.ZERO)
	assert_eq(_pool.get_free_count(), 0, "three drops used the three, none was created")
	assert_eq(_spawner.get_items().size(), 3, "three active items")


func test_r_008_20_drop_records_now() -> void:
	_clock.now = 1234
	var from_inventory: DroppedItem = _spawner.drop_inventory(_source_with_loot(), Vector3.ZERO)
	assert_eq(from_inventory.dropped_at_unix, 1234, "drop_inventory")
	_clock.now = 1300
	var source: InventoryComponent = _new_inventory(3)
	source.add(&"scrap", 5)
	var result: ActionResult = _spawner.drop_from_slot(source, 0, 2, Vector3.ZERO)
	assert_true(result.ok, "the split drop works")
	var from_slot: DroppedItem = _spawner.get_items().back()
	assert_eq(from_slot.dropped_at_unix, 1300, "drop_from_slot")
	_clock.now = 1400
	var one: Array[ItemStack] = [_stack(&"iron", 1)]
	var from_stacks: DroppedItem = _spawner.drop_stacks(one, Vector3.ZERO)
	assert_eq(from_stacks.dropped_at_unix, 1400, "drop_stacks")


func test_r_008_22_expired_disappears_and_gives_nothing() -> void:
	var source: InventoryComponent = _source_with_loot()
	var item: DroppedItem = _spawner.drop_inventory(source, Vector3.ZERO)
	var free_before: int = _pool.get_free_count()
	var lifetime: int = _config.lifetime_s
	assert_gt(lifetime, 0, "the config has a lifetime")
	_spawner.discard_expired(START_TIME + lifetime - 1)
	assert_true(_spawner.get_items().has(item), "one second before the end it stays")
	_spawner.discard_expired(START_TIME + lifetime)
	assert_false(_spawner.get_items().has(item), "at dropped_at + lifetime it is gone")
	assert_false(item.is_inside_tree(), "outside the tree")
	assert_gt(_pool.get_free_count(), free_before, "back in the pool")
	assert_true(source.is_empty(), "the source did not get anything back")
	assert_true(item.get_contents().is_empty(), "the stacks did not go anywhere")


func test_r_008_22_timer_runs_only_with_items() -> void:
	assert_false(_spawner.is_checking_expiry(), "no items, no check")
	var item: DroppedItem = _spawner.drop_inventory(_source_with_loot(), Vector3.ZERO)
	assert_true(_spawner.is_checking_expiry(), "running with an item")
	_pick_up(item)
	await wait_physics_frames(2)
	assert_false(_spawner.is_checking_expiry(), "stopped when the last one left")
	var one: Array[ItemStack] = [_stack(&"scrap", 1)]
	_spawner.drop_stacks(one, Vector3.ZERO)
	assert_true(_spawner.is_checking_expiry(), "running again")
	_spawner.discard_expired(START_TIME + _config.lifetime_s)
	assert_false(_spawner.is_checking_expiry(), "stopped after expiry too")


func test_r_008_32_independent_items() -> void:
	var older: DroppedItem = _spawner.drop_inventory(_source_with_loot(), Vector3.ZERO)
	_clock.now = START_TIME + 100
	var newer: DroppedItem = _spawner.drop_inventory(_source_with_loot(), Vector3.ONE)
	assert_ne(older, newer, "two items")
	assert_ne(older.uid, newer.uid, "each with its own uid")
	assert_eq(older.dropped_at_unix, START_TIME, "its own time")
	assert_eq(newer.dropped_at_unix, START_TIME + 100, "its own time")
	_spawner.discard_expired(START_TIME + _config.lifetime_s)
	assert_eq(_spawner.get_items().size(), 1, "only the older one expired")
	assert_same(_spawner.get_items()[0], newer, "the newer one stays")


func test_r_008_10_drop_inventory_empty_creates_nothing() -> void:
	_pool.prewarm(2)
	var item: DroppedItem = _spawner.drop_inventory(_new_inventory(5), Vector3.ZERO)
	assert_null(item, "nothing to drop")
	assert_eq(_spawner.get_items().size(), 0, "no item")
	assert_eq(_pool.get_free_count(), 2, "the pool was not touched")


func test_r_008_10_drop_inventory_moves_everything() -> void:
	var source: InventoryComponent = _source_with_loot()
	var item: DroppedItem = _spawner.drop_inventory(source, Vector3.ZERO)
	assert_true(source.is_empty(), "the source gave everything")
	assert_eq(item.get_contents().count(&"scrap"), 6, "scrap moved")
	assert_eq(item.get_contents().count(&"iron"), 2, "iron moved")


func test_r_008_10_drop_from_slot_moves_exactly_the_quantity() -> void:
	var source: InventoryComponent = _new_inventory(3)
	source.add(&"scrap", 10)
	var result: ActionResult = _spawner.drop_from_slot(source, 0, 4, Vector3.ZERO)
	assert_true(result.ok, "ok")
	assert_eq(source.count(&"scrap"), 6, "the rest stays in the slot")
	assert_eq(_spawner.get_items().size(), 1, "one item")
	var item: DroppedItem = _spawner.get_items()[0]
	assert_eq(item.get_contents().count(&"scrap"), 4, "exactly the quantity")


func test_r_008_10_drop_from_slot_invalid_creates_nothing() -> void:
	var source: InventoryComponent = _new_inventory(3)
	source.add(&"scrap", 10)
	var cases: Array[Vector2i] = [Vector2i(7, 1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(0, 11)]
	for request: Vector2i in cases:
		var result: ActionResult = _spawner.drop_from_slot(source, request.x, request.y, Vector3.ZERO)
		assert_false(result.ok, "slot %d quantity %d is invalid" % [request.x, request.y])
		assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST, "invalid request")
	assert_eq(_spawner.get_items().size(), 0, "nothing created")
	assert_eq(source.count(&"scrap"), 10, "the source is untouched")


func test_r_008_10_drop_stacks_empty_is_null() -> void:
	var none: Array[ItemStack] = []
	assert_null(_spawner.drop_stacks(none, Vector3.ZERO), "no stacks, no item")
	assert_eq(_spawner.get_items().size(), 0, "nothing created")


func test_r_008_10_drop_stacks_holds_copies_of_the_stacks() -> void:
	var stacks: Array[ItemStack] = [_stack(&"scrap", 3), _stack(&"iron", 2)]
	var item: DroppedItem = _spawner.drop_stacks(stacks, Vector3.ZERO)
	assert_eq(item.get_contents().count(&"scrap"), 3, "scrap")
	assert_eq(item.get_contents().count(&"iron"), 2, "iron")


func test_r_008_10_to_data_lists_one_dictionary_per_item() -> void:
	_spawner.drop_inventory(_source_with_loot(), Vector3.ZERO)
	var one: Array[ItemStack] = [_stack(&"cables", 1)]
	_spawner.drop_stacks(one, Vector3.ONE)
	var data: Array[Dictionary] = _spawner.to_data()
	assert_eq(data.size(), 2, "one per item")
	var first_uid: String = data[0]["uid"]
	assert_eq(first_uid, _spawner.get_items()[0].uid, "oldest first")


func test_r_008_10_spawner_without_zone_reports_error() -> void:
	var unbound: DroppedItemSpawner = DroppedItemSpawner.new()
	unbound.pool = _pool
	unbound.time_service = _clock
	_world.add_child(unbound)
	var one: Array[ItemStack] = [_stack(&"scrap", 1)]
	assert_null(unbound.drop_stacks(one, Vector3.ZERO), "no zone bound")
	assert_push_error("needs a pool, a time service and a bound zone")
	assert_eq(unbound.get_items().size(), 0, "nothing created")


func test_r_008_10_spawner_without_time_service_reports_error() -> void:
	var no_clock: DroppedItemSpawner = DroppedItemSpawner.new()
	no_clock.pool = _pool
	_world.add_child(no_clock)
	no_clock.bind_zone(ZONE, _zone_root)
	var one: Array[ItemStack] = [_stack(&"scrap", 1)]
	assert_null(no_clock.drop_stacks(one, Vector3.ZERO), "no clock")
	assert_push_error("needs a pool, a time service and a bound zone")
	assert_eq(no_clock.get_items().size(), 0, "nothing created")


const OTHER_ZONE := Vector2i(0, -1)


func test_r_009_04_unbind_returns_items_to_pool() -> void:
	_spawner.drop_inventory(_source_with_loot(), ZONE_ORIGIN + Vector3(1.0, 0.0, 1.0))
	_spawner.drop_stacks([_stack(&"cables", 3)], ZONE_ORIGIN + Vector3(-2.0, 0.0, 0.5))
	var free_before: int = _pool.get_free_count()
	_spawner.unbind_zone()
	assert_eq(_spawner.get_items().size(), 0, "no active item left")
	assert_eq(_pool.get_free_count(), free_before + 2, "both went back to the pool")
	assert_false(_spawner.is_checking_expiry(), "nothing left to expire")


func test_r_009_17_unbind_stores_and_rebind_restores() -> void:
	var item: DroppedItem = _spawner.drop_inventory(
		_source_with_loot(), ZONE_ORIGIN + Vector3(1.0, 0.0, 2.0)
	)
	var before: Array[Dictionary] = _spawner.to_data()
	var uid: String = item.uid
	_spawner.unbind_zone()
	var other_root: Node3D = Node3D.new()
	_world.add_child(other_root)
	_spawner.bind_zone(OTHER_ZONE, other_root)
	assert_eq(_spawner.get_items().size(), 0, "another zone does not get them")
	_spawner.unbind_zone()
	# The zone comes back somewhere else in the world: the item follows it.
	var new_root: Node3D = Node3D.new()
	new_root.position = ZONE_ORIGIN + Vector3(5.0, 0.0, 0.0)
	_world.add_child(new_root)
	_spawner.bind_zone(ZONE, new_root)
	assert_eq(_spawner.to_data(), before, "same uid, zone, local position, time and stacks")
	assert_eq(_spawner.get_items().size(), 1, "one item back")
	if _spawner.get_items().size() != 1:
		return
	var restored: DroppedItem = _spawner.get_items()[0]
	assert_eq(restored.uid, uid, "same uid")
	assert_eq(
		restored.global_position, new_root.to_global(restored.local_position), "lies in its zone"
	)
	assert_true(_spawner.is_checking_expiry(), "expiry runs again")
	var picked: InventoryComponent = _pick_up(restored)
	assert_eq(picked.count(&"scrap"), 6, "its scrap can be picked up")
	assert_eq(picked.count(&"iron"), 2, "and its iron")


func test_r_009_17_expired_discarded_on_rebind() -> void:
	_spawner.drop_inventory(_source_with_loot(), ZONE_ORIGIN)
	_clock.now = START_TIME + 10
	_spawner.drop_stacks([_stack(&"cables", 1)], ZONE_ORIGIN + Vector3(2.0, 0.0, 0.0))
	_spawner.unbind_zone()
	# Unloaded zones do not expire; the first item's lifetime ends meanwhile.
	_clock.now = START_TIME + _config.lifetime_s
	_spawner.bind_zone(ZONE, _zone_root)
	assert_eq(_spawner.get_items().size(), 1, "the expired one is discarded on rebind")
	if _spawner.get_items().size() == 1:
		assert_eq(_spawner.get_items()[0].get_contents().count(&"cables"), 1, "the newer one stays")


func test_r_009_17_rebind_twice_restores_once() -> void:
	_spawner.drop_inventory(_source_with_loot(), ZONE_ORIGIN)
	_spawner.unbind_zone()
	_spawner.bind_zone(ZONE, _zone_root)
	_spawner.unbind_zone()
	_spawner.bind_zone(ZONE, _zone_root)
	assert_eq(_spawner.get_items().size(), 1, "stored items are restored once, not duplicated")


## Spec 010: saving and loading (R-010-09, R-010-11, R-010-29, R-010-30).
const FARM_ZONE := Vector2i(0, 0)
const BASE_ZONE := Vector2i(0, -1)


func _fresh_spawner() -> DroppedItemSpawner:
	var spawner: DroppedItemSpawner = DroppedItemSpawner.new()
	spawner.pool = _pool
	spawner.config = _config
	spawner.time_service = _clock
	_world.add_child(spawner)
	return spawner


func _root() -> Node3D:
	var root: Node3D = Node3D.new()
	_world.add_child(root)
	return root


func _entry(uid: String, zone: Vector2i, dropped_at: int, item_id: String = "scrap") -> Dictionary:
	return {
		"uid": uid,
		"zone_id": [zone.x, zone.y],
		"position": [1.0, 0.0, 2.0],
		"dropped_at": dropped_at,
		"stacks": [{"item_id": item_id, "quantity": 2}],
	}


func _uids(data: Dictionary) -> PackedStringArray:
	var uids: PackedStringArray = PackedStringArray()
	var items: Array = data["items"]
	for entry: Variant in items:
		var item_data: Dictionary = entry
		var uid: String = item_data["uid"]
		uids.append(uid)
	uids.sort()
	return uids


func _sorted_by_uid(items: Array) -> Array:
	var sorted: Array = items.duplicate()
	sorted.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var uid_a: String = a["uid"]
			var uid_b: String = b["uid"]
			return uid_a < uid_b
	)
	return sorted


func test_r_010_09_save_key() -> void:
	assert_eq(DroppedItemSpawner.SAVE_KEY, &"dropped_items", "constant")
	assert_eq(_spawner.get_save_key(), &"dropped_items", "method")


func test_r_010_29_saved_as_spec_008() -> void:
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.bind_zone(FARM_ZONE, _root())
	var live: DroppedItem = spawner.drop_inventory(_source_with_loot(), Vector3(2.0, 0.0, 3.0))
	var expected: Array = [live.to_data()]
	spawner.unbind_zone()
	spawner.bind_zone(BASE_ZONE, _root())
	var other: Array[ItemStack] = [_stack(&"cables", 1)]
	var second: DroppedItem = spawner.drop_stacks(other, Vector3(-1.0, 0.0, 1.0))
	expected.append(second.to_data())
	var data: Dictionary = spawner.to_save_data()
	var items: Array = data["items"]
	assert_eq(items.size(), 2, "live and stored items")
	assert_eq(_sorted_by_uid(items), _sorted_by_uid(expected), "each entry equals DroppedItem.to_data()")


func test_r_010_09_empty_save_data() -> void:
	var spawner: DroppedItemSpawner = _fresh_spawner()
	assert_eq(spawner.to_save_data(), {"items": []}, "nothing dropped")


func test_r_010_09_round_trip_dropped_items() -> void:
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.bind_zone(FARM_ZONE, _root())
	spawner.drop_inventory(_source_with_loot(), Vector3(2.0, 0.0, 3.0))
	spawner.unbind_zone()
	spawner.bind_zone(BASE_ZONE, _root())
	var one: Array[ItemStack] = [_stack(&"cables", 1)]
	spawner.drop_stacks(one, Vector3(-1.0, 0.0, 1.0))
	var saved: Dictionary = spawner.to_save_data()
	var restored: DroppedItemSpawner = _fresh_spawner()
	restored.from_save_data(saved)
	restored.bind_zone(BASE_ZONE, _root())
	var again: Dictionary = restored.to_save_data()
	var saved_items: Array = saved["items"]
	var again_items: Array = again["items"]
	assert_eq(_sorted_by_uid(again_items), _sorted_by_uid(saved_items), "same items")
	assert_eq(restored.get_items().size(), 1, "the bound zone's item is back")
	restored.unbind_zone()
	restored.bind_zone(FARM_ZONE, _root())
	assert_eq(restored.get_items().size(), 1, "the other zone's item comes back when bound")


func test_r_010_09_load_replaces_what_was_stored() -> void:
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.bind_zone(FARM_ZONE, _root())
	spawner.drop_inventory(_source_with_loot(), Vector3.ZERO)
	spawner.unbind_zone()
	spawner.from_save_data({"items": [_entry("keep", BASE_ZONE, START_TIME)]})
	assert_eq(_uids(spawner.to_save_data()), PackedStringArray(["keep"]), "only what was loaded")


func test_r_010_09_load_emits_nothing() -> void:
	watch_signals(EventBus)
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.from_save_data({"items": [_entry("a", FARM_ZONE, START_TIME)]})
	spawner.bind_zone(FARM_ZONE, _root())
	for info: Dictionary in EventBus.get_signal_list():
		var signal_name: String = info["name"]
		assert_signal_not_emitted(EventBus, signal_name, "loading emits no %s" % signal_name)


func test_r_010_30_expired_on_load() -> void:
	var lifetime: int = _config.lifetime_s
	var data: Dictionary = {
		"items":
		[
			_entry("exact", FARM_ZONE, START_TIME - lifetime),
			_entry("one_second_less", FARM_ZONE, START_TIME - lifetime + 1),
			_entry("future", FARM_ZONE, START_TIME + 100),
			_entry("ancient", FARM_ZONE, START_TIME - lifetime * 10),
		]
	}
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.from_save_data(data)
	var kept: PackedStringArray = _uids(spawner.to_save_data())
	assert_eq(
		kept,
		PackedStringArray(["future", "one_second_less"]),
		"the exact limit and older expire; younger and future ones stay"
	)
	spawner.bind_zone(FARM_ZONE, _root())
	assert_eq(spawner.get_items().size(), 2, "the survivors are restored")


func test_r_010_11_malformed_entries_skipped() -> void:
	var broken: Dictionary = _entry("broken", FARM_ZONE, START_TIME)
	broken.erase("stacks")
	var data: Dictionary = {"items": [broken, _entry("good", FARM_ZONE, START_TIME)]}
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.from_save_data(data)
	assert_push_error_count(1)
	assert_eq(_uids(spawner.to_save_data()), PackedStringArray(["good"]), "only the good one")


func test_r_010_11_unknown_zone_skipped() -> void:
	var data: Dictionary = {
		"items": [_entry("lost", Vector2i(99, 99), START_TIME), _entry("good", FARM_ZONE, START_TIME)]
	}
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.from_save_data(data)
	assert_push_error_count(1)
	assert_eq(_uids(spawner.to_save_data()), PackedStringArray(["good"]), "the unknown zone is dropped")


func test_r_010_11_unknown_id_skipped() -> void:
	var data: Dictionary = {
		"items":
		[
			_entry("ghost", FARM_ZONE, START_TIME, "no_such_item"),
			_entry("good", FARM_ZONE, START_TIME),
		]
	}
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.from_save_data(data)
	spawner.bind_zone(FARM_ZONE, _root())
	assert_push_error_count(1)
	assert_eq(spawner.get_items().size(), 1, "the stack of the unknown item is lost, the rest loads")
	if spawner.get_items().size() == 1:
		assert_eq(spawner.get_items()[0].uid, "good", "the other entry")


# --- Pieces (spec 011) --------------------------------------------------------

## A crafted basic arms piece, damaged to durability.
func _piece(durability: int) -> ItemStack:
	var piece: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(&"basic_arms"))
	piece.durability = durability
	return piece


## The one piece stack of inventory; null when there is none.
func _piece_in(inventory: InventoryComponent) -> ItemStack:
	for stack: ItemStack in inventory.get_slots():
		if stack != null and stack.item is PieceData:
			return stack
	return null


func _piece_entry(uid: String, durability: Variant, piece_uid: Variant) -> Dictionary:
	var entry: Dictionary = _entry(uid, FARM_ZONE, START_TIME)
	var stacks: Array = [
		{"item_id": "scrap", "quantity": 2},
		{"item_id": "basic_arms", "quantity": 1, "durability": durability, "uid": piece_uid},
	]
	entry["stacks"] = stacks
	return entry


func test_r_011_09_throw_and_pick_up_keep_piece() -> void:
	var source: InventoryComponent = _new_inventory(3)
	var piece: ItemStack = _piece(55)
	var offered: Array[ItemStack] = [piece]
	assert_true(source.add_stacks(offered).ok, "the piece is in the inventory")
	var thrown: ActionResult = _spawner.drop_from_slot(source, 0, 1, Vector3(41.0, 0.0, -24.0))
	assert_true(thrown.ok, "the piece is thrown")
	var items: Array[DroppedItem] = _spawner.get_items()
	assert_eq(items.size(), 1, "it lies on the ground")
	if items.size() != 1:
		return
	var on_ground: ItemStack = _piece_in(items[0].get_contents())
	assert_not_null(on_ground, "the dropped item holds the piece")
	if on_ground != null:
		assert_eq(on_ground.durability, 55, "durability kept on the ground")
		assert_eq(on_ground.uid, piece.uid, "uid kept on the ground")
	var picked: ItemStack = _piece_in(_pick_up(items[0]))
	assert_not_null(picked, "the piece is picked up")
	if picked != null:
		assert_eq(picked.durability, 55, "durability kept when picked up")
		assert_eq(picked.uid, piece.uid, "uid kept when picked up")


func test_r_011_10_save_load_restores_piece() -> void:
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.bind_zone(FARM_ZONE, _root())
	var piece: ItemStack = _piece(30)
	var stacks: Array[ItemStack] = [_stack(&"scrap", 2), piece]
	spawner.drop_stacks(stacks, Vector3(1.0, 0.0, 1.0))
	var saved: Dictionary = spawner.to_save_data()
	var restored: DroppedItemSpawner = _fresh_spawner()
	restored.from_save_data(saved)
	restored.bind_zone(FARM_ZONE, _root())
	var items: Array[DroppedItem] = restored.get_items()
	assert_eq(items.size(), 1, "the dropped item is back")
	if items.size() != 1:
		return
	var loaded: ItemStack = _piece_in(items[0].get_contents())
	assert_not_null(loaded, "with its piece")
	if loaded != null:
		assert_eq(loaded.durability, 30, "durability restored")
		assert_eq(loaded.uid, piece.uid, "uid restored")
	assert_eq(items[0].get_contents().count(&"scrap"), 2, "and its material")


func test_r_011_11_bad_saved_piece_stack_lost() -> void:
	var data: Dictionary = {
		"items":
		[
			_piece_entry("zero", 0, "p1"),
			_piece_entry("above", 101, "p2"),
			_piece_entry("no_uid", 50, ""),
			_piece_entry("no_fields", -1, ""),
			_piece_entry("good", 50, "p3"),
		]
	}
	var spawner: DroppedItemSpawner = _fresh_spawner()
	spawner.from_save_data(data)
	spawner.bind_zone(FARM_ZONE, _root())
	assert_push_error_count(4)
	var items: Array[DroppedItem] = spawner.get_items()
	assert_eq(items.size(), 5, "every entry keeps its good stacks")
	var pieces: int = 0
	for item: DroppedItem in items:
		assert_eq(item.get_contents().count(&"scrap"), 2, "%s keeps its material" % item.uid)
		var piece: ItemStack = _piece_in(item.get_contents())
		if piece != null:
			pieces += 1
			assert_eq(item.uid, "good", "only the good piece loads")
			assert_eq(piece.uid, "p3", "with its uid")
	assert_eq(pieces, 1, "the bad piece stacks are lost")
