extends GutTest
## BuildGrid (spec 009, plan §3): pure occupation, bounds, cell <-> local
## conversion and JSON round trip of the base's build area. Covers R-009-25,
## R-009-26, R-009-27, R-009-28, R-009-31, R-009-45 and the rule of R-009-58
## (cells passed as "blocked" make a placement invalid). Data is built by hand:
## no scene tree, no autoloads, no .tres.
##
## Assumed conventions (plan leaves them open): cell (0, 0) has its corner at
## area_origin_local; cell.x runs along local X and cell.y along local Z; the
## local Y of cell_to_local is area_origin_local.y.

const NO_CELL := Vector2i(-1, -1)
const ERR_PLACEMENT := &"ERR_INVALID_PLACEMENT"
const ORIGIN := Vector3(-6.0, 0.0, -4.0)
const ZONE := Vector2i(0, 0)

var _config: BuildGridData
var _small: StructureData
var _wide: StructureData
var _big: StructureData
var _catalog: DataCatalog
var _none: Array[Vector2i] = []


func before_each() -> void:
	_config = _make_config(Vector2i(12, 8), [Vector2i(5, 3)])
	_small = _structure(&"small", Vector2i(1, 1))
	_wide = _structure(&"wide", Vector2i(2, 1))
	_big = _structure(&"big", Vector2i(2, 2))
	_catalog = DataCatalog.new()
	_catalog.structures.append(_small)
	_catalog.structures.append(_wide)
	_catalog.structures.append(_big)


func _make_config(size: Vector2i, reserved: Array[Vector2i]) -> BuildGridData:
	var config: BuildGridData = BuildGridData.new()
	config.cell_size_m = 1.0
	config.area_size_cells = size
	config.area_origin_local = ORIGIN
	config.reserved_cells = reserved
	return config


func _structure(id: StringName, footprint: Vector2i) -> StructureData:
	var structure: StructureData = StructureData.new()
	structure.id = id
	structure.name_key = &"STRUCTURE_TEST"
	structure.footprint = footprint
	return structure


func _grid() -> BuildGrid:
	return BuildGrid.new(_config, ZONE)


func _entry(uid: String, structure_id: String, cell: Array) -> Dictionary:
	return {"uid": uid, "structure_id": structure_id, "zone_id": [0, 0], "cell": cell}


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy: Array[Vector2i] = cells.duplicate()
	copy.sort_custom(_cell_less)
	return copy


static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


func _snapshot(grid: BuildGrid) -> Array[String]:
	var lines: Array[String] = []
	for uid: String in grid.get_uids():
		lines.append("%s|%s|%s" % [uid, grid.get_structure_id(uid), grid.get_cell(uid)])
	lines.sort()
	return lines


# --- R-009-25 valid placement ------------------------------------------------


func test_r_009_25_valid_placement_inside() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.is_valid(Vector2i(1, 1), Vector2i(0, 0), _none), "corner cell")
	assert_true(grid.is_valid(Vector2i(1, 1), Vector2i(11, 7), _none), "opposite corner cell")
	var result: ActionResult = grid.occupy("a", _small, Vector2i(3, 2))
	assert_true(result.ok)
	assert_eq(grid.uid_at(Vector2i(3, 2)), "a")
	assert_eq(grid.get_cell("a"), Vector2i(3, 2))
	assert_eq(grid.get_structure_id("a"), &"small")
	assert_eq(grid.get_uids(), ["a"] as Array[String])


func test_r_009_25_contains() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.contains(Vector2i(0, 0)))
	assert_true(grid.contains(Vector2i(11, 7)))
	assert_false(grid.contains(Vector2i(12, 7)), "x past the area")
	assert_false(grid.contains(Vector2i(11, 8)), "y past the area")
	assert_false(grid.contains(Vector2i(-1, 0)))
	assert_false(grid.contains(Vector2i(0, -1)))


func test_r_009_25_outside_limits() -> void:
	var grid: BuildGrid = _grid()
	for cell: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(12, 0), Vector2i(0, 8), Vector2i(40, 40)]:
		assert_false(grid.is_valid(Vector2i(1, 1), cell, _none), "%s is outside" % cell)
		var result: ActionResult = grid.occupy("a", _small, cell)
		assert_false(result.ok, "%s cannot be occupied" % cell)
		assert_eq(result.error_key, ERR_PLACEMENT)
	assert_eq(grid.get_uids().size(), 0, "nothing was stored")


