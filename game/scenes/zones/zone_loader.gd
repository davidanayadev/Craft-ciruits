class_name ZoneLoader
extends Node
## Keeps exactly one zone loaded in ZoneSlot and travels between zones (spec
## 009, architecture §6). A travel loads the scene in the background, unloads
## the current zone (its pooled entities back to their pools first), places
## and populates the new one, puts the players on its spawn point and emits
## zone_changed once. It also counts the visit of a farm zone left through its
## exit point, and repopulates the loaded zone when its visit counter goes up.
## Main shows the loading screen and freezes World while a travel runs; this
## node hangs from Main, outside World, so it keeps processing meanwhile.

signal travel_started(zone_id: Vector2i)
## The new zone is in ZoneSlot, populated, with the players on it. Whoever
## wires zone-specific signals connects them here.
signal zone_loaded(zone: Zone)
signal travel_finished(zone_id: Vector2i)
## Loading failed: the current zone is untouched.
signal travel_failed(zone_id: Vector2i)

@export var zone_slot: Node3D
@export var players_root: Node3D
@export var zombie_pool: ObjectPool
@export var impact_pool: ObjectPool
@export var dropped_item_pool: ObjectPool
@export var dropped_items: DroppedItemSpawner
@export var base_structures: BaseStructures

var _current: Zone = null
var _target: ZoneData = null
var _travelling: bool = false
## The travel started at an exit point: leaving a farm zone counts its visit.
var _leaving_by_exit: bool = false


func _ready() -> void:
	set_process(false)
	GameManager.zone_visit_changed.connect(_on_zone_visit_changed)


## Unknown zone_id or a travel in progress → push_error, ERR_INVALID_REQUEST
## and the current zone stays (R-009-06). Travelling to the loaded zone loads
## it again (a death inside the base).
func travel_to(zone_id: Vector2i) -> ActionResult:
	return _start_travel(zone_id, false)


func is_travelling() -> bool:
	return _travelling


## Null before the first travel ends.
func get_current_zone() -> Zone:
	return _current


func _process(_delta: float) -> void:
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		_target.scene_path
	)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	set_process(false)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("the scene '%s' did not load" % _target.scene_path)
		return
	var zone: Zone = _instantiate(ResourceLoader.load_threaded_get(_target.scene_path) as PackedScene)
	if zone == null:
		return
	_unload_current()
	_load(zone)
	_finish(zone)


func _start_travel(zone_id: Vector2i, by_exit: bool) -> ActionResult:
	var catalog: DataCatalog = DataRegistry.get_catalog()
	if _travelling:
		push_error("ZoneLoader '%s': a travel is already in progress; %s refused." % [name, zone_id])
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	if catalog == null or not catalog.has_zone(zone_id):
		push_error("ZoneLoader '%s': unknown zone %s." % [name, zone_id])
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	_target = catalog.get_zone(zone_id)
	var requested: Error = ResourceLoader.load_threaded_request(_target.scene_path)
	if requested != OK:
		push_error("ZoneLoader '%s': cannot load '%s' (%s)." % [name, _target.scene_path, error_string(requested)])
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	_travelling = true
	_leaving_by_exit = by_exit
	travel_started.emit(zone_id)
	# Deferred, after what travel_started queued (Main freezes World deferred):
	# even a scene already in cache never loads before the world is frozen.
	set_process.call_deferred(true)
	return ActionResult.success()


## The scene's root must be the Zone of its ZoneData, of the class of its kind.
func _instantiate(scene: PackedScene) -> Zone:
	var node: Node = scene.instantiate() if scene != null else null
	var zone: Zone = node as Zone
	var expected_kind: bool = (
		zone != null
		and zone.data == _target
		and (zone is FarmZone) == (_target.kind == ZoneData.Kind.FARM)
		and (zone is BaseZone) == (_target.kind == ZoneData.Kind.BASE)
	)
	if not expected_kind:
		if node != null:
			node.free()
		_fail("the scene '%s' is not the zone of its ZoneData" % _target.scene_path)
		return null
	return zone


