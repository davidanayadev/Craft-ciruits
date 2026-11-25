extends GutTest
## EquipmentComponent (spec 015, plan D7, D9, D10, D19): three slots by
## PieceData.SlotType, equip/unequip through InventoryComponent.exchange_slot,
## wear and break, take_slots, and the save. Covers R-015-05, R-015-07 to
## R-015-12, R-015-20, R-015-21, R-015-23, R-015-37, R-015-39 to R-015-41 and
## R-015-53. The repair tests (R-015-30) are task T-015-11.

const CATALOG_PATH := "res://resources/data_catalog.tres"
const ARMS_PATH := "res://resources/pieces/basic_arms.tres"
const LEGS_PATH := "res://resources/pieces/basic_legs.tres"
const CORE_PATH := "res://resources/pieces/basic_core.tres"

## Inventory that reports what a test hands it: a piece the real inventory
## would never hold (it validates every stack it stores).
class FakeInventory:
	extends InventoryComponent
	var fake_slots: Array[ItemStack] = []

	func get_slots() -> Array[ItemStack]:
		return fake_slots

	func get_slot_count() -> int:
		return fake_slots.size()


var _catalog: DataCatalog
var _order: Array[String] = []
var _seen_in_handler: String = "unset"


func before_each() -> void:
	_catalog = load(CATALOG_PATH) as DataCatalog
	_order = []
	_seen_in_handler = "unset"


func _piece(path: String) -> PieceData:
	return load(path) as PieceData


## Empty unless starting is given; the catalog is injected so DataRegistry is not used.
func _equipment(starting: Array[PieceData] = []) -> EquipmentComponent:
	var equipment: EquipmentComponent = EquipmentComponent.new()
	equipment.catalog = _catalog
	equipment.starting_pieces = starting
	add_child_autofree(equipment)
	return equipment


func _all_starting() -> Array[PieceData]:
	return [_piece(ARMS_PATH), _piece(LEGS_PATH), _piece(CORE_PATH)]


func _inventory(slot_count: int) -> InventoryComponent:
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.catalog = _catalog
	add_child_autofree(inventory)
	var result: ActionResult = inventory.set_slot_count(slot_count)
	assert_true(result.ok, "set_slot_count(%d) in the test setup" % slot_count)
	return inventory


## A new piece stack (new uid) with the given durability, put in slot index.
func _put_piece(inventory: InventoryComponent, index: int, path: String, durability: int) -> ItemStack:
	var stack: ItemStack = CraftingSystem.create_result(_piece(path))
	stack.durability = durability
	var result: ActionResult = inventory.exchange_slot(index, stack)
	assert_true(result.ok, "test setup: piece in slot %d" % index)
	return stack


func _put_scrap(inventory: InventoryComponent, index: int) -> void:
	var stack: ItemStack = ItemStack.new(_catalog.get_item(&"scrap"), 1)
	var result: ActionResult = inventory.exchange_slot(index, stack)
	assert_true(result.ok, "test setup: scrap in slot %d" % index)


func _track_order(inventory: InventoryComponent, equipment: EquipmentComponent) -> void:
	inventory.inventory_changed.connect(func() -> void: _order.append("inventory_changed"))
	equipment.equipment_changed.connect(func() -> void: _order.append("equipment_changed"))
	equipment.piece_broken.connect(
		func(_uid: String, _slot: PieceData.SlotType, _piece: PieceData) -> void:
			_order.append("piece_broken")
	)


func _uid_of(equipment: EquipmentComponent, slot: PieceData.SlotType) -> String:
	var stack: ItemStack = equipment.get_piece(slot)
	return "" if stack == null else stack.uid


func _durability_of(equipment: EquipmentComponent, slot: PieceData.SlotType) -> int:
	var stack: ItemStack = equipment.get_piece(slot)
	return -1 if stack == null else stack.durability


func _entry(piece_id: String, durability: Variant, piece_uid: Variant) -> Dictionary:
	return {"item_id": piece_id, "durability": durability, "uid": piece_uid}


func _slots_data(arms: Variant, legs: Variant, core: Variant) -> Dictionary:
	return {"slots": {"arms": arms, "legs": legs, "core": core}}


# --- R-015-07 three slots, own state ---------------------------------------------


