class_name DroppedItem
extends Node3D
## Stacks lying on the ground (spec 008): what a dead robot carried, what a
## zombie left or what the player threw. Interacting takes everything that
## fits; the rest stays. It keeps its stacks in its own InventoryComponent, so
## dropping and picking up reuse the inventory rules and never create or lose
## items. Instances are pooled: setup() starts a new use and reset() leaves
## nothing of the previous one. It knows neither the pool nor the clock:
## DroppedItemSpawner owns both.

## Its last stack was picked up. Once per use.
signal emptied(dropped: DroppedItem)

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
## carries its durability and uid, so a piece survives the save (R-011-10).
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
	}


## Everything that fits goes to the interactor's inventory, in slot order.
## What does not fit stays here; that inventory reports it (overflowed).
## emptied comes only from here: setup() and reset() also leave it empty.
func _on_interacted(interactor: Node3D) -> void:
	var inventory: InventoryComponent = InventoryComponent.find_in(interactor)
	if inventory == null:
		push_error(
			"DroppedItem '%s': '%s' picked it up but has no InventoryComponent."
			% [name, interactor.name]
		)
		return
	var slot_indices: Array[int] = []
	for index: int in _contents.get_slot_count():
		slot_indices.append(index)
	inventory.take_from(_contents, slot_indices)
	if _contents.is_empty():
		_interactable.enabled = false
		emptied.emit(self)
