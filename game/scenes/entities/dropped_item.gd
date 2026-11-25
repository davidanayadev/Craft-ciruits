class_name DroppedItem
extends Node3D
## Stacks lying on the ground (spec 008): what a dead robot carried, what a
## zombie left or what the player threw. It is a container (spec 015, R-015-45):
## interacting only announces opened, and the container screen moves stacks
## both ways. It keeps its stacks in its own InventoryComponent, so dropping
## and taking reuse the inventory rules and never create or lose items; its
## slot count is the one it was created with (R-015-47). Instances are pooled:
## setup() starts a new use and reset() leaves nothing of the previous one. It
## knows neither the pool, the clock nor the UI: DroppedItemSpawner owns the
## first two and DroppedItemFlow opens the screen.

## Fact: someone interacted with it (R-015-45). Every interaction while it exists.
signal opened(item: DroppedItem, opener: Node3D)

## Identity for saves and the network (architecture §10.3).
var uid: String = ""
var zone_id: Vector2i = Vector2i.ZERO
## Relative to its zone and fixed when it falls, so it does not depend on the
## zone staying loaded (constitution P9).
var local_position: Vector3 = Vector3.ZERO
var dropped_at_unix: int = 0

@onready var _interactable: InteractableComponent = %Interactable
@onready var _contents: InventoryComponent = %Contents


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


## Starts a new use with slot_count empty slots. Call it inside the tree.
func setup(
	p_uid: String,
	p_zone_id: Vector2i,
	p_local_position: Vector3,
	p_dropped_at_unix: int,
	slot_count: int
) -> void:
	uid = p_uid
	zone_id = p_zone_id
	local_position = p_local_position
	dropped_at_unix = p_dropped_at_unix
	_contents.clear(slot_count)
	_interactable.enabled = true


## No stacks, no slots, no uid, zone, position or time, and not interactable:
## an interactor may still point at it for one physics step after it left.
func reset() -> void:
	_interactable.enabled = false
	_contents.clear(0)
	uid = ""
	zone_id = Vector2i.ZERO
	local_position = Vector3.ZERO
	dropped_at_unix = 0


func get_contents() -> InventoryComponent:
	return _contents


## Its state in JSON types only, as spec 010 saves it (R-010-29). Each stack
## carries its durability and uid, so a piece survives the save (R-011-10), and
## the slot count is kept, empty slots included (R-015-55).
func to_data() -> Dictionary:
	var stacks: Array[Dictionary] = []
	for stack: ItemStack in _contents.get_slots():
		if stack != null:
			stacks.append({
				"item_id": String(stack.item.id),
				"quantity": stack.quantity,
				"durability": stack.durability,
				"uid": stack.uid,
			})
	return {
		"uid": uid,
		"zone_id": SaveFields.vector2i_to_array(zone_id),
		"position": SaveFields.vector3_to_array(local_position),
		"dropped_at": dropped_at_unix,
		"stacks": stacks,
		"slot_count": _contents.get_slot_count(),
	}


## Nothing is taken here: whoever opens the screen does it (R-015-45).
func _on_interacted(interactor: Node3D) -> void:
	opened.emit(self, interactor)
