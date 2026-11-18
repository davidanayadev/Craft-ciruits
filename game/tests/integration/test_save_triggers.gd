extends GutTest
## When the World is saved, in the real main scene (spec 010, R-010-38, 39, 42,
## 43, 44, 65). Every test uses a MemorySaveStore (SaveTestSupport), never the
## real saves. The saves are counted two ways: the game_saved facts recorded by
## a listener and the writes the store accepted.
## R-010-38: entering the base saves, and the battery saved is the one it had.
## R-010-39: the save of a recharge comes after the charge is applied.
## R-010-42: a death (saved once the robot reappeared) and a build or a move.
## R-010-43: a request during a travel or the transfer waits for it to end; the
## placement and edit modes change nothing until they are confirmed, so what is
## saved while one is open is the state without the structure, the charge, or
## the move.
## R-010-44: one game_saved per save, with the first reason noted.
## R-010-65: "New world" is ignored during a travel (the branch that reloads
## the scene would replace the one GUT runs in, so it is not tested here).
## R-011-28: crafting and repairing at the bench save once each (spec 011).
## The transfer is driven by advance(), never by real time.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TRAVEL_TIMEOUT_S := 10.0
const GREEN_ZONE_ID := Vector2i(0, 0)
const STATION_CELL := Vector2i(9, 2)
const MOVED_CELL := Vector2i(2, 5)
const SETTLE_FRAMES := 2
const CONSUMED := 30.0
## The robot drains a little between the event and the end of the frame.
const BATTERY_TOLERANCE := 1.0
## Well inside the HUD message time.
const NOTICE_STILL_UP_S := 1.0

var _main: Node
var _store: MemorySaveStore
var _robot: Robot
var _loader: ZoneLoader
var _ui: UIManager
var _structures: BaseStructures
var _transfer: TransferScreen
var _saved: Array[StringName] = []
var _writes_seen: int = 0


func before_each() -> void:
	GameManager.clear_visit_counts()
	_store = SaveTestSupport.start_world()
	_saved = []
	EventBus.game_saved.connect(_on_game_saved)
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)
	_robot = _main.get_node("%Robot") as Robot
	_loader = _main.get_node("%ZoneLoader") as ZoneLoader
	_ui = _main.get_node("%UIManager") as UIManager
	_structures = _main.get_node("%BaseStructures") as BaseStructures
	_transfer = _main.get_node("%TransferScreen") as TransferScreen
	if _loader.is_travelling():
		await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)
	await _settle()
	_forget_saves()


func after_each() -> void:
	if EventBus.game_saved.is_connected(_on_game_saved):
		EventBus.game_saved.disconnect(_on_game_saved)
	GameManager.clear_visit_counts()
	SaveTestSupport.reset()


# --- Helpers ------------------------------------------------------------------


func _on_game_saved(reason: StringName) -> void:
	_saved.append(reason)


## Lets the saves noted in the last frame be resolved.
func _settle() -> void:
	await wait_process_frames(SETTLE_FRAMES)


## What happened before this point is not the test's business.
func _forget_saves() -> void:
	_saved.clear()
	_writes_seen = _store.write_count


func _new_writes() -> int:
	return _store.write_count - _writes_seen


func _base_id() -> Vector2i:
	return DataRegistry.get_base_zone().zone_id


func _travel(zone_id: Vector2i) -> void:
	_loader.travel_to(zone_id)
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)
	await _settle()


func _die() -> void:
	_robot.battery.consume(_robot.battery.get_current())
	await wait_process_frames(SETTLE_FRAMES)


func _station_recipe() -> RecipeData:
	return DataRegistry.get_recipe(&"charging_station")


## Gives the robot the scrap of the recipe and places the station; its uid.
func _place_station() -> String:
	var recipe: RecipeData = _station_recipe()
	_robot.inventory.add(&"scrap", CraftingSystem.cost_of(recipe)[&"scrap"])
	var placed: ActionResult = _structures.place(_robot, recipe, STATION_CELL)
	assert_true(placed.ok, "the station is placed")
	return _structures.structure_at(STATION_CELL)


func _world_file() -> String:
	var ids: PackedStringArray = _store.list_world_ids()
	assert_eq(ids.size(), 1, "exactly one World in the store")
	return "world_" + ids[0] if not ids.is_empty() else ""


func _read_world() -> Dictionary:
	var decoded: Variant = SaveCodec.decode(_store.get_bytes(_world_file(), ISaveStore.Copy.MAIN))
	assert_true(decoded is Dictionary, "the World file holds a document")
	var document: Dictionary = decoded if decoded is Dictionary else {}
	return document


