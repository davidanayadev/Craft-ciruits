class_name BuildGrid
extends RefCounted
## Pure rules of the base placement grid (spec 009, ACTION_PLAN 2.8): which
## cells a structure covers, whether a placement is valid, the conversion
## between a cell and its local position in the base, and the state of the
## placed structures in JSON types. No nodes: BaseStructures owns one and
## keeps it across loads of the base.
## Cell (0, 0) has its corner at BuildGridData.area_origin_local; cell.x runs
## along local X and cell.y along local Z. A structure is anchored on its
## lowest cell and covers footprint cells from there.

const NO_CELL := Vector2i(-1, -1)
const ERR_INVALID_PLACEMENT := &"ERR_INVALID_PLACEMENT"
const NO_UID := ""

var _config: BuildGridData
var _zone_id: Vector2i
## uid → anchor cell.
var _cells: Dictionary[String, Vector2i] = {}
## uid → structure id.
var _structure_ids: Dictionary[String, StringName] = {}
## uid → footprint, read from the StructureData when it was placed.
var _footprints: Dictionary[String, Vector2i] = {}
## Every covered cell → uid.
var _occupancy: Dictionary[Vector2i, String] = {}


func _init(p_config: BuildGridData, p_zone_id: Vector2i) -> void:
	_config = p_config
	_zone_id = p_zone_id


func contains(cell: Vector2i) -> bool:
	var size: Vector2i = _config.area_size_cells
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Every covered cell inside the area, not reserved, not taken by another
## structure (moving_uid's own cells do not count) and not blocked (where a
## robot stands).
func is_valid(
	footprint: Vector2i, cell: Vector2i, blocked: Array[Vector2i], moving_uid: String = NO_UID
) -> bool:
	for covered: Vector2i in _covered_cells(footprint, cell):
		if not contains(covered) or _config.reserved_cells.has(covered) or blocked.has(covered):
			return false
		var owner_uid: String = _occupancy.get(covered, NO_UID)
		if owner_uid != NO_UID and owner_uid != moving_uid:
			return false
	return true


## Invalid cell or a uid already placed → ERR_INVALID_PLACEMENT, no change.
## Blocked cells are the caller's to check: loading saved state has no robots.
func occupy(uid: String, structure: StructureData, cell: Vector2i) -> ActionResult:
	var empty: Array[Vector2i] = []
	if uid.is_empty() or structure == null or _cells.has(uid):
		return ActionResult.failure(ERR_INVALID_PLACEMENT)
	if not is_valid(structure.footprint, cell, empty):
		return ActionResult.failure(ERR_INVALID_PLACEMENT)
	_cells[uid] = cell
	_structure_ids[uid] = structure.id
	_footprints[uid] = structure.footprint
	_mark(uid, true)
	return ActionResult.success()


## Frees the old cells and takes the new ones in one step. Unknown uid or an
## invalid target → ERR_INVALID_PLACEMENT, no change.
func move(uid: String, cell: Vector2i, blocked: Array[Vector2i]) -> ActionResult:
	if not _cells.has(uid) or not is_valid(_footprints[uid], cell, blocked, uid):
		return ActionResult.failure(ERR_INVALID_PLACEMENT)
	_mark(uid, false)
	_cells[uid] = cell
	_mark(uid, true)
	return ActionResult.success()


## Frees the cells of uid and forgets it. Unknown uid → ERR_INVALID_PLACEMENT,
## no change. Placing undoes itself with it when the payment fails.
func remove(uid: String) -> ActionResult:
	if not _cells.has(uid):
		return ActionResult.failure(ERR_INVALID_PLACEMENT)
	_mark(uid, false)
	_cells.erase(uid)
	_structure_ids.erase(uid)
	_footprints.erase(uid)
	return ActionResult.success()


## Anchor cell; NO_CELL for an unknown uid.
func get_cell(uid: String) -> Vector2i:
	return _cells.get(uid, NO_CELL)


## "" when the cell is free or outside the area.
func uid_at(cell: Vector2i) -> String:
	return _occupancy.get(cell, NO_UID)


func get_uids() -> Array[String]:
	var uids: Array[String] = []
	uids.assign(_cells.keys())
	return uids


## &"" for an unknown uid.
func get_structure_id(uid: String) -> StringName:
	return _structure_ids.get(uid, &"")


## The valid cell closest to near (Euclidean; ties go to the first in row
## order), or NO_CELL when the footprint fits nowhere. With no blocked cells it
## also answers "does it fit anywhere" (R-009-27).
func find_free_cell(footprint: Vector2i, near: Vector2i, blocked: Array[Vector2i]) -> Vector2i:
	var best: Vector2i = NO_CELL
	var best_distance: int = -1
	for y: int in _config.area_size_cells.y:
		for x: int in _config.area_size_cells.x:
			var cell: Vector2i = Vector2i(x, y)
			var distance: int = (cell - near).length_squared()
			if best_distance != -1 and distance >= best_distance:
				continue
			if is_valid(footprint, cell, blocked):
				best = cell
				best_distance = distance
	return best


