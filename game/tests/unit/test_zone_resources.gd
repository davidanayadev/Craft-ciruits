extends GutTest
## Zone data (spec 004): the green zone is zone (0, 0) (R-004-02), fits in one
## cell of the global grid (R-004-03) and gets the box count of BALANCE §7.1
## (R-004-21). The expected values mirror BALANCE.md §7 and §7.1; update both
## together.

const GREEN_ZONE_PATH := "res://resources/zones/green_zone.tres"
const WORLD_GRID_PATH := "res://resources/config/world_grid.tres"

var _zone: ZoneData
var _grid: WorldGridConfigData


func before_each() -> void:
	_zone = load(GREEN_ZONE_PATH) as ZoneData
	_grid = load(WORLD_GRID_PATH) as WorldGridConfigData


func test_r_004_02_green_zone_id() -> void:
	assert_not_null(_zone, "green_zone.tres exists and is a ZoneData")
	if _zone == null:
		return
	assert_eq(_zone.zone_id, Vector2i(0, 0), "the green zone is zone (0, 0)")


func test_r_004_03_cell_size_matches_balance() -> void:
	assert_not_null(_grid, "world_grid.tres exists and is a WorldGridConfigData")
	if _grid == null:
		return
	assert_eq(_grid.cell_size_m, 80.0, "global map cell (BALANCE §7)")


func test_r_004_03_green_zone_size_fits_in_cell() -> void:
	if _zone == null or _grid == null:
		fail_test("zone or grid resource is missing")
		return
	assert_eq(_zone.size_m, Vector2(50.0, 50.0), "green zone size (BALANCE §7.1)")
	assert_lte(_zone.size_m.x, _grid.cell_size_m, "width fits in one cell")
	assert_lte(_zone.size_m.y, _grid.cell_size_m, "depth fits in one cell")


func test_r_004_21_box_counts_match_balance() -> void:
	if _zone == null:
		fail_test("green_zone.tres is missing")
		return
	assert_eq(_zone.box_count_min, 5, "minimum boxes (BALANCE §7.1)")
	assert_eq(_zone.box_count_max, 7, "maximum boxes (BALANCE §7.1)")
