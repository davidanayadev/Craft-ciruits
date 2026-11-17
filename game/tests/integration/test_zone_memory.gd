extends GutTest
## ZoneMemory (spec 010): keeps what each farm zone had on its visit (boxes
## opened, enemies dead) while it is unloaded and puts it back on loading it
## again in the same visit (R-010-27, R-010-32); a new visit discards it
## (R-010-28). It is saved in the World file (R-010-09), skipping zones that
## the catalog does not know (R-010-11).

const ZONE_SCENE := preload("res://scenes/farm_zone/farm_zone_green.tscn")
const ZOMBIE_SCENE := preload("res://scenes/entities/zombie.tscn")
const KILLER_UID := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const WORLD_SEED := 4242
const VISIT := 1
const UNKNOWN_ZONE := Vector2i(77, 77)

var _memory: ZoneMemory
var _pool: ObjectPool
var _opener: Node3D


func before_each() -> void:
	GameManager.begin_world(Uid.generate(), "", WORLD_SEED, DataRegistry.get_ruleset(&"normal"))
	_memory = ZoneMemory.new()
	add_child_autofree(_memory)
	_pool = ObjectPool.new()
	_pool.scene = ZOMBIE_SCENE
	add_child_autofree(_pool)
	_opener = Node3D.new()
	add_child_autofree(_opener)


func after_each() -> void:
	GameManager.begin_world(Uid.generate(), "", 20261115, DataRegistry.get_ruleset(&"normal"))


## The navigation region is removed: several zones at the same place in one
## map raise edge-merge errors (see test_zombie_spawner.gd).
func _farm(visit: int, state: Dictionary) -> FarmZone:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	zone.get_node("%Navigation").free()
	add_child_autofree(zone)
	zone.populate(WORLD_SEED, visit, _pool, state)
	return zone


func _zone_id(farm: FarmZone) -> Vector2i:
	return farm.data.zone_id


func _open(box: LootBox) -> void:
	var interactable: InteractableComponent = box.get_node("%Interactable") as InteractableComponent
	interactable.interact(_opener)


func _take_first_slot(box: LootBox) -> void:
	var taker: InventoryComponent = InventoryComponent.new()
	add_child_autofree(taker)
	taker.set_slot_count(5)
	var first: Array[int] = [0]
	taker.take_from(box.get_contents(), first)


func _kill(zombie: Zombie) -> void:
	zombie.get_hurtbox().receive_attack(zombie.get_data().hp_max, KILLER_UID)


func _describe_enemies(farm: FarmZone) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for zombie: Zombie in farm.get_enemies():
		lines.append("%s @ %s" % [zombie.get_data().id, zombie.global_position])
	return lines


func _dirty_farm() -> FarmZone:
	var farm: FarmZone = _farm(VISIT, {})
	var boxes: Array[LootBox] = farm.get_boxes()
	assert_gte(boxes.size(), 2, "the zone has boxes")
	_open(boxes[0])
	_open(boxes[1])
	_take_first_slot(boxes[0])
	return farm


func test_r_010_09_save_key() -> void:
	assert_eq(ZoneMemory.SAVE_KEY, &"farm_visits", "constant")
	assert_eq(_memory.get_save_key(), &"farm_visits", "method")


func test_r_010_27_open_boxes_kept() -> void:
	var farm: FarmZone = _dirty_farm()
	var state: Dictionary = farm.get_visit_state()
	var saved_boxes: Array = state["boxes"]
	assert_eq(saved_boxes.size(), 2, "the two opened boxes")
	_memory.bind_farm(farm)
	_memory.unbind_farm()
	farm.despawn_enemies()
	var kept: Dictionary = _memory.take_state(_zone_id(farm), VISIT)
	assert_eq(kept, state, "the state kept is the one the zone had")
	var again: FarmZone = _farm(VISIT, kept)
	var again_state: Dictionary = again.get_visit_state()
	var again_boxes: Array = again_state["boxes"]
	assert_eq(again_boxes, saved_boxes, "same boxes opened, with what was left")
	var opened: int = 0
	for box: LootBox in again.get_boxes():
		if box.is_opened():
			opened += 1
	assert_eq(opened, 2, "no other box is opened")


func test_r_010_27_take_state_forgets_it() -> void:
	var farm: FarmZone = _dirty_farm()
	_memory.bind_farm(farm)
	_memory.unbind_farm()
	var first: Dictionary = _memory.take_state(_zone_id(farm), VISIT)
	assert_false(first.is_empty(), "kept the first time")
	var second: Dictionary = _memory.take_state(_zone_id(farm), VISIT)
	assert_true(second.is_empty(), "forgotten after taking it")


func test_r_010_27_take_state_of_other_visit_or_zone_is_empty() -> void:
	var farm: FarmZone = _dirty_farm()
	_memory.bind_farm(farm)
	_memory.unbind_farm()
	var other_visit: Dictionary = _memory.take_state(_zone_id(farm), VISIT + 1)
	assert_true(other_visit.is_empty(), "another visit")
	var other_zone: Dictionary = _memory.take_state(UNKNOWN_ZONE, VISIT)
	assert_true(other_zone.is_empty(), "another zone")


