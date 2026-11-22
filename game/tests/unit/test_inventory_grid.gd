extends GutTest
## InventoryGrid (spec 013): passes the move highlight (R-013-19) and the
## destination outline of placing mode (R-013-16) to its cells.

const GRID_SCENE := preload("res://scenes/ui/inventory_grid.tscn")
const SLOTS := 4
const DURATION_S := 0.4

var _grid: InventoryGrid


func before_each() -> void:
	var inventory: InventoryComponent = InventoryComponent.new()
	add_child_autofree(inventory)
	inventory.set_slot_count(SLOTS)
	_grid = GRID_SCENE.instantiate() as InventoryGrid
	add_child_autofree(_grid)
	_grid.bind(inventory)


func _cells() -> Array[InventorySlotView]:
	var cells: Array[InventorySlotView] = []
	for child: Node in _grid.get_children():
		cells.append(child as InventorySlotView)
	return cells


func test_r_013_19_flash_slots() -> void:
	var flashed: Array[int] = [1, 3]
	_grid.flash_slots(flashed, DURATION_S)
	var cells: Array[InventorySlotView] = _cells()
	assert_eq(cells.size(), SLOTS, "one cell per slot")
	for i: int in cells.size():
		assert_eq(cells[i].is_highlighted(), flashed.has(i), "cell %d" % i)


func test_r_013_19_flash_ignores_unknown_slots() -> void:
	var outside: Array[int] = [-1, SLOTS]
	_grid.flash_slots(outside, DURATION_S)
	assert_push_error_count(2, "slots outside the grid are reported")
	for cell: InventorySlotView in _cells():
		assert_false(cell.is_highlighted(), "no cell is highlighted")


func test_r_013_16_targets_marked() -> void:
	_grid.set_targets_marked(true)
	for cell: InventorySlotView in _cells():
		assert_true(cell.is_target_marked(), "every cell is a destination")
	_grid.set_targets_marked(false)
	for cell: InventorySlotView in _cells():
		assert_false(cell.is_target_marked(), "no cell is a destination")