func test_r_009_25_reserved_cell() -> void:
	var grid: BuildGrid = _grid()
	assert_false(grid.is_valid(Vector2i(1, 1), Vector2i(5, 3), _none), "reserved cell")
	var result: ActionResult = grid.occupy("a", _small, Vector2i(5, 3))
	assert_false(result.ok)
	assert_eq(result.error_key, ERR_PLACEMENT)
	assert_eq(grid.uid_at(Vector2i(5, 3)), "", "still free")
	# A footprint that only touches the reserved cell with one of its cells is invalid too.
	assert_false(grid.is_valid(Vector2i(2, 1), Vector2i(4, 3), _none), "2x1 over (4,3)-(5,3)")
	assert_true(grid.is_valid(Vector2i(2, 1), Vector2i(3, 3), _none), "2x1 over (3,3)-(4,3) is fine")


func test_r_009_25_occupied_cell() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _small, Vector2i(2, 2)).ok)
	assert_false(grid.is_valid(Vector2i(1, 1), Vector2i(2, 2), _none))
	var result: ActionResult = grid.occupy("b", _small, Vector2i(2, 2))
	assert_false(result.ok)
	assert_eq(result.error_key, ERR_PLACEMENT)
	assert_eq(grid.uid_at(Vector2i(2, 2)), "a", "the first one keeps it")
	assert_eq(grid.get_cell("b"), NO_CELL, "b was not stored")
	# Overlap through a second footprint cell.
	assert_false(grid.occupy("c", _wide, Vector2i(1, 2)).ok, "(1,2)-(2,2) overlaps a")
	assert_eq(grid.get_uids().size(), 1)


func test_r_009_25_blocked_cell() -> void:
	var grid: BuildGrid = _grid()
	var blocked: Array[Vector2i] = [Vector2i(4, 4)]
	assert_false(grid.is_valid(Vector2i(1, 1), Vector2i(4, 4), blocked), "a robot stands there")
	assert_true(grid.is_valid(Vector2i(1, 1), Vector2i(4, 4), _none), "free without the robot")
	assert_true(grid.is_valid(Vector2i(1, 1), Vector2i(4, 5), blocked), "the next cell is free")
	assert_false(grid.is_valid(Vector2i(2, 2), Vector2i(3, 3), blocked), "(4,4) is inside the 2x2")


func test_r_009_25_footprint_partly_outside() -> void:
	var grid: BuildGrid = _grid()
	assert_false(grid.is_valid(Vector2i(2, 2), Vector2i(11, 7), _none), "corner: 3 cells out")
	assert_false(grid.is_valid(Vector2i(2, 1), Vector2i(11, 0), _none), "right edge")
	assert_false(grid.is_valid(Vector2i(1, 2), Vector2i(0, 7), _none), "bottom edge")
	assert_false(grid.is_valid(Vector2i(2, 2), Vector2i(-1, 0), _none), "left edge")
	assert_true(grid.is_valid(Vector2i(2, 2), Vector2i(10, 6), _none), "exactly fills the corner")
	var result: ActionResult = grid.occupy("a", _big, Vector2i(11, 7))
	assert_false(result.ok)
	assert_eq(result.error_key, ERR_PLACEMENT)
	assert_eq(grid.get_uids().size(), 0)


func test_r_009_25_footprint_2x2_occupies_four_cells() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _big, Vector2i(2, 2)).ok)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
		assert_eq(grid.uid_at(cell), "a", "%s belongs to a" % cell)
	assert_eq(grid.uid_at(Vector2i(4, 2)), "")
	assert_eq(grid.uid_at(Vector2i(2, 4)), "")
	assert_eq(grid.get_cell("a"), Vector2i(2, 2), "get_cell is the anchor cell")


func test_r_009_25_duplicate_uid_rejected() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _small, Vector2i(1, 1)).ok)
	var result: ActionResult = grid.occupy("a", _small, Vector2i(6, 6))
	assert_false(result.ok, "a uid can only be in the grid once")
	assert_eq(grid.get_cell("a"), Vector2i(1, 1), "unchanged")
	assert_eq(grid.uid_at(Vector2i(6, 6)), "")