func _saved_player_part(key: String) -> Dictionary:
	var document: Dictionary = _read_world()
	var players: Dictionary = document[SaveDocuments.KEY_PLAYERS]
	var parts: Dictionary = players.get(SaveManager.get_player_uuid(), {})
	var part: Dictionary = parts.get(key, {})
	return part


func _saved_placed() -> Array:
	var document: Dictionary = _read_world()
	var world: Dictionary = document[SaveDocuments.KEY_WORLD]
	var part: Dictionary = world.get(String(BaseStructures.SAVE_KEY), {})
	var placed: Array = part.get("placed", [])
	return placed


func _saved_battery() -> float:
	var part: Dictionary = _saved_player_part("battery")
	var current: float = part.get("current", -1.0)
	return current


func _saved_scrap() -> int:
	var part: Dictionary = _saved_player_part("inventory")
	var slots: Array = part.get("slots", [])
	var total: int = 0
	for entry: Variant in slots:
		if entry is Dictionary:
			var fields: Dictionary = entry
			if str(fields.get("item_id", "")) == "scrap":
				total += SaveFields.to_int(fields.get("quantity"), 0)
	return total


func _screen_of(screen_id: StringName) -> PlacementScreen:
	for child: Node in _ui.get_children():
		var screen: PlacementScreen = child as PlacementScreen
		if screen != null and not screen.is_queued_for_deletion() and screen_id == PlacementScreen.SCREEN_ID:
			return screen
	return null


func _assert_one_save(reason: StringName) -> void:
	assert_eq(_new_writes(), 1, "exactly one write")
	assert_eq(_saved, [reason], "exactly one game_saved, with reason '%s'" % reason)


# --- R-010-38 -----------------------------------------------------------------


func test_r_010_38_entering_base_saves_without_recharge() -> void:
	await _travel(GREEN_ZONE_ID)
	_forget_saves()
	_robot.battery.consume(CONSUMED)
	var before: float = _robot.battery.get_current()
	await _travel(_base_id())
	_assert_one_save(SaveManager.REASON_ENTERED_BASE)
	assert_almost_eq(_saved_battery(), before, BATTERY_TOLERANCE, "the battery as it was before entering")
	assert_lt(_saved_battery(), _robot.battery.get_maximum() - CONSUMED / 2.0, "not the maximum")
	assert_lt(_robot.battery.get_current(), _robot.battery.get_maximum() - CONSUMED / 2.0, "nor was it recharged")


func test_r_010_38_entering_the_green_zone_does_not_save() -> void:
	await _travel(GREEN_ZONE_ID)
	assert_eq(_new_writes(), 0, "no write")
	assert_eq(_saved.size(), 0, "no game_saved")


# --- R-010-39 -----------------------------------------------------------------


func test_r_010_39_recharge_saves_after_recharge() -> void:
	_place_station()
	await _settle()
	_forget_saves()
	_robot.battery.consume(CONSUMED)
	var base: BaseZone = _loader.get_current_zone() as BaseZone
	var station: Node = base.get_structures_root().get_child(0)
	(station.get_node("%Interactable") as InteractableComponent).interact(_robot)
	assert_eq(_new_writes(), 0, "nothing is written during the signal that asks for it")
	await _settle()
	_assert_one_save(SaveManager.REASON_RECHARGED)
	assert_almost_eq(_saved_battery(), _robot.battery.get_maximum(), BATTERY_TOLERANCE, "the recharged battery")


## R-010-62 in the real scene: the station's save reaches the HUD and the
## notice stays up, not replaced or hidden by what else the recharge does.
func test_r_010_62_recharge_shows_game_saved_in_main() -> void:
	_place_station()
	await _settle()
	var message: Label = _main.get_node("%Hud").get_node("%MessageLabel") as Label
	var base: BaseZone = _loader.get_current_zone() as BaseZone
	var station: Node = base.get_structures_root().get_child(0)
	(station.get_node("%Interactable") as InteractableComponent).interact(_robot)
	await _settle()
	assert_true(message.visible, "the notice shows after the recharge")
	assert_eq(message.text, String(Hud.MSG_GAME_SAVED), "and it is the saved one")
	await wait_seconds(NOTICE_STILL_UP_S)
	assert_true(message.visible, "and it is still up a moment later")
	assert_eq(message.text, String(Hud.MSG_GAME_SAVED), "with the same text")


# --- R-010-42 -----------------------------------------------------------------


