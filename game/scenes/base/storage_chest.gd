class_name StorageChest
extends StaticBody3D
## A placed storage chest (spec 012, BALANCE §5.4): presentation only. Its
## contents live in StructureStates under World, never in this instance, which
## leaves with the base (plan D5). Interacting only announces `used`;
## BaseStructures relays it and StructureUseFlow opens the container screen.

## A player interacted with this chest.
signal used(user: Node3D)

@onready var _interactable: InteractableComponent = %Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node3D) -> void:
	used.emit(interactor)