func test_r_010_28_visit_up_discards_boxes() -> void:
	var farm: FarmZone = _dirty_farm()
	_memory.bind_farm(farm)
	_memory.unbind_farm()
	GameManager.increment_visit_count(_zone_id(farm))
	var new_visit: Dictionary = _memory.take_state(_zone_id(farm), VISIT + 1)
	assert_true(new_visit.is_empty(), "nothing is carried to the new visit")
	var old_visit: Dictionary = _memory.take_state(_zone_id(farm), VISIT)
	assert_true(old_visit.is_empty(), "and the old state is gone")


func test_r_010_28_save_between_rise_and_repopulation_keeps_old_visit() -> void:
	var farm: FarmZone = _dirty_farm()
	var live_state: Dictionary = farm.get_visit_state()
	_memory.bind_farm(farm)
	GameManager.increment_visit_count(_zone_id(farm))
	var data: Dictionary = _memory.to_save_data()
	var zones: Array = data["zones"]
	assert_eq(zones.size(), 1, "the bound farm is saved")
	if zones.size() == 1:
		var entry: Dictionary = zones[0]
		var visit: int = entry["visit"]
		assert_eq(visit, VISIT, "with the visit its boxes belong to")
		var entry_state: Dictionary = entry["state"]
		assert_eq(entry_state, live_state, "and its live state")
	var for_new_visit: Dictionary = _memory.take_state(_zone_id(farm), VISIT + 1)
	assert_true(for_new_visit.is_empty(), "the new visit starts clean")


func test_r_010_32_dead_enemies_stay_dead() -> void:
	var farm: FarmZone = _farm(VISIT, {})
	var before: int = farm.get_enemies().size()
	var lines: PackedStringArray = _describe_enemies(farm)
	_kill(farm.get_enemies()[0])
	await wait_physics_frames(2)
	_memory.bind_farm(farm)
	_memory.unbind_farm()
	farm.despawn_enemies()
	var kept: Dictionary = _memory.take_state(_zone_id(farm), VISIT)
	var again: FarmZone = _farm(VISIT, kept)
	watch_signals(again)
	assert_eq(again.get_enemies().size(), before - 1, "the dead one is not back")
	var expected: PackedStringArray = lines.slice(1)
	assert_eq(_describe_enemies(again), expected, "the others are where they were")
	await wait_physics_frames(2)
	assert_signal_not_emitted(again, "enemy_loot_dropped", "no drop rolled again")


func test_r_010_09_round_trip_zone_memory() -> void:
	var farm: FarmZone = _dirty_farm()
	_kill(farm.get_enemies()[1])
	await wait_physics_frames(2)
	_memory.bind_farm(farm)
	_memory.unbind_farm()
	var saved: Dictionary = _memory.to_save_data()
	var zones: Array = saved["zones"]
	assert_eq(zones.size(), 1, "one zone kept")
	var restored: ZoneMemory = ZoneMemory.new()
	add_child_autofree(restored)
	restored.from_save_data(saved)
	assert_eq(restored.to_save_data(), saved, "same document")


func test_r_010_09_save_data_format() -> void:
	var empty: Dictionary = _memory.to_save_data()
	assert_eq(empty, {"zones": []}, "nothing kept")
	var farm: FarmZone = _dirty_farm()
	_memory.bind_farm(farm)
	var data: Dictionary = _memory.to_save_data()
	var zones: Array = data["zones"]
	assert_eq(zones.size(), 1, "the bound farm counts")
	if zones.size() != 1:
		return
	var entry: Dictionary = zones[0]
	var zone_id: Vector2i = _zone_id(farm)
	var saved_id: Array = entry["zone_id"]
	assert_eq(saved_id, [zone_id.x, zone_id.y], "zone id as two integers")
	var saved_state: Dictionary = entry["state"]
	assert_eq(saved_state, farm.get_visit_state(), "the live state")


func test_r_010_09_load_replaces_and_emits_nothing() -> void:
	var farm: FarmZone = _dirty_farm()
	_memory.bind_farm(farm)
	_memory.unbind_farm()
	watch_signals(EventBus)
	_memory.from_save_data({"zones": []})
	assert_eq(_memory.to_save_data(), {"zones": []}, "what was kept is replaced")
	assert_signal_not_emitted(EventBus, "zone_changed", "loading announces nothing")


func test_r_010_11_unknown_id_skipped() -> void:
	var probe: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	var zone_id: Vector2i = probe.data.zone_id
	probe.free()
	var state: Dictionary = {"boxes": [], "dead_enemies": [1]}
	var data: Dictionary = {
		"zones":
		[
			{"zone_id": [UNKNOWN_ZONE.x, UNKNOWN_ZONE.y], "visit": 0, "state": state},
			{"zone_id": [zone_id.x, zone_id.y], "visit": 2, "state": state},
		]
	}
	_memory.from_save_data(data)
	assert_push_error_count(1)
	var unknown: Dictionary = _memory.take_state(UNKNOWN_ZONE, 0)
	assert_true(unknown.is_empty(), "the unknown zone is not kept")
	var known: Dictionary = _memory.take_state(zone_id, 2)
	assert_eq(known, state, "the known one loads")