func test_r_009_25_unknown_uid_and_free_cell() -> void:
	var grid: BuildGrid = _grid()
	assert_eq(grid.get_cell("nope"), NO_CELL)
	assert_eq(grid.uid_at(Vector2i(0, 0)), "")
	assert_eq(grid.uid_at(Vector2i(99, 99)), "", "outside the area is also ''")
	assert_eq(grid.get_uids().size(), 0)


# --- R-009-26 move -------------------------------------------------------------


func test_r_009_26_move_frees_old_cells() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _big, Vector2i(2, 2)).ok)
	var result: ActionResult = grid.move("a", Vector2i(7, 4), _none)
	assert_true(result.ok)
	assert_eq(grid.get_cell("a"), Vector2i(7, 4))
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
		assert_eq(grid.uid_at(cell), "", "%s is free again" % cell)
	for cell: Vector2i in [Vector2i(7, 4), Vector2i(8, 4), Vector2i(7, 5), Vector2i(8, 5)]:
		assert_eq(grid.uid_at(cell), "a", "%s is taken now" % cell)
	assert_eq(grid.get_uids().size(), 1, "still one structure")


func test_r_009_26_invalid_move_keeps_place() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _wide, Vector2i(2, 2)).ok)
	assert_true(grid.occupy("b", _small, Vector2i(6, 2)).ok)
	var before: Array[String] = _snapshot(grid)
	var blocked: Array[Vector2i] = [Vector2i(9, 9)]
	var targets: Array[Vector2i] = [
		Vector2i(-1, 2),  # outside
		Vector2i(11, 2),  # footprint partly outside
		Vector2i(5, 3),  # reserved
		Vector2i(5, 2),  # (5,2)-(6,2) overlaps b
	]
	for target: Vector2i in targets:
		var result: ActionResult = grid.move("a", target, _none)
		assert_false(result.ok, "move to %s" % target)
		assert_eq(result.error_key, ERR_PLACEMENT)
		assert_eq(_snapshot(grid), before, "nothing changed after %s" % target)
	var blocked_move: ActionResult = grid.move("a", Vector2i(8, 6), blocked)
	assert_true(blocked_move.ok, "control: a free target with an unrelated blocked cell works")
	var back: ActionResult = grid.move("a", Vector2i(2, 2), [Vector2i(3, 2)] as Array[Vector2i])
	assert_false(back.ok, "a blocked cell inside the footprint refuses the move (R-009-58)")
	assert_eq(grid.get_cell("a"), Vector2i(8, 6))
	assert_eq(grid.uid_at(Vector2i(2, 2)), "", "old cells stay free")


func test_r_009_26_move_unknown_uid() -> void:
	var grid: BuildGrid = _grid()
	var result: ActionResult = grid.move("ghost", Vector2i(1, 1), _none)
	assert_false(result.ok)
	assert_eq(grid.get_uids().size(), 0)
	assert_eq(grid.uid_at(Vector2i(1, 1)), "")


# --- R-009-27 fits somewhere ---------------------------------------------------


func test_r_009_27_fits_somewhere() -> void:
	var grid: BuildGrid = _grid()
	var found: Vector2i = grid.find_free_cell(Vector2i(1, 1), Vector2i(3, 3), _none)
	assert_eq(found, Vector2i(3, 3), "a free near cell is the answer")
	assert_true(grid.is_valid(Vector2i(1, 1), found, _none))


func test_r_009_27_nearest_valid_cell() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _small, Vector2i(3, 3)).ok)
	var found: Vector2i = grid.find_free_cell(Vector2i(1, 1), Vector2i(3, 3), _none)
	var neighbours: Array[Vector2i] = [Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(3, 4)]
	assert_true(found in neighbours, "an orthogonal neighbour, got %s" % found)
	var reserved_near: Vector2i = grid.find_free_cell(Vector2i(1, 1), Vector2i(5, 3), _none)
	assert_ne(reserved_near, Vector2i(5, 3), "the reserved cell is never returned")
	assert_true(grid.is_valid(Vector2i(1, 1), reserved_near, _none))


