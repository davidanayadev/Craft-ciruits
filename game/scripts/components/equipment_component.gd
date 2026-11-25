class_name EquipmentComponent
extends Node
## The equipment slots of one robot (spec 015, architecture §9.3): arms, legs
## and core, each empty or holding one piece ItemStack with its uid and
## durability (R-015-07). Per-player state (constitution P4), never in an
## autoload. Only owner and writer of what is equipped: equipping and
## unequipping ask the inventory to write its own slot (plan 015 D7), and the
## wear of a hit is decided by DegradationSystem (plan 015 D9).
##
## Every change is complete before its signal: a listener of the inventory's
## inventory_changed already sees the final equipment, never the same piece in
## both places, and equipment_changed comes after it.

## State: the slots changed (equip, unequip, swap, break, death, load). Once per operation.
signal equipment_changed
## State: a piece lost durability without breaking, or was repaired (R-015-53).
signal durability_changed(slot: PieceData.SlotType, durability: int)
## Fact: a piece broke and is gone (R-015-23). After equipment_changed; never on load.
## It carries the PieceData because the piece no longer exists anywhere (plan 015 D10).
signal piece_broken(piece_uid: String, slot: PieceData.SlotType, piece: PieceData)

const ERR_NOT_A_PIECE := &"ERR_NOT_A_PIECE"
const ERR_NO_FREE_SLOT := &"ERR_NO_FREE_SLOT"
const ERR_SLOT_EMPTY := &"ERR_SLOT_EMPTY"
## Save contract (spec 010, architecture §10.2).
const SAVE_KEY := &"equipment"
const _SLOTS_KEY := "slots"
## Save key of each slot, indexed by PieceData.SlotType.
const _SLOT_KEYS: Array[String] = ["arms", "legs", "core"]

## New-game state, put on in _ready(): BALANCE §4.2 "Equipo inicial" (plan 015 D19).
## SaveManager replaces it when the World has an equipment part (R-015-42).
@export var starting_pieces: Array[PieceData] = []

## Validates ids on load and on equip; DataRegistry's catalog when left null at _ready().
var catalog: DataCatalog = null

var _pieces: Array[ItemStack] = []


func _init() -> void:
	_pieces.resize(PieceData.SlotType.size())


func _ready() -> void:
	if catalog == null:
		catalog = DataRegistry.get_catalog()
	for piece: PieceData in starting_pieces:
		if piece == null or not _is_slot(piece.slot_type):
			push_error("EquipmentComponent '%s': an invalid starting piece is skipped." % name)
			continue
		_pieces[piece.slot_type] = CraftingSystem.create_result(piece)


## Copy of the piece in slot, or null.
func get_piece(slot: PieceData.SlotType) -> ItemStack:
	if not _is_slot(slot):
		push_error("EquipmentComponent '%s': get_piece() of unknown slot %d." % [name, slot])
		return null
	return null if _pieces[slot] == null else _pieces[slot].copy()


## Copies indexed by SlotType, null for empty.
func get_pieces() -> Array[ItemStack]:
	var copies: Array[ItemStack] = []
	for piece: ItemStack in _pieces:
		copies.append(null if piece == null else piece.copy())
	return copies


func has_piece(piece_uid: String) -> bool:
	return InventoryRules.index_of_uid(_pieces, piece_uid) >= 0


## Modifiers of the equipped pieces only (R-015-05), in slot order.
func get_modifiers() -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	for piece: ItemStack in _pieces:
		if piece != null:
			modifiers.append_array((piece.item as PieceData).modifiers)
	return modifiers


