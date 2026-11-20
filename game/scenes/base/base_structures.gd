class_name BaseStructures
extends Node
## The structures placed in the base (spec 009): world state outside any
## player (constitution P4), so it lives under World and outlives the base
## scene. It owns the BuildGrid and, while the base is loaded, an instance of
## each structure under the base's %Structures; the instances leave with the
## base and are made again from the state (they are static, not pooled).
## place() and move() take the requesting player: the host decides here in
## co-op (architecture §3 rule 4, §12). Presentation only asks.
## Spec 012: each structure's limit (StructureData.max_count), the state of
## chests and generators in its StructureStates child (plan D5), the maximum
## battery bonus of the placed generators, the players' requests to collect
## batteries, and the uses of a chest or a generator relayed as structure_used.

## A player interacted with a placed chest or generator (relayed from its instance).
signal structure_used(structure_uid: String, user: Node3D)
## State signal: the maximum battery bonus of the placed generators changed (plan D9).
signal max_battery_bonus_changed(bonus: float)

const ERR_INVALID_PLACEMENT := BuildGrid.ERR_INVALID_PLACEMENT
const MSG_STRUCTURE_LIMIT := &"MSG_STRUCTURE_LIMIT"
## Save contract (spec 010, architecture §10.2).
const SAVE_KEY := &"structures"
const _PLACED_KEY := "placed"

## The same resource the base scene uses (a test guards it).
@export var grid_config: BuildGridData

## GameManager.get_time_service() at _ready() unless assigned before (R-012-19,
## plan D21). Tests assign a FakeTimeService before placing or binding the base.
var time_service: ITimeService

var _grid: BuildGrid = null
var _base: BaseZone = null
## uid → instance in the loaded base.
var _instances: Dictionary[String, Node3D] = {}
var _interactions_enabled: bool = true
var _states: StructureStates = null
var _max_battery_bonus: float = 0.0


func _ready() -> void:
	if time_service == null:
		time_service = GameManager.get_time_service()
	_states = StructureStates.new()
	_states.name = "StructureStates"
	add_child(_states)
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


## Checks the limit (R-012-09), place, base and materials, then takes the
## cells, charges the player, makes the structure's state (spec 012), its
## instance and the bonus, and emits structure_built once (R-009-35, plan D5).
## Any refusal changes nothing.
func place(player: Robot, recipe: RecipeData, cell: Vector2i) -> ActionResult:
	if player == null or recipe == null or recipe.result_structure == null:
		push_error("BaseStructures '%s': place() needs a player and a structure recipe." % name)
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	var structure: StructureData = recipe.result_structure
	if is_at_limit(structure):
		return ActionResult.failure(MSG_STRUCTURE_LIMIT)
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
	_states.create_for(uid, structure, time_service.now_unix())
	_instantiate(uid)
	_update_bonus()
	EventBus.structure_built.emit(uid)
	return ActionResult.success()


## How many structures of structure_id are placed.
func count_of(structure_id: StringName) -> int:
	var count: int = 0
	for uid: String in _grid.get_uids():
		if _grid.get_structure_id(uid) == structure_id:
			count += 1
	return count


## max_count > 0 and that many are already placed (R-012-08, R-012-09).
func is_at_limit(structure: StructureData) -> bool:
	return structure.max_count > 0 and count_of(structure.id) >= structure.max_count


## The largest max_battery_bonus among the placed generators; 0.0 when none (plan D9).
func get_max_battery_bonus() -> float:
	return _max_battery_bonus


## null when structure_uid is not a placed chest.
func get_chest_contents(structure_uid: String) -> InventoryComponent:
	return _states.get_chest_contents(structure_uid)


## The generator's state, read with time_service; -1 when full. Not a
## generator → push_error, -1.
func seconds_to_next_battery(structure_uid: String) -> int:
	var generator: WindGeneratorComponent = _states.get_generator(structure_uid)
	if generator == null:
		push_error("BaseStructures '%s': '%s' is not a placed generator." % [name, structure_uid])
		return -1
	return generator.get_seconds_to_next(time_service.now_unix())


## The player's request to collect a generator's batteries (R-012-20, plan D8):
## EventBus.batteries_collected when any battery moved. No player, or a uid
## that is not a placed generator → push_error, ERR_INVALID_REQUEST.
func collect_batteries(player: Robot, structure_uid: String) -> ActionResult:
	var generator: WindGeneratorComponent = _states.get_generator(structure_uid)
	if player == null or generator == null:
		push_error(
			"BaseStructures '%s': collect_batteries() needs a player and a placed generator ('%s')."
			% [name, structure_uid]
		)
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var result: ActionResult = generator.collect(player.inventory, time_service.now_unix())
	if result.ok:
		EventBus.batteries_collected.emit(structure_uid, player.player_uid)
	return result


