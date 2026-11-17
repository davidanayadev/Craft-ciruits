class_name BuildGridData
extends Resource
## Placement grid of the base (BALANCE.md §5.6, ACTION_PLAN 2.8). The cell size
## and the area come from BALANCE; the origin and the reserved cells are the
## layout of the base scene, which points to this same resource.

## Side of one square cell.
@export var cell_size_m: float = 0.0
## Buildable area, in cells (x, z).
@export var area_size_cells: Vector2i = Vector2i.ZERO
## Corner of cell (0, 0), local to the base. Cells grow towards +x and +z.
@export var area_origin_local: Vector3 = Vector3.ZERO
## Never buildable: in front of the spawn point, the exit point and the bench.
@export var reserved_cells: Array[Vector2i] = []
