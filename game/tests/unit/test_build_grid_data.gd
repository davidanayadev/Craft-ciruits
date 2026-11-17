extends GutTest
## Base placement grid data (spec 009, R-009-23): cell size and buildable area
## from BALANCE §5.6, and reserved cells inside the area. The expected values
## mirror BALANCE.md §5.6; update both together.

const BASE_GRID_PATH := "res://resources/config/base_grid.tres"

var _grid: BuildGridData


func before_each() -> void:
	_grid = load(BASE_GRID_PATH) as BuildGridData


func test_r_009_23_values_from_balance() -> void:
	assert_not_null(_grid, "base_grid.tres exists and is a BuildGridData")
	if _grid == null:
		return
	assert_eq(_grid.cell_size_m, 1.0, "cell size (BALANCE §5.6)")
	assert_eq(_grid.area_size_cells, Vector2i(12, 8), "buildable area (BALANCE §5.6)")


func test_r_009_23_reserved_cells_inside_area() -> void:
	if _grid == null:
		fail_test("base_grid.tres is missing")
		return
	assert_gt(_grid.reserved_cells.size(), 0, "the base reserves cells (question 7)")
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _grid.reserved_cells:
		assert_true(
			cell.x >= 0 and cell.y >= 0
			and cell.x < _grid.area_size_cells.x and cell.y < _grid.area_size_cells.y,
			"reserved cell %s is inside the area" % cell
		)
		assert_false(seen.has(cell), "reserved cell %s is listed once" % cell)
		seen[cell] = true