## Equips the piece in inventory's slot_index (R-015-08); what was equipped in
## its slot goes to that inventory slot (R-015-09). An empty slot, a stack that
## is not a valid piece → ERR_NOT_A_PIECE (R-015-12). No inventory or a bad
## index → push_error, ERR_INVALID_REQUEST. A refusal of the inventory → its
## result. No change and no signal on any refusal.
func equip_from(inventory: InventoryComponent, slot_index: int) -> ActionResult:
	if inventory == null or slot_index < 0 or slot_index >= inventory.get_slot_count():
		push_error("EquipmentComponent '%s': equip_from() got no inventory or slot %d." % [name, slot_index])
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var incoming: ItemStack = _as_equippable(inventory.get_slots()[slot_index])
	if incoming == null:
		return ActionResult.failure(ERR_NOT_A_PIECE)
	var slot: int = (incoming.item as PieceData).slot_type
	var previous: ItemStack = _pieces[slot]
	_pieces[slot] = incoming
	var exchanged: ActionResult = inventory.exchange_slot(slot_index, previous)
	if not exchanged.ok:
		_pieces[slot] = previous
		return exchanged
	equipment_changed.emit()
	return ActionResult.success()


## Sends the piece of slot to the first empty slot of inventory (R-015-10). An
## empty slot → ERR_SLOT_EMPTY; no empty inventory slot → ERR_NO_FREE_SLOT
## (R-015-11). No inventory or a bad slot → push_error, ERR_INVALID_REQUEST. No
## change and no signal on any refusal.
func unequip_to(inventory: InventoryComponent, slot: PieceData.SlotType) -> ActionResult:
	if inventory == null or not _is_slot(slot):
		push_error("EquipmentComponent '%s': unequip_to() got no inventory or slot %d." % [name, slot])
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var piece: ItemStack = _pieces[slot]
	if piece == null:
		return ActionResult.failure(ERR_SLOT_EMPTY)
	var slots: Array[ItemStack] = inventory.get_slots()
	if InventoryRules.count_used_slots(slots) >= slots.size():
		return ActionResult.failure(ERR_NO_FREE_SLOT)
	_pieces[slot] = null
	var added: InventoryAddResult = inventory.add_stacks([piece])
	if not added.ok:
		_pieces[slot] = piece
		return ActionResult.failure(added.error_key)
	equipment_changed.emit()
	return ActionResult.success()


## A hit received wears the first equipped piece of DegradationSystem.WEAR_ORDER
## by wear (R-015-21): durability_changed while some is left (R-015-53); at 0
## or below it breaks and is gone, equipment_changed then piece_broken, and
## the rest of the wear is lost (R-015-23). Nothing equipped → no change (R-015-22).
func apply_hit_wear(wear: float) -> void:
	var slot: int = DegradationSystem.target_slot(_pieces)
	if slot == DegradationSystem.NO_SLOT:
		return
	var piece: ItemStack = _pieces[slot]
	var durability: int = DegradationSystem.durability_after_hit(piece.durability, wear)
	if durability == piece.durability:
		return
	if durability > 0:
		piece.durability = durability
		durability_changed.emit(slot, durability)
		return
	_pieces[slot] = null
	equipment_changed.emit()
	piece_broken.emit(piece.uid, slot, piece.item as PieceData)


## Removes these slots and returns their pieces, with uid and durability
## (death, plan 015 D12). One equipment_changed when any was taken.
func take_slots(slots: Array[PieceData.SlotType]) -> Array[ItemStack]:
	var taken: Array[ItemStack] = []
	for slot: PieceData.SlotType in slots:
		if not _is_slot(slot):
			push_error("EquipmentComponent '%s': take_slots() of unknown slot %d." % [name, slot])
		elif _pieces[slot] != null:
			taken.append(_pieces[slot])
			_pieces[slot] = null
	if not taken.is_empty():
		equipment_changed.emit()
	return taken


