class_name DroppedItemSpawner
extends Node3D
## Creates the dropped items, expires them and returns them to their pool
## (spec 008). It is the parent of the active ones and lives under World,
## outside the zone: repopulating or unloading a zone does not touch them.
## The clock comes from outside (GameManager's in the game, a fake one in
## tests): it never creates one.

## The device clock has whole seconds, so checking more often finds nothing new.
const EXPIRY_CHECK_INTERVAL_S := 1.0

@export var pool: ObjectPool
@export var config: DroppedItemConfigData

var time_service: ITimeService

var _items: Array[DroppedItem] = []
var _zone_id: Vector2i = Vector2i.ZERO
var _zone_root: Node3D = null
var _expiry_timer: Timer = null


func _ready() -> void:
	_expiry_timer = Timer.new()
	_expiry_timer.wait_time = EXPIRY_CHECK_INTERVAL_S
	_expiry_timer.timeout.connect(_on_expiry_timer_timeout)
	add_child(_expiry_timer)


## The zone that is loaded: what falls from now on belongs to it, at a
## position local to zone_root. ZoneLoader calls it in spec 009.
func bind_zone(zone_id: Vector2i, zone_root: Node3D) -> void:
	_zone_id = zone_id
	_zone_root = zone_root


## The zone given to bind_zone().
func get_zone_id() -> Vector2i:
	return _zone_id


## Moves every stack of source into one new dropped item. Empty source → null.
func drop_inventory(source: InventoryComponent, world_position: Vector3) -> DroppedItem:
	if source == null or source.is_empty():
		return null
	var item: DroppedItem = _spawn(world_position, source.get_slot_count())
	if item == null:
		return null
	var slot_indices: Array[int] = []
	for index: int in source.get_slot_count():
		slot_indices.append(index)
	item.get_contents().take_from(source, slot_indices)
	return item


## Moves quantity of one slot of source into a new dropped item; the rest
## stays in the slot. Invalid slot or quantity → ERR_INVALID_REQUEST and
## nothing is created.
func drop_from_slot(
	source: InventoryComponent, slot_index: int, quantity: int, world_position: Vector3
) -> ActionResult:
	if source == null or not InventoryRules.can_split(source.get_slots(), slot_index, quantity):
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	var item: DroppedItem = _spawn(world_position, 1)
	if item == null:
		return ActionResult.failure(InventoryComponent.ERR_INVALID_REQUEST)
	var result: InventoryAddResult = item.get_contents().take_amount_from(
		source, slot_index, quantity
	)
	# Nothing moved (an item the catalog does not know): no empty item stays.
	if item.get_contents().is_empty():
		_release(item)
	return result


## A new dropped item holding copies of stacks (an enemy's loot). Empty → null.
func drop_stacks(stacks: Array[ItemStack], world_position: Vector3) -> DroppedItem:
	if stacks.is_empty():
		return null
	var item: DroppedItem = _spawn(world_position, stacks.size())
	if item == null:
		return null
	if not item.get_contents().add_stacks(stacks).ok:
		push_error("DroppedItemSpawner '%s': the stacks did not fit in their dropped item." % name)
	return item


## discard_expired() at the time of this spawner's own clock, the one the
## drop times were read from.
func discard_expired_now() -> void:
	if time_service == null:
		push_error("DroppedItemSpawner '%s': time_service must be assigned." % name)
		return
	discard_expired(time_service.now_unix())


## Returns to the pool every item whose lifetime ended; nobody gets its stacks.
func discard_expired(now_unix: int) -> void:
	if config == null:
		push_error("DroppedItemSpawner '%s': config must be assigned." % name)
		return
	for item: DroppedItem in _items.duplicate():
		if DroppedItemRules.is_expired(item.dropped_at_unix, now_unix, config.lifetime_s):
			_release(item)


## The active dropped items, oldest first.
func get_items() -> Array[DroppedItem]:
	return _items


## Whether the periodic expiry check is running: only while there are items.
func is_checking_expiry() -> bool:
	return _expiry_timer != null and not _expiry_timer.is_stopped()


func to_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for item: DroppedItem in _items:
		data.append(item.to_data())
	return data


func _spawn(world_position: Vector3, slot_count: int) -> DroppedItem:
	if pool == null or time_service == null or _zone_root == null:
		push_error(
			"DroppedItemSpawner '%s': needs a pool, a time service and a bound zone." % name
		)
		return null
	var instance: Node = pool.acquire()
	var item: DroppedItem = instance as DroppedItem
	if item == null:
		push_error(
			"DroppedItemSpawner '%s': the pool '%s' does not hold dropped items."
			% [name, pool.name]
		)
		if instance != null:
			pool.release(instance)
		return null
	item.position = to_local(world_position)
	add_child(item)
	item.setup(
		Uid.generate(),
		_zone_id,
		_zone_root.to_local(world_position),
		time_service.now_unix(),
		slot_count
	)
	item.emptied.connect(_on_item_emptied)
	_items.append(item)
	if _expiry_timer.is_stopped():
		_expiry_timer.start()
	return item


func _release(item: DroppedItem) -> void:
	_items.erase(item)
	item.emptied.disconnect(_on_item_emptied)
	item.reset()
	pool.release(item)
	if _items.is_empty():
		_expiry_timer.stop()


func _on_item_emptied(item: DroppedItem) -> void:
	# Deferred: the pick-up can arrive in the middle of a physics step, and
	# taking an area out of the tree there removes it from the space mid-step.
	_return_emptied.call_deferred(item, item.uid)


func _return_emptied(item: DroppedItem, emptied_uid: String) -> void:
	# It may have expired between the pick-up and this call, and even be in use
	# again as another drop: the uid tells them apart.
	if _items.has(item) and item.uid == emptied_uid:
		_release(item)


func _on_expiry_timer_timeout() -> void:
	discard_expired_now()