func test_r_015_07_three_slots_keep_uid_and_durability() -> void:
	var equipment: EquipmentComponent = _equipment()
	var inventory: InventoryComponent = _inventory(4)
	var arms: ItemStack = _put_piece(inventory, 0, ARMS_PATH, 61)
	var legs: ItemStack = _put_piece(inventory, 1, LEGS_PATH, 62)
	var core: ItemStack = _put_piece(inventory, 2, CORE_PATH, 63)
	for index: int in 3:
		assert_true(equipment.equip_from(inventory, index).ok, "equip slot %d" % index)
	assert_eq(_uid_of(equipment, PieceData.SlotType.ARMS), arms.uid, "arms uid")
	assert_eq(_uid_of(equipment, PieceData.SlotType.LEGS), legs.uid, "legs uid")
	assert_eq(_uid_of(equipment, PieceData.SlotType.CORE), core.uid, "core uid")
	assert_eq(_durability_of(equipment, PieceData.SlotType.ARMS), 61, "arms durability")
	assert_eq(_durability_of(equipment, PieceData.SlotType.LEGS), 62, "legs durability")
	assert_eq(_durability_of(equipment, PieceData.SlotType.CORE), 63, "core durability")
	var pieces: Array[ItemStack] = equipment.get_pieces()
	assert_eq(pieces.size(), 3, "one entry per slot")
	assert_eq(pieces[PieceData.SlotType.LEGS].uid, legs.uid, "indexed by SlotType")


func test_r_015_07_each_component_has_its_own_slots() -> void:
	var first: EquipmentComponent = _equipment()
	var second: EquipmentComponent = _equipment()
	var inventory: InventoryComponent = _inventory(2)
	_put_piece(inventory, 0, ARMS_PATH, 80)
	assert_true(first.equip_from(inventory, 0).ok, "setup: equip")
	assert_not_null(first.get_piece(PieceData.SlotType.ARMS), "the first one has arms")
	assert_null(second.get_piece(PieceData.SlotType.ARMS), "the second one is untouched")
	assert_eq(second.get_modifiers().size(), 0, "and has no modifiers")


func test_r_015_07_get_piece_returns_copies() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var copy: ItemStack = equipment.get_piece(PieceData.SlotType.ARMS)
	copy.durability = 1
	var all: Array[ItemStack] = equipment.get_pieces()
	all[PieceData.SlotType.LEGS].durability = 1
	assert_eq(_durability_of(equipment, PieceData.SlotType.ARMS), 100, "get_piece shares nothing")
	assert_eq(_durability_of(equipment, PieceData.SlotType.LEGS), 100, "get_pieces shares nothing")


func test_r_015_07_has_piece() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var uid: String = _uid_of(equipment, PieceData.SlotType.LEGS)
	assert_true(equipment.has_piece(uid), "an equipped uid")
	assert_false(equipment.has_piece("not-equipped"), "an unknown uid")
	assert_false(equipment.has_piece(""), "the empty uid is never a piece")
	var empty: EquipmentComponent = _equipment()
	assert_false(empty.has_piece(uid), "another component does not have it")
	assert_false(empty.has_piece(""), "nothing equipped, empty uid")


# --- R-015-05 modifiers only of equipped pieces ----------------------------------


func test_r_015_05_get_modifiers_only_equipped() -> void:
	var legs: PieceData = _piece(LEGS_PATH)
	var starting: Array[PieceData] = [legs]
	var equipment: EquipmentComponent = _equipment(starting)
	var modifiers: Array[StatModifier] = equipment.get_modifiers()
	assert_eq(modifiers.size(), legs.modifiers.size(), "only the legs' modifiers")
	for modifier: StatModifier in modifiers:
		assert_true(legs.modifiers.has(modifier), "%s comes from the legs" % modifier.stat)
	assert_eq(_equipment().get_modifiers().size(), 0, "nothing equipped, no modifiers")


func test_r_015_05_modifiers_follow_unequip() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var inventory: InventoryComponent = _inventory(2)
	var all_count: int = equipment.get_modifiers().size()
	var arms_count: int = _piece(ARMS_PATH).modifiers.size()
	assert_true(equipment.unequip_to(inventory, PieceData.SlotType.ARMS).ok, "setup")
	assert_eq(equipment.get_modifiers().size(), all_count - arms_count, "a piece in the inventory changes nothing")


# --- R-015-08 equip ----------------------------------------------------------------


func test_r_015_08_equip_into_empty_slot() -> void:
	var equipment: EquipmentComponent = _equipment()
	var inventory: InventoryComponent = _inventory(3)
	var piece: ItemStack = _put_piece(inventory, 1, ARMS_PATH, 60)
	watch_signals(inventory)
	watch_signals(equipment)
	_track_order(inventory, equipment)
	var result: ActionResult = equipment.equip_from(inventory, 1)
	assert_true(result.ok, "equipped")
	assert_eq(_uid_of(equipment, PieceData.SlotType.ARMS), piece.uid, "same uid")
	assert_eq(_durability_of(equipment, PieceData.SlotType.ARMS), 60, "same durability")
	assert_null(inventory.get_slots()[1], "it left the inventory")
	assert_signal_emit_count(inventory, "inventory_changed", 1, "one inventory_changed")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "one equipment_changed")
	var expected: Array[String] = ["inventory_changed", "equipment_changed"]
	assert_eq(_order, expected, "inventory first, then equipment")


