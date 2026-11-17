class_name RepairBench
extends StaticBody3D
## The repair bench of the base (spec 009): part of the base scene at a fixed
## position, never a placed structure (R-009-20). Interacting with it is a
## request the base relays; the build screen opens from there (R-009-64).
## Spec 011 adds crafting pieces and repairing.

signal used(user: Node3D)

@onready var _interactable: InteractableComponent = %Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node3D) -> void:
	used.emit(interactor)