## Pooled entities go back to their pools first, so none is freed with the
## zone (R-009-04). The visit counts after the zone is gone (R-009-14), so the
## repopulation it triggers finds nothing to repopulate.
func _unload_current() -> void:
	if _current == null:
		return
	var leaving: Zone = _current
	var farm: FarmZone = leaving as FarmZone
	if farm != null:
		farm.despawn_enemies()
	dropped_items.unbind_zone()
	if leaving is BaseZone:
		base_structures.unbind_base()
	zone_slot.remove_child(leaving)
	leaving.queue_free()
	_current = null
	if _leaving_by_exit and leaving.data.counts_visits():
		GameManager.increment_visit_count(leaving.data.zone_id)


func _load(zone: Zone) -> void:
	zone_slot.add_child(zone)
	_current = zone
	GameManager.set_current_zone(zone.data.zone_id)
	var farm: FarmZone = zone as FarmZone
	if farm != null:
		_populate(farm)
	var base: BaseZone = zone as BaseZone
	if base != null:
		base_structures.bind_base(base)
	# After populating, before anyone can interact (R-009-17, R-008-23).
	dropped_items.bind_zone(zone.data.zone_id, zone)
	zone.exit_requested.connect(_on_exit_requested)


## The boxes and enemies of its current visit (R-009-16), with the pools
## prewarmed behind the loading screen so nothing is created mid-game (P12).
func _populate(farm: FarmZone) -> void:
	var enemy_max: int = farm.data.enemy_count_max
	zombie_pool.prewarm(enemy_max)
	# At most one burst per enemy and swing, and a burst ends before the next.
	impact_pool.prewarm(enemy_max)
	# One drop per zombie, one throw per inventory slot and one death per player.
	var drops: int = enemy_max
	for robot: Robot in _players():
		drops += robot.inventory.get_slot_count() + 1
	dropped_item_pool.prewarm(drops)
	var visit: int = GameManager.get_visit_count(farm.data.zone_id)
	farm.generate(GameManager.get_world_seed(), visit)
	farm.spawn_enemies(GameManager.get_world_seed(), visit, zombie_pool)


func _finish(zone: Zone) -> void:
	for robot: Robot in _players():
		robot.place_at(zone.get_spawn_position())
	zone_loaded.emit(zone)
	_travelling = false
	EventBus.zone_changed.emit(zone.data.zone_id)
	travel_finished.emit(zone.data.zone_id)


func _fail(reason: String) -> void:
	push_error("ZoneLoader '%s': travel to %s failed: %s." % [name, _target.zone_id, reason])
	_travelling = false
	travel_failed.emit(_target.zone_id)


func _players() -> Array[Robot]:
	var robots: Array[Robot] = []
	for node: Node in players_root.get_children():
		var robot: Robot = node as Robot
		if robot != null:
			robots.append(robot)
	return robots


## Free travel, no limit (R-009-11); every player goes with the zone.
func _on_exit_requested(destination: ZoneData, _traveller: Node3D) -> void:
	_start_travel(destination.zone_id, true)


## A new visit of the loaded zone: new enemies and closed boxes (R-008-09).
## During a travel the zone is about to be replaced: nothing to do.
func _on_zone_visit_changed(zone_id: Vector2i, visit: int) -> void:
	if _loaded_farm(zone_id) == null:
		return
	# Deferred: the signal arrives in the middle of a physics step (a death),
	# and repopulating takes bodies out of the tree.
	_repopulate.call_deferred(zone_id, visit)


func _repopulate(zone_id: Vector2i, visit: int) -> void:
	var farm: FarmZone = _loaded_farm(zone_id)
	if farm == null:
		return
	farm.repopulate(GameManager.get_world_seed(), visit, zombie_pool)
	# Before anyone can interact again (R-008-23).
	dropped_items.discard_expired_now()


## The loaded zone when it is the farm zone zone_id and no travel runs; else null.
func _loaded_farm(zone_id: Vector2i) -> FarmZone:
	var farm: FarmZone = _current as FarmZone
	if farm == null or _travelling or farm.data.zone_id != zone_id:
		return null
	return farm