func test_r_015_08_equipment_final_inside_inventory_changed() -> void:
	var equipment: EquipmentComponent = _equipment()
	var inventory: InventoryComponent = _inventory(2)
	var piece: ItemStack = _put_piece(inventory, 0, LEGS_PATH, 77)
	inventory.inventory_changed.connect(
		func() -> void: _seen_in_handler = _uid_of(equipment, PieceData.SlotType.LEGS)
	)
	assert_true(equipment.equip_from(inventory, 0).ok, "equipped")
	assert_eq(_seen_in_handler, piece.uid, "the equipment is already final when the inventory signals")


func test_r_015_08_refused_exchange_restores_slot() -> void:
	var legs: PieceData = _piece(LEGS_PATH)
	var starting: Array[PieceData] = [legs]
	var equipment: EquipmentComponent = _equipment(starting)
	var inventory: InventoryComponent = _inventory(2)
	var spare: ItemStack = _put_piece(inventory, 0, LEGS_PATH, 40)
	var original_uid: String = _uid_of(equipment, PieceData.SlotType.LEGS)
	# The inventory no longer knows the legs' id, so it refuses the swapped-out piece.
	var limited: DataCatalog = DataCatalog.new()
	limited.items.append(_catalog.get_item(&"scrap"))
	inventory.catalog = limited
	watch_signals(inventory)
	watch_signals(equipment)
	var result: ActionResult = equipment.equip_from(inventory, 0)
	assert_push_error("exchange_slot")
	assert_false(result.ok, "the refusal is returned")
	assert_eq(result.error_key, InventoryComponent.ERR_INVALID_REQUEST, "the inventory's refusal")
	assert_eq(_uid_of(equipment, PieceData.SlotType.LEGS), original_uid, "the equipped piece is back")
	assert_eq(_durability_of(equipment, PieceData.SlotType.LEGS), 100, "with its durability")
	assert_eq(inventory.get_slots()[0].uid, spare.uid, "the inventory is unchanged")
	assert_signal_not_emitted(equipment, "equipment_changed")
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- R-015-09 swap -----------------------------------------------------------------


func test_r_015_09_equip_swaps_with_equipped() -> void:
	var legs: PieceData = _piece(LEGS_PATH)
	var starting: Array[PieceData] = [legs]
	var equipment: EquipmentComponent = _equipment(starting)
	var inventory: InventoryComponent = _inventory(3)
	var old_uid: String = _uid_of(equipment, PieceData.SlotType.LEGS)
	var incoming: ItemStack = _put_piece(inventory, 2, LEGS_PATH, 40)
	watch_signals(inventory)
	watch_signals(equipment)
	_track_order(inventory, equipment)
	assert_true(equipment.equip_from(inventory, 2).ok, "swapped")
	assert_eq(_uid_of(equipment, PieceData.SlotType.LEGS), incoming.uid, "the new piece is equipped")
	assert_eq(_durability_of(equipment, PieceData.SlotType.LEGS), 40, "with its durability")
	var returned: ItemStack = inventory.get_slots()[2]
	assert_not_null(returned, "the old piece went to the same slot")
	assert_eq(returned.uid, old_uid, "the old piece's uid")
	assert_eq(returned.durability, 100, "and durability")
	assert_signal_emit_count(inventory, "inventory_changed", 1, "one inventory_changed")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "one equipment_changed")
	var expected: Array[String] = ["inventory_changed", "equipment_changed"]
	assert_eq(_order, expected, "inventory first, then equipment")


# --- R-015-10 unequip ----------------------------------------------------------------


func test_r_015_10_unequip_to_first_empty_slot() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var inventory: InventoryComponent = _inventory(4)
	_put_scrap(inventory, 0)
	_put_scrap(inventory, 1)
	_put_scrap(inventory, 3)
	var uid: String = _uid_of(equipment, PieceData.SlotType.LEGS)
	watch_signals(inventory)
	watch_signals(equipment)
	_track_order(inventory, equipment)
	var result: ActionResult = equipment.unequip_to(inventory, PieceData.SlotType.LEGS)
	assert_true(result.ok, "unequipped")
	assert_null(equipment.get_piece(PieceData.SlotType.LEGS), "the slot is empty")
	var landed: ItemStack = inventory.get_slots()[2]
	assert_not_null(landed, "it went to the first empty slot")
	assert_eq(landed.uid, uid, "same uid")
	assert_eq(landed.durability, 100, "same durability")
	assert_signal_emit_count(inventory, "inventory_changed", 1, "one inventory_changed")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "one equipment_changed")
	var expected: Array[String] = ["inventory_changed", "equipment_changed"]
	assert_eq(_order, expected, "inventory first, then equipment")
	assert_not_null(equipment.get_piece(PieceData.SlotType.ARMS), "the other slots stay")


func test_r_015_10_unequip_core() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var inventory: InventoryComponent = _inventory(2)
	var uid: String = _uid_of(equipment, PieceData.SlotType.CORE)
	assert_true(equipment.unequip_to(inventory, PieceData.SlotType.CORE).ok, "the core can be taken off")
	assert_null(equipment.get_piece(PieceData.SlotType.CORE), "the core slot is empty")
	assert_eq(inventory.get_slots()[0].uid, uid, "the core is in the inventory")


