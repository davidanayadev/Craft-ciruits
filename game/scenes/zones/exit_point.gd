class_name ExitPoint
extends Node3D
## The physical way out of a zone (spec 009): interacting with it asks to
## travel to its destination, with no cost and no limit (BALANCE §1.2). The
## destination is set on each instance; the zone_id lives only in that ZoneData.

## Relayed by the zone as exit_requested.
signal travel_requested(destination: ZoneData, traveller: Node3D)

@export var destination: ZoneData

@onready var _interactable: InteractableComponent = %Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node3D) -> void:
	if destination == null:
		push_error("ExitPoint '%s': destination must be assigned." % name)
		return
	travel_requested.emit(destination, interactor)
