class_name BaseZone
extends Zone
## The base (spec 009): a safe zone with floor, boundaries, a spawn point, an
## exit point, the fixed repair bench and a buildable area that starts empty.
## No enemies and no navigation mesh. The placed structures are not its own
## state: BaseStructures instances them under %Structures while the base is
## loaded. It also shows the placement preview, which is presentation only.

## A player interacted with the repair bench.
signal bench_used(user: Node3D)

const PREVIEW_VALID := preload("res://resources/materials/preview_valid.tres")
const PREVIEW_INVALID := preload("res://resources/materials/preview_invalid.tres")

## The same resource BaseStructures uses (a test guards it).
@export var grid: BuildGridData

var _preview: Node3D = null
var _preview_structure: StructureData = null

@onready var _bench: RepairBench = %RepairBench
@onready var _build_area: BuildArea = %BuildArea
@onready var _structures_root: Node3D = %Structures
@onready var _preview_root: Node3D = %PreviewRoot


func _ready() -> void:
	super()
	_bench.used.connect(_on_bench_used)


## The fixed repair bench of the base (spec 011): the bench screen asks it to craft and repair.
func get_bench() -> RepairBench:
	return _bench


func get_structures_root() -> Node3D:
	return _structures_root


func get_preview_root() -> Node3D:
	return _preview_root


## Global height of the build plane.
func get_floor_height() -> float:
	return _build_area.global_position.y


func set_grid_visible(grid_visible: bool) -> void:
	_build_area.set_overlay_visible(grid_visible)


func is_grid_visible() -> bool:
	return _build_area.is_overlay_visible()


## Shows structure at local_position (local to the base), green when valid
## and red when not. The preview has no collision and is not interactable.
func show_preview(structure: StructureData, local_position: Vector3, valid: bool) -> void:
	if structure == null or structure.scene == null:
		push_error("BaseZone '%s': show_preview() needs a structure with a scene." % name)
		return
	if structure != _preview_structure:
		hide_preview()
		_preview = structure.scene.instantiate() as Node3D
		# Disabled: out of the physics space, so it neither blocks nor is interactable.
		_preview.process_mode = Node.PROCESS_MODE_DISABLED
		_preview_root.add_child(_preview)
		_preview_structure = structure
	_preview.position = _preview_root.to_local(to_global(local_position))
	var material: Material = PREVIEW_VALID if valid else PREVIEW_INVALID
	for mesh: Node in _preview.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material


func hide_preview() -> void:
	if _preview != null:
		_preview.queue_free()
	_preview = null
	_preview_structure = null


## The preview node, or null when hidden. For tests and the placement screen.
func get_preview() -> Node3D:
	return _preview


func _on_bench_used(user: Node3D) -> void:
	bench_used.emit(user)