# --- R-015-11 full inventory -----------------------------------------------------------


func test_r_015_11_unequip_full_inventory_refused() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var inventory: InventoryComponent = _inventory(1)
	_put_scrap(inventory, 0)
	var uid: String = _uid_of(equipment, PieceData.SlotType.ARMS)
	watch_signals(inventory)
	watch_signals(equipment)
	var result: ActionResult = equipment.unequip_to(inventory, PieceData.SlotType.ARMS)
	assert_false(result.ok, "refused")
	assert_eq(result.error_key, EquipmentComponent.ERR_NO_FREE_SLOT, "no free slot")
	assert_eq(_uid_of(equipment, PieceData.SlotType.ARMS), uid, "the piece stays equipped")
	assert_eq(inventory.count(&"scrap"), 1, "the inventory is unchanged")
	assert_signal_not_emitted(equipment, "equipment_changed")
	assert_signal_not_emitted(inventory, "inventory_changed")


# --- R-015-12 refusals -------------------------------------------------------------------


func test_r_015_12_equip_material_refused() -> void:
	var equipment: EquipmentComponent = _equipment()
	var inventory: InventoryComponent = _inventory(2)
	_put_scrap(inventory, 0)
	watch_signals(inventory)
	watch_signals(equipment)
	var result: ActionResult = equipment.equip_from(inventory, 0)
	assert_false(result.ok, "a material is not a piece")
	assert_eq(result.error_key, EquipmentComponent.ERR_NOT_A_PIECE, "ERR_NOT_A_PIECE")
	assert_eq(inventory.count(&"scrap"), 1, "the scrap stays")
	assert_signal_not_emitted(equipment, "equipment_changed")
	assert_signal_not_emitted(inventory, "inventory_changed")


func test_r_015_12_equip_invalid_piece_refused() -> void:
	var equipment: EquipmentComponent = _equipment()
	var fake: FakeInventory = autofree(FakeInventory.new())
	var no_uid: ItemStack = ItemStack.new(_piece(ARMS_PATH), 1)
	no_uid.durability = 50
	var broken: ItemStack = CraftingSystem.create_result(_piece(ARMS_PATH))
	broken.durability = 0
	fake.fake_slots = [no_uid, broken]
	watch_signals(equipment)
	for index: int in 2:
		var result: ActionResult = equipment.equip_from(fake, index)
		assert_false(result.ok, "invalid piece %d refused" % index)
		assert_eq(result.error_key, EquipmentComponent.ERR_NOT_A_PIECE, "ERR_NOT_A_PIECE for %d" % index)
	assert_null(equipment.get_piece(PieceData.SlotType.ARMS), "nothing was equipped")
	assert_signal_not_emitted(equipment, "equipment_changed")


func test_r_015_12_empty_slot_refused() -> void:
	var equipment: EquipmentComponent = _equipment()
	var inventory: InventoryComponent = _inventory(2)
	watch_signals(equipment)
	var result: ActionResult = equipment.equip_from(inventory, 0)
	assert_false(result.ok, "an empty inventory slot")
	assert_eq(result.error_key, EquipmentComponent.ERR_NOT_A_PIECE, "ERR_NOT_A_PIECE")
	var empty_slot: ActionResult = equipment.unequip_to(inventory, PieceData.SlotType.ARMS)
	assert_false(empty_slot.ok, "an empty equipment slot")
	assert_eq(empty_slot.error_key, EquipmentComponent.ERR_SLOT_EMPTY, "ERR_SLOT_EMPTY")
	assert_signal_not_emitted(equipment, "equipment_changed")


func test_r_015_12_bad_index_or_null_inventory_invalid_request() -> void:
	var equipment: EquipmentComponent = _equipment()
	var inventory: InventoryComponent = _inventory(2)
	watch_signals(equipment)
	var out_of_range: ActionResult = equipment.equip_from(inventory, 2)
	assert_push_error_count(1)
	assert_false(out_of_range.ok, "index out of range")
	assert_eq(out_of_range.error_key, ActionResult.ERR_INVALID_REQUEST, "ERR_INVALID_REQUEST")
	var negative: ActionResult = equipment.equip_from(inventory, -1)
	assert_push_error_count(2)
	assert_eq(negative.error_key, ActionResult.ERR_INVALID_REQUEST, "negative index")
	var no_inventory: ActionResult = equipment.equip_from(null, 0)
	assert_push_error_count(3)
	assert_eq(no_inventory.error_key, ActionResult.ERR_INVALID_REQUEST, "null inventory")
	assert_signal_not_emitted(equipment, "equipment_changed")


# --- R-015-20, R-015-21 wear ----------------------------------------------------------------