## At no cost (BALANCE §5.6). Invalid target or unknown uid → no change.
func move(player: Robot, structure_uid: String, cell: Vector2i) -> ActionResult:
	if player == null:
		push_error("BaseStructures '%s': move() needs a player." % name)
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	if not is_bound():
		return ActionResult.failure(ERR_INVALID_PLACEMENT)
	var moved: ActionResult = _grid.move(structure_uid, cell, _robot_cells())
	if not moved.ok:
		return moved
	if _instances.has(structure_uid):
		_instances[structure_uid].global_position = cell_to_world(get_structure(structure_uid), cell)
	EventBus.structure_moved.emit(structure_uid)
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


## All or nothing; placed chests and generators start new (spec 012), and with
## the base loaded the instances follow the new state.
func load_data(data: Array) -> ActionResult:
	return _load(data, {})


func get_save_key() -> StringName:
	return SAVE_KEY


## The placed structures as BuildGrid.to_data() gives them (R-010-31), plus
## the chests' contents and the generators' state when there are any (R-012-39,
## plan D6): a base without them saves as in spec 010.
func to_save_data() -> Dictionary:
	var part: Dictionary = {_PLACED_KEY: to_data()}
	var states: Dictionary = _states.to_data()
	for key: String in states:
		var entries: Dictionary = states[key]
		if not entries.is_empty():
			part[key] = entries
	return part


## Entries of a structure the catalog no longer has → push_error and skipped
## (R-010-11); the rest loads all or nothing, then the chests and generators
## (plan D5). Emits no structure_built nor any other fact (D15, R-012-41); only
## max_battery_bonus_changed, a state signal.
func from_save_data(data: Dictionary) -> void:
	var placed: Variant = data.get(_PLACED_KEY)
	if not placed is Array:
		push_error("BaseStructures '%s': no saved structures in %s; none loaded." % [name, data])
		return
	var catalog: DataCatalog = DataRegistry.get_catalog()
	var known: Array = []
	for entry: Variant in placed as Array:
		var fields: Dictionary = entry if entry is Dictionary else {}
		var structure_id: String = str(fields.get("structure_id", ""))
		if catalog == null or not catalog.has_structure(StringName(structure_id)):
			push_error("BaseStructures '%s': saved structure %s is unknown; it is lost." % [name, entry])
			continue
		known.append(entry)
	if not _load(known, data).ok:
		push_error("BaseStructures '%s': the saved structures do not fit the grid; none loaded." % name)


## Grid, then the old instances go, then the states, then the instances again
## and the bonus: an instance never binds to a state that is being freed (plan D5).
func _load(placed: Array, saved_states: Dictionary) -> ActionResult:
	var loaded: ActionResult = _grid.load_data(placed, DataRegistry.get_catalog())
	if not loaded.ok:
		return loaded
	for instance: Node3D in _instances.values():
		instance.queue_free()
	_instances.clear()
	_states.load_data(saved_states, _placed_structures(), time_service.now_unix())
	if is_bound():
		bind_base(_base)
	_update_bonus()
	return loaded


## uid → data of every placed structure.
func _placed_structures() -> Dictionary[String, StructureData]:
	var placed: Dictionary[String, StructureData] = {}
	for uid: String in _grid.get_uids():
		placed[uid] = get_structure(uid)
	return placed


## Publishes the largest bonus of the placed generators when it changed (plan D9).
func _update_bonus() -> void:
	var bonus: float = 0.0
	for structure: StructureData in _placed_structures().values():
		var generator: WindGeneratorData = structure as WindGeneratorData
		if generator != null:
			bonus = maxf(bonus, generator.max_battery_bonus)
	if bonus == _max_battery_bonus:
		return
	_max_battery_bonus = bonus
	max_battery_bonus_changed.emit(bonus)


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
	_connect_instance(uid, instance)


## A chest or a generator reports its uses here; a generator shows its state.
func _connect_instance(uid: String, instance: Node3D) -> void:
	var chest: StorageChest = instance as StorageChest
	if chest != null:
		chest.used.connect(_on_instance_used.bind(uid))
	var generator: WindGenerator = instance as WindGenerator
	if generator != null:
		generator.bind_state(_states.get_generator(uid), time_service)
		generator.used.connect(_on_instance_used.bind(uid))


func _on_instance_used(user: Node3D, structure_uid: String) -> void:
	structure_used.emit(structure_uid, user)


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