func test_r_009_27_find_respects_blocked() -> void:
	var grid: BuildGrid = _grid()
	var blocked: Array[Vector2i] = [Vector2i(3, 3)]
	var found: Vector2i = grid.find_free_cell(Vector2i(1, 1), Vector2i(3, 3), blocked)
	assert_ne(found, Vector2i(3, 3))
	assert_ne(found, NO_CELL)


func test_r_009_27_footprint_needs_contiguous_room() -> void:
	# 3x2 area, one cell taken in the middle column: no free 2x2 block is left.
	_config = _make_config(Vector2i(3, 2), [])
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _small, Vector2i(1, 0)).ok)
	assert_eq(grid.find_free_cell(Vector2i(2, 2), Vector2i(0, 0), _none), NO_CELL, "no 2x2 fits")
	assert_ne(grid.find_free_cell(Vector2i(1, 1), Vector2i(0, 0), _none), NO_CELL, "1x1 still fits")


func test_r_009_27_full_grid_fits_nowhere() -> void:
	_config = _make_config(Vector2i(2, 2), [])
	var grid: BuildGrid = _grid()
	var n: int = 0
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		assert_true(grid.occupy("u%d" % n, _small, cell).ok)
		n += 1
	assert_eq(grid.find_free_cell(Vector2i(1, 1), Vector2i(0, 0), _none), NO_CELL)


func test_r_009_27_reserved_and_blocked_can_fill_it() -> void:
	_config = _make_config(Vector2i(2, 1), [Vector2i(0, 0)])
	var grid: BuildGrid = _grid()
	var blocked: Array[Vector2i] = [Vector2i(1, 0)]
	assert_eq(grid.find_free_cell(Vector2i(1, 1), Vector2i(0, 0), blocked), NO_CELL)
	assert_eq(grid.find_free_cell(Vector2i(1, 1), Vector2i(0, 0), _none), Vector2i(1, 0))


# --- R-009-28 conversion --------------------------------------------------------


func test_r_009_28_cell_to_local_is_footprint_centre() -> void:
	var grid: BuildGrid = _grid()
	assert_eq(grid.cell_to_local(Vector2i(0, 0), Vector2i(1, 1)), Vector3(-5.5, 0.0, -3.5))
	assert_eq(grid.cell_to_local(Vector2i(2, 3), Vector2i(2, 2)), Vector3(-3.0, 0.0, 0.0))
	assert_eq(grid.cell_to_local(Vector2i(2, 3), Vector2i(2, 1)), Vector3(-3.0, 0.0, -0.5))


func test_r_009_28_local_to_cell() -> void:
	var grid: BuildGrid = _grid()
	assert_eq(grid.local_to_cell(Vector3(-5.5, 0.0, -3.5)), Vector2i(0, 0))
	assert_eq(grid.local_to_cell(Vector3(-6.0, 0.0, -4.0)), Vector2i(0, 0), "the corner belongs to cell (0, 0)")
	assert_eq(grid.local_to_cell(Vector3(-4.01, 0.0, -2.01)), Vector2i(1, 1))
	assert_eq(grid.local_to_cell(Vector3(-0.01, 7.0, 3.99)), Vector2i(5, 7), "the height is ignored")
	assert_eq(grid.local_to_cell(Vector3(-6.5, 0.0, -4.5)), Vector2i(-1, -1), "outside, below the origin")
	assert_eq(grid.local_to_cell(Vector3(10.0, 0.0, 10.0)), Vector2i(16, 14), "outside, past the area")
	assert_false(grid.contains(grid.local_to_cell(Vector3(10.0, 0.0, 10.0))))


func test_r_009_28_cell_size_scales() -> void:
	_config.cell_size_m = 2.0
	var grid: BuildGrid = _grid()
	assert_eq(grid.cell_to_local(Vector2i(1, 1), Vector2i(1, 1)), Vector3(-3.0, 0.0, -1.0))
	assert_eq(grid.local_to_cell(Vector3(-3.0, 0.0, -1.0)), Vector2i(1, 1))
	assert_eq(grid.local_to_cell(Vector3(-2.1, 0.0, -0.1)), Vector2i(1, 1))
	assert_eq(grid.local_to_cell(Vector3(-1.9, 0.0, 0.1)), Vector2i(2, 2))


