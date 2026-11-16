class_name HitFlashComponent
extends Node
## White flash of an entity that was hit (spec 007, R-007-24): lays a shared
## material over its meshes for the time of CombatFeedbackData. Presentation
## only: it never touches HP. It processes only while it flashes.

## Meshes the flash covers.
@export var meshes: Array[GeometryInstance3D] = []
## Shared by every instance (resources/materials/hit_flash.tres).
@export var material: Material
@export var feedback: CombatFeedbackData

var _seconds_left: float = 0.0


func _ready() -> void:
	set_process(false)
	if material == null or feedback == null:
		push_error("HitFlashComponent '%s': material and feedback must be assigned." % name)


func _process(delta: float) -> void:
	advance(delta)


## Starts the flash, or starts it again if it was already on.
func flash() -> void:
	if material == null or feedback == null:
		return
	_seconds_left = feedback.enemy_flash_s
	_set_overlay(material)
	set_process(true)


## Ends the flash at once. A pooled entity calls it when it starts a new life.
func clear() -> void:
	_seconds_left = 0.0
	_set_overlay(null)
	set_process(false)


func is_flashing() -> bool:
	return _seconds_left > 0.0


## Advances the flash by delta seconds; _process calls it while flashing.
func advance(delta: float) -> void:
	if not is_flashing():
		return
	_seconds_left -= delta
	if _seconds_left <= 0.0:
		clear()


func _set_overlay(overlay: Material) -> void:
	for mesh: GeometryInstance3D in meshes:
		if mesh != null:
			mesh.material_overlay = overlay
