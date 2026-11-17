class_name BaseStructures
extends Node
## The structures placed in the base (spec 009): world state outside any
## player (constitution P4), so it lives under World and outlives the base
## scene. It owns the BuildGrid and, while the base is loaded, an instance of
## each structure under the base's %Structures; the instances leave with the
## base and are made again from the state (they are static, not pooled).
## place() and move() take the requesting player: the host decides here in
## co-op (architecture §3 rule 4, §12). Presentation only asks.

const ERR_INVALID_PLACEMENT := BuildGrid.ERR_INVALID_PLACEMENT

## The same resource the base scene uses (a test guards it).
@export var grid_config: BuildGridData

var _grid: BuildGrid = null
var _base: BaseZone = null
## uid → instance in the loaded base.
var _instances: Dictionary[String, Node3D] = {}
var _interactions_enabled: bool = true


func _ready() -> void:
	var base_zone: ZoneData = DataRegistry.get_base_zone()
	if grid_config == null or base_zone == null:
		push_error("BaseStructures '%s': needs grid_config and a base zone in the catalog." % name)
		return
	_grid = BuildGrid.new(grid_config, base_zone.zone_id)


## The base was loaded: its structures stand on their cells again.
func bind_base(base: BaseZone) -> void:
	_base = base
	_instances.clear()
	for uid: String in _grid.get_uids():
		_instantiate(uid)


## The base is being unloaded; the instances leave with it, the state stays.
func unbind_base() -> void:
	_base = null
	_instances.clear()


func is_bound() -> bool:
	return _base != null


## The loaded base, or null.
func get_base() -> BaseZone:
	return _base


## Inside the buildable area (not necessarily free).
func is_in_area(cell: Vector2i) -> bool:
	return _grid.contains(cell)


## Room for the footprint somewhere, wherever the robots stand (R-009-38):
## a robot can step aside.
func fits_anywhere(structure: StructureData) -> bool:
	var none: Array[Vector2i] = []
	return _grid.find_free_cell(structure.footprint, Vector2i.ZERO, none) != BuildGrid.NO_CELL


## Valid with the cells of every robot blocked (R-009-58). False without a base.
func can_place(structure: StructureData, cell: Vector2i, moving_uid: String = "") -> bool:
	if not is_bound() or structure == null:
		return false
	return _grid.is_valid(structure.footprint, cell, _robot_cells(), moving_uid)


## Checks place, base and materials, then charges the player, takes the cells
## and emits structure_built once (R-009-35). Any refusal changes nothing.
func place(player: Robot, recipe: RecipeData, cell: Vector2i) -> ActionResult:
	if player == null or recipe == null or recipe.result_structure == null:
		push_error("BaseStructures '%s': place() needs a player and a structure recipe." % name)
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	var structure: StructureData = recipe.result_structure
	if not can_place(structure, cell):
		return ActionResult.failure(ERR_INVALID_PLACEMENT)
	if not CraftingSystem.can_pay(player.inventory.get_slots(), recipe):
		return ActionResult.failure(CraftingSystem.ERR_NOT_ENOUGH_MATERIALS)
	# Cells first, payment second: whichever fails, nothing stays half done.
	var uid: String = Uid.generate()
	var taken: ActionResult = _grid.occupy(uid, structure, cell)
	if not taken.ok:
		push_error("BaseStructures '%s': a checked cell %s could not be taken." % [name, cell])
		return taken
	var paid: ActionResult = player.inventory.remove_many(CraftingSystem.cost_of(recipe))
	if not paid.ok:
		_grid.remove(uid)
		return paid
	_instantiate(uid)
	EventBus.structure_built.emit(uid)
	return ActionResult.success()


## At no cost (BALANCE §5.6). Invalid target or unknown uid → no change.
func move(player: Robot, structure_uid: String, cell: Vector2i) -> ActionResult:
	if player == null:
		push_error("BaseStructures '%s': move() needs a player." % name)
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	if not is_bound():
		return ActionResult.failure(ERR_INVALID_PLACEMENT)
	var moved: ActionResult = _grid.move(structure_uid, cell, _robot_cells())
	if moved.ok and _instances.has(structure_uid):
		_instances[structure_uid].global_position = cell_to_world(get_structure(structure_uid), cell)
	return moved


## "" when no placed structure covers the cell; the bench and the exit point
## are never structures (R-009-60).
func structure_at(cell: Vector2i) -> String:
	return _grid.uid_at(cell)


## Null for an unknown uid.
func get_structure(structure_uid: String) -> StructureData:
	var structure_id: StringName = _grid.get_structure_id(structure_uid)
	if structure_id.is_empty():
		return null
	return DataRegistry.get_structure(structure_id)


func get_cell(structure_uid: String) -> Vector2i:
	return _grid.get_cell(structure_uid)


## The valid cell closest to world_position, or BuildGrid.NO_CELL.
func nearest_free_cell(structure: StructureData, world_position: Vector3) -> Vector2i:
	if not is_bound():
		return BuildGrid.NO_CELL
	return _grid.find_free_cell(structure.footprint, cell_at(world_position), _robot_cells())


## The cell under a world position of the loaded base; may be outside the area.
func cell_at(world_position: Vector3) -> Vector2i:
	if not is_bound():
		return BuildGrid.NO_CELL
	return _grid.local_to_cell(_base.to_local(world_position))


## Where structure stands on cell, in the loaded base.
func cell_to_world(structure: StructureData, cell: Vector2i) -> Vector3:
	if not is_bound():
		return Vector3.ZERO
	return _base.to_global(_grid.cell_to_local(cell, structure.footprint))


## Off while a structure is being placed or moved (R-009-50); new instances
## follow the current setting.
func set_interactions_enabled(enabled: bool) -> void:
	_interactions_enabled = enabled
	for instance: Node3D in _instances.values():
		_set_instance_interactions(instance, enabled)


## JSON types only (R-009-31): spec 010 saves it as it is.
func to_data() -> Array[Dictionary]:
	return _grid.to_data()


## All or nothing; with the base loaded the instances follow the new state.
func load_data(data: Array) -> ActionResult:
	var loaded: ActionResult = _grid.load_data(data, DataRegistry.get_catalog())
	if loaded.ok and is_bound():
		for instance: Node3D in _instances.values():
			instance.queue_free()
		bind_base(_base)
	return loaded


func _instantiate(uid: String) -> void:
	var structure: StructureData = get_structure(uid)
	if structure == null or structure.scene == null:
		push_error("BaseStructures '%s': structure '%s' has no scene." % [name, uid])
		return
	var instance: Node3D = structure.scene.instantiate() as Node3D
	_base.get_structures_root().add_child(instance)
	instance.global_position = cell_to_world(structure, _grid.get_cell(uid))
	_set_instance_interactions(instance, _interactions_enabled)
	_instances[uid] = instance


func _set_instance_interactions(instance: Node3D, enabled: bool) -> void:
	for node: Node in instance.find_children("*", "Area3D", true, false):
		var interactable: InteractableComponent = node as InteractableComponent
		if interactable != null:
			interactable.enabled = enabled


## Cells under every player robot, so nothing is placed on one (R-009-58).
func _robot_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for node: Node in get_tree().get_nodes_in_group(Robot.PLAYER_GROUP):
		var robot: Robot = node as Robot
		if robot != null:
			cells.append_array(
				_grid.cells_in_radius(_base.to_local(robot.global_position), robot.get_footprint_radius())
			)
	return cells