func test_r_009_28_cell_local_round_trip_every_cell() -> void:
	var grid: BuildGrid = _grid()
	var one: Vector2i = Vector2i(1, 1)
	var bad: int = 0
	for x: int in 12:
		for y: int in 8:
			var cell: Vector2i = Vector2i(x, y)
			if grid.local_to_cell(grid.cell_to_local(cell, one)) != cell:
				bad += 1
	assert_eq(bad, 0, "local_to_cell(cell_to_local(c)) == c for the 96 cells")


func test_r_009_28_cells_in_radius() -> void:
	var grid: BuildGrid = _grid()
	var centre: Vector3 = grid.cell_to_local(Vector2i(3, 2), Vector2i(1, 1))
	var inside: Array[Vector2i] = [Vector2i(3, 2)]
	assert_eq(_sorted(grid.cells_in_radius(centre, 0.3)), inside, "a small circle inside one cell")
	var corner: Vector3 = Vector3(ORIGIN.x + 4.0, 0.0, ORIGIN.z + 3.0)
	var four: Array[Vector2i] = [Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 2), Vector2i(4, 3)]
	assert_eq(_sorted(grid.cells_in_radius(corner, 0.1)), four, "a circle on a corner touches 4 cells")


# --- R-009-31 JSON ---------------------------------------------------------------


func test_r_009_31_data_is_json_types() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _wide, Vector2i(2, 3)).ok)
	var data: Array[Dictionary] = grid.to_data()
	assert_eq(data.size(), 1)
	var entry: Dictionary = data[0]
	assert_eq(entry.size(), 4, "uid, structure_id, zone_id, cell")
	assert_eq(str(entry["uid"]), "a")
	assert_eq(str(entry["structure_id"]), "wide")
	var zone: Array = entry["zone_id"] as Array
	var cell: Array = entry["cell"] as Array
	assert_eq(zone.size(), 2)
	assert_eq(cell.size(), 2)
	var cell_pair: Array[int] = []
	cell_pair.assign(cell)
	var zone_pair: Array[int] = []
	zone_pair.assign(zone)
	assert_eq(cell_pair, [2, 3] as Array[int])
	assert_eq(zone_pair, [ZONE.x, ZONE.y] as Array[int])
	var text: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Array, "it survives JSON.stringify / parse_string")
	assert_eq(grid.to_data().size(), 1, "to_data does not change the grid")


func test_r_009_31_empty_grid_data() -> void:
	var grid: BuildGrid = _grid()
	assert_eq(grid.to_data().size(), 0)
	var result: ActionResult = _grid().load_data([], _catalog)
	assert_true(result.ok, "an empty list is valid state")


func test_r_009_31_round_trip_same_cells() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _big, Vector2i(2, 2)).ok)
	assert_true(grid.occupy("b", _small, Vector2i(11, 7)).ok)
	assert_true(grid.occupy("c", _wide, Vector2i(6, 0)).ok)
	var text: String = JSON.stringify(grid.to_data())
	var parsed: Variant = JSON.parse_string(text)
	var entries: Array = parsed as Array
	var restored: BuildGrid = _grid()
	var result: ActionResult = restored.load_data(entries, _catalog)
	assert_true(result.ok, "numbers come back from JSON as floats and still load")
	assert_eq(_snapshot(restored), _snapshot(grid), "same uids, structures and cells")
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(7, 0), Vector2i(11, 7)]:
		assert_eq(restored.uid_at(cell), grid.uid_at(cell), "occupation of %s" % cell)
	assert_eq(restored.uid_at(Vector2i(3, 3)), "a", "the footprint comes from the StructureData")