## Centre of the footprint placed on cell, local to the base.
func cell_to_local(cell: Vector2i, footprint: Vector2i) -> Vector3:
	var size: float = _config.cell_size_m
	var centre: Vector2 = (Vector2(cell) + Vector2(footprint) / 2.0) * size
	return _config.area_origin_local + Vector3(centre.x, 0.0, centre.y)


## The cell that holds a local point; the height is ignored. May be outside the area.
func local_to_cell(local: Vector3) -> Vector2i:
	var offset: Vector3 = (local - _config.area_origin_local) / _config.cell_size_m
	return Vector2i(floori(offset.x), floori(offset.z))


## Cells touched by a circle on the floor (where a robot stands, R-009-58).
## May include cells outside the area.
func cells_in_radius(local: Vector3, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var low: Vector2i = local_to_cell(local - Vector3(radius, 0.0, radius))
	var high: Vector2i = local_to_cell(local + Vector3(radius, 0.0, radius))
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			if _distance_to_cell(local, Vector2i(x, y)) < radius:
				cells.append(Vector2i(x, y))
	return cells


## JSON types only (R-009-31); the footprint is not saved, it comes from the
## StructureData on load.
func to_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for uid: String in _cells:
		var cell: Vector2i = _cells[uid]
		data.append({
			"uid": uid,
			"structure_id": String(_structure_ids[uid]),
			"zone_id": [_zone_id.x, _zone_id.y],
			"cell": [cell.x, cell.y],
		})
	return data


## Replaces the state with data, all or nothing: every entry is checked (known
## structure, this zone, valid cell, no overlap, no repeated uid) before
## anything changes. Any problem → ERR_INVALID_PLACEMENT and the state stays.
func load_data(data: Array, catalog: DataCatalog) -> ActionResult:
	var staged: BuildGrid = BuildGrid.new(_config, _zone_id)
	for entry: Variant in data:
		if not staged._load_entry(entry, catalog):
			return ActionResult.failure(ERR_INVALID_PLACEMENT)
	_cells = staged._cells
	_structure_ids = staged._structure_ids
	_footprints = staged._footprints
	_occupancy = staged._occupancy
	return ActionResult.success()


func _load_entry(entry: Variant, catalog: DataCatalog) -> bool:
	if not entry is Dictionary:
		return false
	var fields: Dictionary = entry
	var uid: Variant = fields.get("uid")
	var structure_id: Variant = fields.get("structure_id")
	if not uid is String or not structure_id is String or catalog == null:
		return false
	if not catalog.has_structure(StringName(structure_id as String)):
		return false
	var zone_pair: Array[int] = _to_pair(fields.get("zone_id"))
	var cell_pair: Array[int] = _to_pair(fields.get("cell"))
	if zone_pair.is_empty() or cell_pair.is_empty():
		return false
	if Vector2i(zone_pair[0], zone_pair[1]) != _zone_id:
		return false
	var cell: Vector2i = Vector2i(cell_pair[0], cell_pair[1])
	var structure: StructureData = catalog.get_structure(StringName(structure_id as String))
	return occupy(uid as String, structure, cell).ok


## A [x, y] pair of whole numbers (JSON gives floats) → [x, y] as ints;
## anything else → empty.
static func _to_pair(value: Variant) -> Array[int]:
	var numbers: Array[int] = []
	if not value is Array or (value as Array).size() != 2:
		return numbers
	for item: Variant in value as Array:
		if not (item is int or item is float):
			return []
		var number: float = item
		if number != floorf(number):
			return []
		numbers.append(floori(number))
	return numbers


static func _covered_cells(footprint: Vector2i, cell: Vector2i) -> Array[Vector2i]:
	var covered: Array[Vector2i] = []
	for y: int in footprint.y:
		for x: int in footprint.x:
			covered.append(cell + Vector2i(x, y))
	return covered


func _mark(uid: String, taken: bool) -> void:
	for covered: Vector2i in _covered_cells(_footprints[uid], _cells[uid]):
		if taken:
			_occupancy[covered] = uid
		else:
			_occupancy.erase(covered)


## Distance on the floor from a point to the nearest point of a cell.
func _distance_to_cell(local: Vector3, cell: Vector2i) -> float:
	var size: float = _config.cell_size_m
	var low: Vector2 = Vector2(_config.area_origin_local.x, _config.area_origin_local.z) + Vector2(cell) * size
	var point: Vector2 = Vector2(local.x, local.z)
	var nearest: Vector2 = point.clamp(low, low + Vector2(size, size))
	return point.distance_to(nearest)