func test_r_015_20_equal_pieces_wear_separately() -> void:
	var first: EquipmentComponent = _equipment(_all_starting())
	var second: EquipmentComponent = _equipment(_all_starting())
	assert_ne(
		_uid_of(first, PieceData.SlotType.ARMS), _uid_of(second, PieceData.SlotType.ARMS),
		"equal pieces have their own uid"
	)
	first.apply_hit_wear(5.0)
	assert_eq(_durability_of(first, PieceData.SlotType.ARMS), 95, "the hit piece wore")
	assert_eq(_durability_of(second, PieceData.SlotType.ARMS), 100, "its equal did not")


func test_r_015_21_hit_wears_only_first_piece() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	watch_signals(equipment)
	equipment.apply_hit_wear(5.0)
	assert_eq(_durability_of(equipment, PieceData.SlotType.ARMS), 95, "arms first")
	assert_eq(_durability_of(equipment, PieceData.SlotType.LEGS), 100, "legs untouched")
	assert_eq(_durability_of(equipment, PieceData.SlotType.CORE), 100, "core untouched")
	assert_signal_emit_count(equipment, "durability_changed", 1, "one piece wore")
	assert_signal_not_emitted(equipment, "equipment_changed")


func test_r_015_21_next_piece_when_arms_missing() -> void:
	var starting: Array[PieceData] = [_piece(LEGS_PATH), _piece(CORE_PATH)]
	var equipment: EquipmentComponent = _equipment(starting)
	equipment.apply_hit_wear(5.0)
	assert_eq(_durability_of(equipment, PieceData.SlotType.LEGS), 95, "legs wear without arms")
	assert_eq(_durability_of(equipment, PieceData.SlotType.CORE), 100, "core untouched")
	var only_core: Array[PieceData] = [_piece(CORE_PATH)]
	var core_only: EquipmentComponent = _equipment(only_core)
	core_only.apply_hit_wear(5.0)
	assert_eq(_durability_of(core_only, PieceData.SlotType.CORE), 95, "core wears last")


func test_r_015_21_nothing_equipped_no_signal() -> void:
	var equipment: EquipmentComponent = _equipment()
	watch_signals(equipment)
	equipment.apply_hit_wear(5.0)
	assert_signal_not_emitted(equipment, "durability_changed")
	assert_signal_not_emitted(equipment, "equipment_changed")
	assert_signal_not_emitted(equipment, "piece_broken")


# --- R-015-23 break --------------------------------------------------------------------------


func test_r_015_23_piece_breaks_at_zero() -> void:
	var arms: PieceData = _piece(ARMS_PATH)
	var starting: Array[PieceData] = [arms]
	var equipment: EquipmentComponent = _equipment(starting)
	var inventory: InventoryComponent = _inventory(2)
	var uid: String = _uid_of(equipment, PieceData.SlotType.ARMS)
	equipment.apply_hit_wear(float(arms.durability_max - 5))
	assert_eq(_durability_of(equipment, PieceData.SlotType.ARMS), 5, "setup: 5 left")
	watch_signals(equipment)
	_track_order(inventory, equipment)
	equipment.apply_hit_wear(5.0)
	assert_null(equipment.get_piece(PieceData.SlotType.ARMS), "the slot is empty")
	assert_false(equipment.has_piece(uid), "the piece is gone")
	assert_true(inventory.is_empty(), "it does not go to the inventory")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "one equipment_changed")
	assert_signal_emit_count(equipment, "piece_broken", 1, "one piece_broken")
	assert_signal_not_emitted(equipment, "durability_changed")
	var expected: Array[String] = ["equipment_changed", "piece_broken"]
	assert_eq(_order, expected, "equipment_changed first, then piece_broken")
	var params: Array = get_signal_parameters(equipment, "piece_broken", 0)
	var broken_uid: String = params[0] as String
	var broken_slot: int = params[1] as int
	var broken_piece: PieceData = params[2] as PieceData
	assert_eq(broken_uid, uid, "the broken piece's uid")
	assert_eq(broken_slot, PieceData.SlotType.ARMS as int, "its slot")
	assert_eq(broken_piece, arms, "its data")


func test_r_015_23_leftover_does_not_pass_on() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	equipment.apply_hit_wear(250.0)
	assert_null(equipment.get_piece(PieceData.SlotType.ARMS), "the arms broke")
	assert_eq(_durability_of(equipment, PieceData.SlotType.LEGS), 100, "the extra wear is lost")
	assert_eq(_durability_of(equipment, PieceData.SlotType.CORE), 100, "core untouched")


# --- R-015-53 durability signal ----------------------------------------------------------------


func test_r_015_53_wear_emits_durability_changed() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	watch_signals(equipment)
	equipment.apply_hit_wear(5.0)
	assert_signal_emit_count(equipment, "durability_changed", 1, "one signal")
	var params: Array = get_signal_parameters(equipment, "durability_changed", 0)
	var slot: int = params[0] as int
	var durability: int = params[1] as int
	assert_eq(slot, PieceData.SlotType.ARMS as int, "the worn slot")
	assert_eq(durability, 95, "its new durability")
	assert_signal_not_emitted(equipment, "piece_broken")