func test_r_009_31_bad_data_changes_nothing() -> void:
	var cases: Dictionary[String, Array] = {
		"unknown structure id": [_entry("a", "nope", [1, 1])],
		"cell outside": [_entry("a", "small", [20, 1])],
		"footprint partly outside": [_entry("a", "big", [11, 7])],
		"reserved cell": [_entry("a", "small", [5, 3])],
		"overlapping entries": [_entry("a", "wide", [2, 2]), _entry("b", "small", [3, 2])],
		"valid entry before a bad one": [_entry("a", "small", [1, 1]), _entry("b", "nope", [2, 2])],
		"repeated uid": [_entry("a", "small", [1, 1]), _entry("a", "small", [4, 4])],
		"missing cell key": [{"uid": "a", "structure_id": "small", "zone_id": [0, 0]}],
		"missing uid key": [{"structure_id": "small", "zone_id": [0, 0], "cell": [1, 1]}],
		"cell of the wrong type": [_entry("a", "small", ["x", "y"])],
		"cell of the wrong size": [_entry("a", "small", [1])],
		"entry is not a dictionary": [42],
	}
	for label: String in cases:
		var entries: Array = cases[label]
		var empty_grid: BuildGrid = _grid()
		var result: ActionResult = empty_grid.load_data(entries, _catalog)
		assert_false(result.ok, "%s: rejected" % label)
		assert_eq(empty_grid.get_uids().size(), 0, "%s: an empty grid stays empty" % label)
		var kept: BuildGrid = _grid()
		assert_true(kept.occupy("k", _small, Vector2i(9, 1)).ok)
		var before: Array[String] = _snapshot(kept)
		assert_false(kept.load_data(entries, _catalog).ok, "%s: rejected on a used grid" % label)
		assert_eq(_snapshot(kept), before, "%s: the previous content is kept" % label)
		assert_eq(kept.uid_at(Vector2i(9, 1)), "k", "%s: occupation kept" % label)


# --- R-009-45 move onto own cells --------------------------------------------------


func test_r_009_45_move_onto_own_cells() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _wide, Vector2i(2, 2)).ok)
	assert_false(grid.is_valid(Vector2i(2, 1), Vector2i(3, 2), _none), "overlaps a without moving_uid")
	assert_true(grid.is_valid(Vector2i(2, 1), Vector2i(3, 2), _none, "a"), "a's own cells do not count")
	var result: ActionResult = grid.move("a", Vector2i(3, 2), _none)
	assert_true(result.ok, "shifting by one cell over its own footprint")
	assert_eq(grid.get_cell("a"), Vector2i(3, 2))
	assert_eq(grid.uid_at(Vector2i(2, 2)), "", "the cell it left is free")
	assert_eq(grid.uid_at(Vector2i(3, 2)), "a")
	assert_eq(grid.uid_at(Vector2i(4, 2)), "a")


func test_r_009_45_move_to_same_cell() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _big, Vector2i(2, 2)).ok)
	assert_true(grid.move("a", Vector2i(2, 2), _none).ok, "staying put is valid")
	assert_eq(grid.uid_at(Vector2i(3, 3)), "a")


func test_r_009_45_moving_uid_does_not_free_other_structures() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _wide, Vector2i(2, 2)).ok)
	assert_true(grid.occupy("b", _small, Vector2i(4, 2)).ok)
	assert_false(grid.is_valid(Vector2i(2, 1), Vector2i(3, 2), _none, "a"), "(4,2) is b's")
	assert_false(grid.move("a", Vector2i(3, 2), _none).ok)
	assert_eq(grid.get_cell("a"), Vector2i(2, 2))
	assert_eq(grid.uid_at(Vector2i(4, 2)), "b")


# --- R-009-58 blocked cells on move ----------------------------------------------------


func test_r_009_58_blocked_cell_refuses_move() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _small, Vector2i(1, 1)).ok)
	var blocked: Array[Vector2i] = [Vector2i(6, 6)]
	var result: ActionResult = grid.move("a", Vector2i(6, 6), blocked)
	assert_false(result.ok)
	assert_eq(result.error_key, ERR_PLACEMENT)
	assert_eq(grid.get_cell("a"), Vector2i(1, 1))


func test_r_009_36_remove_frees_cells() -> void:
	var grid: BuildGrid = _grid()
	assert_true(grid.occupy("a", _big, Vector2i(2, 2)).ok)
	assert_true(grid.remove("a").ok, "removed")
	assert_eq(grid.get_uids().size(), 0, "forgotten")
	assert_eq(grid.uid_at(Vector2i(3, 3)), "", "its cells are free")
	assert_true(grid.is_valid(Vector2i(2, 2), Vector2i(2, 2), _none), "and valid again")
	assert_false(grid.remove("a").ok, "an unknown uid changes nothing")
