class_name BuildArea
extends Node3D
## Origin and drawing of the base placement grid (spec 009). It sits on the
## corner of cell (0, 0); the lines are only shown while placing or editing.
## Lines of an ImmediateMesh: plan 009 §5.1 point 5 checked them in the
## Compatibility renderer.

## Above the floor, so the lines are not hidden by it.
const LINE_HEIGHT_M := 0.02
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.55)

@export var grid: BuildGridData

var _overlay: MeshInstance3D = null


func _ready() -> void:
	if grid == null:
		push_error("BuildArea '%s': grid must be assigned." % name)
		return
	_overlay = MeshInstance3D.new()
	_overlay.mesh = _build_lines()
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.visible = false
	add_child(_overlay)


func set_overlay_visible(overlay_visible: bool) -> void:
	if _overlay != null:
		_overlay.visible = overlay_visible


func is_overlay_visible() -> bool:
	return _overlay != null and _overlay.visible


func _build_lines() -> ImmediateMesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = LINE_COLOR
	var size: Vector2 = Vector2(grid.area_size_cells) * grid.cell_size_m
	var lines: ImmediateMesh = ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for x: int in grid.area_size_cells.x + 1:
		lines.surface_add_vertex(Vector3(x * grid.cell_size_m, LINE_HEIGHT_M, 0.0))
		lines.surface_add_vertex(Vector3(x * grid.cell_size_m, LINE_HEIGHT_M, size.y))
	for z: int in grid.area_size_cells.y + 1:
		lines.surface_add_vertex(Vector3(0.0, LINE_HEIGHT_M, z * grid.cell_size_m))
		lines.surface_add_vertex(Vector3(size.x, LINE_HEIGHT_M, z * grid.cell_size_m))
	lines.surface_end()
	return lines