# --- take_slots (death, D12) --------------------------------------------------------------------


func test_take_slots_returns_copies_and_emits_once() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var arms_uid: String = _uid_of(equipment, PieceData.SlotType.ARMS)
	var legs_uid: String = _uid_of(equipment, PieceData.SlotType.LEGS)
	equipment.apply_hit_wear(30.0)
	watch_signals(equipment)
	var slots: Array[PieceData.SlotType] = [PieceData.SlotType.ARMS, PieceData.SlotType.LEGS]
	var taken: Array[ItemStack] = equipment.take_slots(slots)
	assert_eq(taken.size(), 2, "both pieces returned")
	var uids: Array[String] = []
	for stack: ItemStack in taken:
		uids.append(stack.uid)
		if stack.uid == arms_uid:
			assert_eq(stack.durability, 70, "the worn durability travels with it")
		assert_true(stack.item is PieceData, "the item is the piece's data")
	assert_true(uids.has(arms_uid) and uids.has(legs_uid), "the right uids")
	assert_null(equipment.get_piece(PieceData.SlotType.ARMS), "arms removed")
	assert_null(equipment.get_piece(PieceData.SlotType.LEGS), "legs removed")
	assert_not_null(equipment.get_piece(PieceData.SlotType.CORE), "core stays")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "one signal for all")
	assert_signal_not_emitted(equipment, "piece_broken")


func test_take_slots_nothing_to_take_no_signal() -> void:
	var starting: Array[PieceData] = [_piece(LEGS_PATH)]
	var equipment: EquipmentComponent = _equipment(starting)
	watch_signals(equipment)
	var none: Array[PieceData.SlotType] = []
	assert_eq(equipment.take_slots(none).size(), 0, "empty list")
	var empty_slots: Array[PieceData.SlotType] = [PieceData.SlotType.ARMS, PieceData.SlotType.CORE]
	assert_eq(equipment.take_slots(empty_slots).size(), 0, "already empty slots")
	assert_signal_not_emitted(equipment, "equipment_changed")
	assert_not_null(equipment.get_piece(PieceData.SlotType.LEGS), "legs untouched")


# --- R-015-37 save --------------------------------------------------------------------------------


func test_r_015_37_save_data_per_slot() -> void:
	var starting: Array[PieceData] = [_piece(LEGS_PATH), _piece(CORE_PATH)]
	var equipment: EquipmentComponent = _equipment(starting)
	assert_eq(equipment.get_save_key(), &"equipment", "save key")
	var data: Dictionary = equipment.to_save_data()
	var slots: Dictionary = data.get("slots", {}) as Dictionary
	assert_true(slots.has("arms") and slots.has("legs") and slots.has("core"), "one key per slot")
	var arms: Variant = slots.get("arms")
	assert_true(arms == null, "an empty slot saves null")
	var legs: Dictionary = slots.get("legs", {}) as Dictionary
	var legs_id: String = legs.get("item_id", "")
	var legs_durability: int = legs.get("durability", -1)
	var legs_uid: String = legs.get("uid", "")
	assert_eq(legs_id, "basic_legs", "item id as text")
	assert_eq(legs_durability, 100, "durability")
	assert_eq(legs_uid, _uid_of(equipment, PieceData.SlotType.LEGS), "uid")
	var core: Dictionary = slots.get("core", {}) as Dictionary
	var core_id: String = core.get("item_id", "")
	assert_eq(core_id, "basic_core", "core item id")


func test_r_015_37_round_trip() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	equipment.apply_hit_wear(28.0)
	var data: Dictionary = equipment.to_save_data()
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	var through_json: Dictionary = parsed as Dictionary
	var loaded: EquipmentComponent = _equipment()
	loaded.from_save_data(through_json)
	for index: int in 3:
		var slot: PieceData.SlotType = index as PieceData.SlotType
		assert_eq(_uid_of(loaded, slot), _uid_of(equipment, slot), "uid of slot %d" % slot)
		assert_eq(_durability_of(loaded, slot), _durability_of(equipment, slot), "durability of slot %d" % slot)
	assert_eq(_durability_of(loaded, PieceData.SlotType.ARMS), 72, "the worn durability came back as a whole number")
	var piece: ItemStack = loaded.get_piece(PieceData.SlotType.ARMS)
	assert_same(piece.item, _catalog.get_item(&"basic_arms"), "the item is the catalog's")


func test_r_015_37_save_has_no_stats() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var slots: Dictionary = equipment.to_save_data().get("slots", {}) as Dictionary
	var entry: Dictionary = slots.get("arms", {}) as Dictionary
	var keys: Array = entry.keys()
	keys.sort()
	assert_eq(keys, ["durability", "item_id", "uid"], "only id, durability and uid are saved")


