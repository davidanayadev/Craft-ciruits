class_name BenchRepairSection
extends VBoxContainer
## Repair tab of the bench screen (spec 011): one row per damaged piece of the
## player's inventory, named by its uid, with its icon, name, durability,
## repair cost and a "Repair" button, disabled with the reason of
## CraftingSystem.check_repair; %NothingToRepair when there is none (R-011-24).
## The damaged pieces change, so refresh() rebuilds the rows (plan 011 D11).

const BUTTON_KEY := &"REPAIR_BUTTON"
const DURABILITY_KEY := &"BENCH_DURABILITY"

var _player: Robot = null
var _bench: RepairBench = null
var _costs: RepairCostData = null

@onready var _nothing_to_repair: Label = %NothingToRepair


func setup(player: Robot, bench: RepairBench, costs: RepairCostData) -> void:
	_player = player
	_bench = bench
	_costs = costs
	refresh()


func refresh() -> void:
	_remove_entries()
	var slots: Array[ItemStack] = _player.inventory.get_slots()
	var listed: int = 0
	for stack: ItemStack in slots:
		if CraftingSystem.is_damaged(stack):
			_add_entry(stack, slots)
			listed += 1
	_nothing_to_repair.visible = listed == 0


## Freed later: the refresh may come from the pressed signal of one of them.
func _remove_entries() -> void:
	for child: Node in get_children():
		if child is BenchEntry:
			remove_child(child)
			child.queue_free()


func _add_entry(stack: ItemStack, slots: Array[ItemStack]) -> void:
	var piece: PieceData = stack.item as PieceData
	var detail: String = tr(DURABILITY_KEY) % [stack.durability, piece.durability_max]
	var entry: BenchEntry = BenchEntry.new()
	entry.name = stack.uid
	entry.setup(piece.icon, piece.name_key, detail, CraftingSystem.repair_cost(stack, _costs), BUTTON_KEY)
	entry.set_blocked(CraftingSystem.check_repair(slots, stack.uid, _costs).error_key)
	entry.pressed.connect(_on_entry_pressed.bind(stack.uid))
	add_child(entry)


func _on_entry_pressed(piece_uid: String) -> void:
	if CraftingSystem.check_repair(_player.inventory.get_slots(), piece_uid, _costs).ok:
		_bench.repair(_player, piece_uid)
