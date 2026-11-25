class_name RepairBench
extends StaticBody3D
## The repair bench of the base (spec 009): part of the base scene at a fixed
## position, never a placed structure (R-009-20). Interacting with it is a
## request the base relays; the bench screen opens from there (R-009-64).
## Crafting and repairing (spec 011) are a player's requests at the bench: the
## player's inventory pays and changes, and the bench announces the fact. It
## holds no state (constitution P4); in co-op the host will decide here.

signal used(user: Node3D)

@onready var _interactable: InteractableComponent = %Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node3D) -> void:
	used.emit(interactor)


## The player's craft request at this bench (plan 011 D7): the player's
## inventory crafts recipe and, when it succeeds, EventBus.item_crafted. No
## player or not a WORKBENCH recipe → push_error, ERR_INVALID_REQUEST.
func craft(player: Robot, recipe: RecipeData) -> ActionResult:
	if player == null or recipe == null or recipe.station != RecipeData.Station.WORKBENCH:
		push_error("RepairBench '%s': craft() needs a player and a WORKBENCH recipe." % name)
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	var result: ActionResult = player.inventory.craft(recipe)
	if result.ok:
		EventBus.item_crafted.emit(recipe.id, player.player_uid)
	return result


## The player's repair request: the piece piece_uid, equipped (spec 015,
## R-015-30) or in the inventory, is repaired with the catalog's repair costs,
## paid from the player's inventory, and, when it succeeds,
## EventBus.piece_repaired. No player → push_error, ERR_INVALID_REQUEST.
func repair(player: Robot, piece_uid: String) -> ActionResult:
	if player == null:
		push_error("RepairBench '%s': repair() needs a player." % name)
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	var costs: RepairCostData = DataRegistry.get_catalog().repair_costs
	var result: ActionResult = null
	if player.equipment.has_piece(piece_uid):
		result = player.equipment.repair(piece_uid, player.inventory, costs)
	else:
		result = player.inventory.repair(piece_uid, costs)
	if result.ok:
		EventBus.piece_repaired.emit(piece_uid, player.player_uid)
	return result