# --- R-015-39 load emits state ---------------------------------------------------------------------


func test_r_015_39_load_emits_state_never_broken() -> void:
	var source: EquipmentComponent = _equipment(_all_starting())
	var data: Dictionary = source.to_save_data()
	var target: EquipmentComponent = _equipment()
	watch_signals(target)
	target.from_save_data(data)
	assert_signal_emit_count(target, "equipment_changed", 1, "one state signal")
	assert_signal_not_emitted(target, "piece_broken")
	assert_signal_not_emitted(target, "durability_changed")
	var dead: Dictionary = _slots_data(null, null, null)
	target.from_save_data(dead)
	assert_signal_emit_count(target, "equipment_changed", 2, "also when it loads empty")
	assert_signal_not_emitted(target, "piece_broken")
	assert_null(target.get_piece(PieceData.SlotType.ARMS), "the slots were replaced")


func test_r_015_39_load_float_durability() -> void:
	var equipment: EquipmentComponent = _equipment()
	var data: Dictionary = _slots_data(_entry("basic_arms", 72.0, "u-arms"), null, null)
	equipment.from_save_data(data)
	assert_eq(_durability_of(equipment, PieceData.SlotType.ARMS), 72, "72.0 from JSON is 72")
	assert_eq(_uid_of(equipment, PieceData.SlotType.ARMS), "u-arms", "uid")


# --- R-015-40 bad entries -----------------------------------------------------------------------------


func test_r_015_40_bad_entries_load_empty() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var data: Dictionary = _slots_data(
		_entry("ghost", 50, "u1"),
		_entry("scrap", 1, "u2"),
		_entry("basic_arms", 50, "u3"),
	)
	watch_signals(equipment)
	equipment.from_save_data(data)
	assert_push_error_count(3)
	assert_null(equipment.get_piece(PieceData.SlotType.ARMS), "unknown id: empty")
	assert_null(equipment.get_piece(PieceData.SlotType.LEGS), "a material: empty")
	assert_null(equipment.get_piece(PieceData.SlotType.CORE), "a piece of another slot: empty")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "still one state signal")


func test_r_015_40_bad_durability_or_uid_load_empty() -> void:
	var bad_entries: Array[Dictionary] = [
		_entry("basic_arms", 0, "u1"),
		_entry("basic_arms", -3, "u1"),
		_entry("basic_arms", 101, "u1"),
		_entry("basic_arms", 50.5, "u1"),
		_entry("basic_arms", "50", "u1"),
		_entry("basic_arms", 50, ""),
		_entry("basic_arms", 50, 7),
	]
	var errors: int = 0
	for entry: Dictionary in bad_entries:
		var equipment: EquipmentComponent = _equipment()
		equipment.from_save_data(_slots_data(entry, null, null))
		errors += 1
		assert_push_error_count(errors)
		assert_null(equipment.get_piece(PieceData.SlotType.ARMS), "bad entry %s loads empty" % entry)


func test_r_015_40_good_entry_loads_beside_bad_one() -> void:
	var equipment: EquipmentComponent = _equipment()
	var data: Dictionary = _slots_data(_entry("basic_arms", 40, "u-arms"), _entry("ghost", 40, "u2"), null)
	equipment.from_save_data(data)
	assert_push_error_count(1)
	assert_eq(_uid_of(equipment, PieceData.SlotType.ARMS), "u-arms", "the good slot loads")
	assert_null(equipment.get_piece(PieceData.SlotType.LEGS), "the bad one is empty")


func test_r_015_40_missing_slots_dictionary_no_change() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	var uid: String = _uid_of(equipment, PieceData.SlotType.ARMS)
	watch_signals(equipment)
	var no_slots: Dictionary = {}
	equipment.from_save_data(no_slots)
	assert_push_error_count(1)
	var not_a_dictionary: Dictionary = {"slots": [1, 2, 3]}
	equipment.from_save_data(not_a_dictionary)
	assert_push_error_count(2)
	assert_eq(_uid_of(equipment, PieceData.SlotType.ARMS), uid, "no change")
	assert_signal_not_emitted(equipment, "equipment_changed")


func test_r_015_40_missing_slot_key_loads_empty() -> void:
	var equipment: EquipmentComponent = _equipment(_all_starting())
	watch_signals(equipment)
	var data: Dictionary = {"slots": {"arms": _entry("basic_arms", 40, "u-arms")}}
	equipment.from_save_data(data)
	assert_eq(_uid_of(equipment, PieceData.SlotType.ARMS), "u-arms", "the listed slot loads")
	assert_null(equipment.get_piece(PieceData.SlotType.LEGS), "a missing key is an empty slot")
	assert_null(equipment.get_piece(PieceData.SlotType.CORE), "also the core")
	assert_signal_emit_count(equipment, "equipment_changed", 1, "one state signal, no error")


# --- R-015-41 new game ------------------------------------------------------------------------------------


