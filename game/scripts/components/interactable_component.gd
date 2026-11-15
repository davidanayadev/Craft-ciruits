class_name InteractableComponent
extends Area3D
## Makes an object interactable (architecture §9.1): box, bench, station,
## chest. The object adds a collision shape as a child and connects
## `interacted` to its own logic; proximity, button and prompt are handled
## once by InteractorComponent and the HUD.

## 3D physics layer reserved for interactables, named "interaction" in
## project.godot. The only place where the number lives.
const PHYSICS_LAYER := 2

signal interacted(interactor: Node3D)

## Translation key of the HUD button text: PROMPT_OPEN, PROMPT_RECHARGE…
@export var prompt_key: StringName
## A disabled interactable is not offered as a target and ignores interact().
@export var enabled: bool = true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(PHYSICS_LAYER, true)
	monitoring = false
	monitorable = true


## The request to interact; emits only while enabled.
func interact(interactor: Node3D) -> void:
	if not enabled:
		return
	interacted.emit(interactor)