func test_r_010_42_death_saves_once_after_respawn() -> void:
	await _travel(GREEN_ZONE_ID)
	_forget_saves()
	await _die()
	assert_true(_transfer.is_playing(), "the transfer plays")
	assert_eq(_new_writes(), 0, "nothing is saved while the robot is dead")
	_transfer.advance(_transfer.config.transfer_duration_s)
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)
	await _settle()
	_assert_one_save(SaveManager.REASON_DIED)
	assert_gt(_saved_battery(), 0.0, "the robot is saved alive")
	var location: Dictionary = _saved_player_part("location")
	var zone_id: Variant = SaveFields.to_vector2i(location.get("zone_id"))
	assert_true(zone_id is Vector2i, "a saved zone id")
	assert_eq(zone_id as Vector2i, _base_id(), "in the base")


func test_r_010_42_build_and_move_save() -> void:
	var uid: String = _place_station()
	await _settle()
	_assert_one_save(SaveManager.REASON_STRUCTURE_BUILT)
	assert_eq(_saved_placed().size(), 1, "the station is saved")
	_forget_saves()
	var moved: ActionResult = _structures.move(_robot, uid, MOVED_CELL)
	assert_true(moved.ok, "the station is moved")
	await _settle()
	_assert_one_save(SaveManager.REASON_STRUCTURE_MOVED)
	var placed: Array = _saved_placed()
	assert_eq(placed.size(), 1, "still one structure")
	if placed.size() == 1:
		var entry: Dictionary = placed[0]
		var cell: Variant = SaveFields.to_vector2i(entry.get("cell"))
		assert_true(cell is Vector2i, "a saved cell")
		assert_eq(cell as Vector2i, MOVED_CELL, "on its new cell")


# --- R-010-43 -----------------------------------------------------------------


func test_r_010_43_held_during_travel() -> void:
	# The deferred flush of the request runs before the zone can load, so a
	# write seen up to zone_loaded would have happened during the travel.
	var writes_at_load: Array[int] = []
	var record: Callable = func(_zone: Zone) -> void: writes_at_load.append(_new_writes())
	_loader.zone_loaded.connect(record)
	_loader.travel_to(GREEN_ZONE_ID)
	SaveManager.request_save(SaveManager.REASON_STRUCTURE_BUILT)
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)
	assert_eq(writes_at_load, [0], "no save during the travel")
	await _settle()
	_assert_one_save(SaveManager.REASON_STRUCTURE_BUILT)


func test_r_010_43_held_during_transfer() -> void:
	await _travel(GREEN_ZONE_ID)
	_forget_saves()
	await _die()
	SaveManager.request_save(SaveManager.REASON_STRUCTURE_BUILT)
	await wait_process_frames(SETTLE_FRAMES)
	assert_true(_transfer.is_playing(), "the transfer is still playing")
	assert_eq(_new_writes(), 0, "no save during the transfer")
	_transfer.advance(_transfer.config.transfer_duration_s)
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)
	await _settle()
	_assert_one_save(SaveManager.REASON_DIED)


func test_r_010_43_placement_state_is_cancelled_state() -> void:
	var recipe: RecipeData = _station_recipe()
	var cost: int = CraftingSystem.cost_of(recipe)[&"scrap"]
	_robot.inventory.add(&"scrap", cost)
	_ui.open(
		PlacementScreen.SCREEN_ID,
		{
			PlacementScreen.CONTEXT_PLAYER: _robot,
			PlacementScreen.CONTEXT_BASE: _structures,
			PlacementScreen.CONTEXT_RECIPE: recipe,
		}
	)
	var screen: PlacementScreen = _screen_of(PlacementScreen.SCREEN_ID)
	assert_not_null(screen, "the placement screen is open")
	if screen == null:
		return
	screen.select_cell(STATION_CELL)
	assert_eq(screen.get_mode(), PlacementScreen.Mode.PLACE, "in place mode")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved while placing")
	assert_eq(_saved_placed().size(), 0, "the structure being placed is not saved")
	assert_eq(_saved_scrap(), cost, "nothing was charged")
	assert_eq(_robot.inventory.count(&"scrap"), cost, "nor is it charged in the game")