func test_r_015_41_new_component_starting_pieces() -> void:
	var equipment: EquipmentComponent = EquipmentComponent.new()
	equipment.catalog = _catalog
	var starting: Array[PieceData] = [_piece(LEGS_PATH), _piece(CORE_PATH)]
	equipment.starting_pieces = starting
	watch_signals(equipment)
	add_child_autofree(equipment)
	assert_null(equipment.get_piece(PieceData.SlotType.ARMS), "no arms in a new game")
	var legs: ItemStack = equipment.get_piece(PieceData.SlotType.LEGS)
	var core: ItemStack = equipment.get_piece(PieceData.SlotType.CORE)
	assert_not_null(legs, "legs equipped")
	assert_not_null(core, "core equipped")
	assert_eq(legs.item.id, &"basic_legs", "the legs piece")
	assert_eq(core.item.id, &"basic_core", "the core piece")
	assert_eq(legs.durability, _piece(LEGS_PATH).durability_max, "full durability")
	assert_eq(core.durability, _piece(CORE_PATH).durability_max, "full durability")
	assert_false(legs.uid.is_empty(), "a uid")
	assert_ne(legs.uid, core.uid, "each piece has its own uid")
	assert_signal_not_emitted(equipment, "equipment_changed")
	assert_signal_not_emitted(equipment, "piece_broken")


func test_r_015_41_no_starting_pieces_all_empty() -> void:
	var equipment: EquipmentComponent = _equipment()
	for stack: ItemStack in equipment.get_pieces():
		assert_null(stack, "every slot starts empty without starting pieces")


# --- R-015-30 repair ------------------------------------------------------------


func _repair_costs() -> RepairCostData:
	return load("res://resources/config/repair_costs.tres") as RepairCostData


func _payer_with(iron: int, cables: int) -> InventoryComponent:
	var payer: InventoryComponent = InventoryComponent.new()
	payer.catalog = load("res://resources/data_catalog.tres") as DataCatalog
	add_child_autofree(payer)
	payer.set_slot_count(5)
	if iron > 0:
		payer.add(&"iron", iron)
	if cables > 0:
		payer.add(&"cables", cables)
	return payer


func test_r_015_30_repair_equipped_keeps_it_equipped() -> void:
	var equipment: EquipmentComponent = _equipment([_piece(LEGS_PATH), _piece(CORE_PATH)])
	equipment.apply_hit_wear(50.0)
	var legs: ItemStack = equipment.get_piece(PieceData.SlotType.LEGS)
	var payer: InventoryComponent = _payer_with(2, 1)
	var seen_in_payer_signal: Array[int] = []
	payer.inventory_changed.connect(
		func() -> void: seen_in_payer_signal.append(equipment.get_piece(PieceData.SlotType.LEGS).durability)
	)
	watch_signals(equipment)
	var result: ActionResult = equipment.repair(legs.uid, payer, _repair_costs())
	assert_true(result.ok, "repaired")
	var repaired: ItemStack = equipment.get_piece(PieceData.SlotType.LEGS)
	assert_eq(repaired.uid, legs.uid, "same uid, still equipped")
	assert_eq(repaired.durability, (legs.item as PieceData).durability_max, "at its maximum")
	assert_eq(payer.count(&"iron"), 0, "the damaged tier was paid (BALANCE §4.3.2)")
	assert_eq(payer.count(&"cables"), 0, "the damaged tier was paid (BALANCE §4.3.2)")
	assert_eq(seen_in_payer_signal, [100] as Array[int], "repaired before the payer reports")
	assert_signal_emit_count(equipment, "durability_changed", 1, "one state signal")
	assert_signal_not_emitted(equipment, "equipment_changed", "the slots did not change")


func test_r_015_30_repair_refused_changes_nothing() -> void:
	var equipment: EquipmentComponent = _equipment([_piece(LEGS_PATH), _piece(CORE_PATH)])
	equipment.apply_hit_wear(50.0)
	var legs: ItemStack = equipment.get_piece(PieceData.SlotType.LEGS)
	var payer: InventoryComponent = _payer_with(0, 0)
	watch_signals(equipment)
	var poor: ActionResult = equipment.repair(legs.uid, payer, _repair_costs())
	assert_eq(poor.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS, "nothing to pay with")
	var core: ItemStack = equipment.get_piece(PieceData.SlotType.CORE)
	var intact: ActionResult = equipment.repair(core.uid, payer, _repair_costs())
	assert_eq(intact.error_key, CraftingSystem.ERR_PIECE_INTACT, "an intact piece")
	var unknown: ActionResult = equipment.repair("nope", payer, _repair_costs())
	assert_eq(unknown.error_key, CraftingSystem.ERR_PIECE_NOT_FOUND, "an unknown uid")
	assert_push_error("nope")
	assert_eq(equipment.get_piece(PieceData.SlotType.LEGS).durability, legs.durability, "unchanged")
	assert_signal_not_emitted(equipment, "durability_changed", "no change, no signal")