## Repairs the equipped piece piece_uid to its maximum durability, paid from
## payer's inventory as for an inventory piece (R-015-30, plan 015 D16); it
## stays equipped with its uid. Unknown uid → push_error,
## CraftingSystem.ERR_PIECE_NOT_FOUND; any other CraftingSystem.check_repair_stack
## refusal → its key; no change either way. No payer or costs → push_error,
## ERR_INVALID_REQUEST. durability_changed when done.
func repair(piece_uid: String, payer: InventoryComponent, costs: RepairCostData) -> ActionResult:
	if payer == null or costs == null:
		push_error("EquipmentComponent '%s': repair() needs a payer and repair costs." % name)
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var slot: int = InventoryRules.index_of_uid(_pieces, piece_uid)
	if slot < 0:
		push_error("EquipmentComponent '%s': no equipped piece with uid '%s' to repair." % [name, piece_uid])
		return ActionResult.failure(CraftingSystem.ERR_PIECE_NOT_FOUND)
	var piece: ItemStack = _pieces[slot]
	var checked: ActionResult = CraftingSystem.check_repair_stack(piece, payer.get_slots(), costs)
	if not checked.ok:
		return checked
	var cost: Dictionary[StringName, int] = CraftingSystem.repair_cost(piece, costs)
	var old_durability: int = piece.durability
	# Written first, so a listener of the payer's inventory_changed sees it repaired.
	piece.durability = (piece.item as PieceData).durability_max
	var paid: ActionResult = payer.remove_many(cost)
	if not paid.ok:
		piece.durability = old_durability
		return paid
	durability_changed.emit(slot, piece.durability)
	return ActionResult.success()


func get_save_key() -> StringName:
	return SAVE_KEY


## Per slot, the piece's item id, durability and uid, or null; nothing derived
## (R-015-37).
func to_save_data() -> Dictionary:
	var slots: Dictionary = {}
	for slot: int in _pieces.size():
		var piece: ItemStack = _pieces[slot]
		slots[_SLOT_KEYS[slot]] = null if piece == null else {
			"item_id": String(piece.item.id),
			"durability": piece.durability,
			"uid": piece.uid,
		}
	return {_SLOTS_KEY: slots}


## Replaces the three slots; a missing slot loads empty, a bad entry loads
## empty with push_error and the rest loads (R-015-40). equipment_changed once,
## never piece_broken (R-015-39). No slot dictionary → push_error, no change.
func from_save_data(data: Dictionary) -> void:
	var saved: Variant = data.get(_SLOTS_KEY)
	if not saved is Dictionary:
		push_error("EquipmentComponent '%s': no saved slots in %s; no change." % [name, data])
		return
	var entries: Dictionary = saved
	var loaded: Array[ItemStack] = []
	for slot: int in _pieces.size():
		loaded.append(_piece_from_save(entries.get(_SLOT_KEYS[slot]), slot))
	_pieces = loaded
	equipment_changed.emit()


## A copy of stack with the catalog's item when it is a valid piece this
## catalog knows; null otherwise.
func _as_equippable(stack: ItemStack) -> ItemStack:
	if stack == null or stack.item == null or catalog == null or not catalog.has_item(stack.item.id):
		return null
	var piece: ItemStack = stack.copy()
	piece.item = catalog.get_item(stack.item.id)
	if not piece.item is PieceData or not _is_slot((piece.item as PieceData).slot_type):
		return null
	return piece if InventoryRules.is_valid_stack(piece) else null


## Null for an empty slot or a bad entry (reported).
func _piece_from_save(entry: Variant, slot: int) -> ItemStack:
	if entry == null:
		return null
	var fields: Dictionary = entry if entry is Dictionary else {}
	var item_id: StringName = StringName(str(fields.get("item_id", "")))
	var durability: Variant = fields.get("durability")
	var piece_uid: Variant = fields.get("uid")
	var piece: ItemStack = null
	if catalog != null and catalog.has_item(item_id) and SaveFields.is_whole_number(durability) and piece_uid is String:
		piece = ItemStack.new(catalog.get_item(item_id), 1)
		piece.durability = SaveFields.to_int(durability, -1)
		piece.uid = piece_uid
	var data: PieceData = null if piece == null else piece.item as PieceData
	if data == null or data.slot_type != slot or not InventoryRules.is_valid_stack(piece):
		push_error("EquipmentComponent '%s': saved %s %s is lost." % [name, _SLOT_KEYS[slot], entry])
		return null
	return piece


func _is_slot(slot: int) -> bool:
	return slot >= 0 and slot < _pieces.size()