func test_r_010_43_move_state_is_cancelled_state() -> void:
	var uid: String = _place_station()
	await _settle()
	_ui.open(
		PlacementScreen.SCREEN_ID,
		{PlacementScreen.CONTEXT_PLAYER: _robot, PlacementScreen.CONTEXT_BASE: _structures}
	)
	var screen: PlacementScreen = _screen_of(PlacementScreen.SCREEN_ID)
	assert_not_null(screen, "the edit screen is open")
	if screen == null:
		return
	screen.select_cell(STATION_CELL)
	screen.select_cell(MOVED_CELL)
	assert_eq(screen.get_mode(), PlacementScreen.Mode.MOVE, "in move mode, the target chosen")
	assert_true(SaveManager.save_game(SaveManager.REASON_CLOSE).ok, "saved while moving")
	var placed: Array = _saved_placed()
	assert_eq(placed.size(), 1, "the structure is saved")
	if placed.size() == 1:
		var entry: Dictionary = placed[0]
		var cell: Variant = SaveFields.to_vector2i(entry.get("cell"))
		assert_true(cell is Vector2i, "a saved cell")
		assert_eq(cell as Vector2i, STATION_CELL, "on its old cell")
		assert_eq(str(entry.get("uid", "")), uid, "the same structure")


# --- R-010-44 -----------------------------------------------------------------


func test_r_010_44_one_game_saved_per_save() -> void:
	SaveManager.request_save(SaveManager.REASON_STRUCTURE_MOVED)
	SaveManager.request_save(SaveManager.REASON_ENTERED_BASE)
	SaveManager.request_save(SaveManager.REASON_RECHARGED)
	await _settle()
	_assert_one_save(SaveManager.REASON_STRUCTURE_MOVED)


func test_r_010_44_requests_during_a_hold_are_one_save() -> void:
	SaveManager.hold_saves(&"test_hold")
	SaveManager.request_save(SaveManager.REASON_RECHARGED)
	SaveManager.request_save(SaveManager.REASON_STRUCTURE_BUILT)
	await _settle()
	assert_eq(_new_writes(), 0, "nothing while held")
	SaveManager.release_saves(&"test_hold")
	await _settle()
	_assert_one_save(SaveManager.REASON_RECHARGED)


# --- R-010-65 -----------------------------------------------------------------


func test_r_010_65_new_world_ignored_while_travelling() -> void:
	var world_id: String = GameManager.get_world_id()
	_loader.travel_to(GREEN_ZONE_ID)
	assert_true(_loader.is_travelling(), "travelling")
	(_main.get_node("%DebugHud") as DebugHud).new_world_requested.emit()
	assert_true(SaveManager.has_world(), "the World is still there")
	assert_eq(_store.list_world_ids(), PackedStringArray([world_id]), "and so is its file")
	assert_eq(GameManager.get_world_id(), world_id, "the same World")
	await wait_for_signal(_loader.travel_finished, TRAVEL_TIMEOUT_S)


# --- R-011-28 -----------------------------------------------------------------


## The saved inventory slot that holds piece_uid; empty when none.
func _saved_piece(piece_uid: String) -> Dictionary:
	var part: Dictionary = _saved_player_part("inventory")
	var slots: Array = part.get("slots", [])
	for entry: Variant in slots:
		if entry is Dictionary:
			var fields: Dictionary = entry
			if str(fields.get("uid", "")) == piece_uid:
				return fields
	return {}


func test_r_011_28_craft_and_repair_save() -> void:
	var base: BaseZone = _loader.get_current_zone() as BaseZone
	assert_not_null(base, "the game starts in the base")
	if base == null:
		return
	var bench: RepairBench = base.get_bench()
	var recipe: RecipeData = DataRegistry.get_recipe(&"basic_arms")
	var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
	for item_id: StringName in cost:
		_robot.inventory.add(item_id, cost[item_id])
	assert_true(bench.craft(_robot, recipe).ok, "the arms are crafted")
	await _settle()
	_assert_one_save(SaveManager.REASON_ITEM_CRAFTED)
	var crafted: ItemStack = null
	for stack: ItemStack in _robot.inventory.get_slots():
		if stack != null and stack.item.id == &"basic_arms":
			crafted = stack
	assert_not_null(crafted, "the crafted piece is in the inventory")
	if crafted == null:
		return
	assert_false(_saved_piece(crafted.uid).is_empty(), "the crafted piece is saved with its uid")
	_forget_saves()
	var damaged: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(&"basic_legs"))
	damaged.durability = 40
	var offered: Array[ItemStack] = [damaged]
	assert_true(_robot.inventory.add_stacks(offered).ok, "a damaged piece is injected")
	_robot.inventory.add(&"iron", 2)
	_robot.inventory.add(&"cables", 1)
	assert_true(bench.repair(_robot, damaged.uid).ok, "the legs are repaired")
	await _settle()
	_assert_one_save(SaveManager.REASON_PIECE_REPAIRED)
	var saved: Dictionary = _saved_piece(damaged.uid)
	var durability: int = SaveFields.to_int(saved.get("durability"), -1)
	assert_eq(durability, 100, "the repaired durability is saved")
