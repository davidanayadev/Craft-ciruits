class_name DroppedItemSpawner
extends Node3D
## Creates the dropped items, expires them and returns them to their pool
## (spec 008). It is the parent of the active ones and lives under World,
## outside the zone: repopulating a zone does not touch them. Unloading one
## keeps their state in JSON types and returns them to the pool; loading it
## again brings them back (spec 009), the same path spec 010 will load from.
## The clock comes from outside (GameManager's in the game, a fake one in
## tests): it never creates one.
## It owns the dropped items in the save (spec 010): every zone's, in the
## format of DroppedItem.to_data(); the expired ones are gone on load.
## A dropped item is a container (spec 015): it re-emits their opened as
## item_opened, announces every item that leaves (item_removed) and releases an
## emptied one only when asked, once its screen closed (release_if_empty).

## Fact: a player interacted with one of its items (R-015-45).
signal item_opened(item: DroppedItem, opener: Node3D)
## Fact: item leaves (expiry, zone unloaded or released empty), before it is
## reset and pooled (plan 015 D13).
signal item_removed(item: DroppedItem)

## The device clock has whole seconds, so checking more often finds nothing new.
const EXPIRY_CHECK_INTERVAL_S := 1.0
## Save contract (spec 010, architecture §10.2).
const SAVE_KEY := &"dropped_items"
## Sanity cap for a slot count read from disk, far above what the game creates:
## not a gameplay value (plan 015 D15).
const MAX_RESTORED_SLOTS := 64
const _ITEMS_KEY := "items"

@export var pool: ObjectPool
@export var config: DroppedItemConfigData

var time_service: ITimeService

var _items: Array[DroppedItem] = []
var _zone_id: Vector2i = Vector2i.ZERO
var _zone_root: Node3D = null
var _expiry_timer: Timer = null
## to_data() of the items of each unloaded zone.
var _stored: Dictionary[Vector2i, Array] = {}


func _ready() -> void:
	_expiry_timer = Timer.new()
	_expiry_timer.wait_time = EXPIRY_CHECK_INTERVAL_S
	_expiry_timer.timeout.connect(_on_expiry_timer_timeout)
	add_child(_expiry_timer)


## The zone that is loaded: what falls from now on belongs to it, at a
## position local to zone_root. The items stored when it was unloaded come
## back, and the expired ones are discarded before anyone can interact
## (R-009-17, R-008-23). ZoneLoader calls it.
func bind_zone(zone_id: Vector2i, zone_root: Node3D) -> void:
	_zone_id = zone_id
	_zone_root = zone_root
	_restore_stored()


## The bound zone is being unloaded: its items keep their state here and go
## back to the pool, so none is freed with the zone (R-009-04).
func unbind_zone() -> void:
	var stored: Array = _stored.get(_zone_id, [])
	stored.append_array(to_data())
	if not stored.is_empty():
		_stored[_zone_id] = stored
	for item: DroppedItem in _items.duplicate():
		_release(item)
	_zone_root = null


## The zone given to bind_zone().
func get_zone_id() -> Vector2i:
	return _zone_id


## Moves every stack of source and the given pieces (the equipment that
## falls, spec 015) into one new dropped item with one slot per stack it
## receives (R-015-47). Nothing to drop → null (R-015-51). The caller removes
## the pieces from where they were only when an item was created (plan 015 D12).
func drop_inventory(
	source: InventoryComponent, world_position: Vector3, pieces: Array[ItemStack] = []
) -> DroppedItem:
	if source == null:
		push_error("DroppedItemSpawner '%s': drop_inventory() got no source." % name)
		return null
	var used: int = InventoryRules.count_used_slots(source.get_slots())
	if used + pieces.size() == 0:
		return null
	var item: DroppedItem = _spawn(world_position, used + pieces.size())
	if item == null:
		return null
	var slot_indices: Array[int] = []
	for index: int in source.get_slot_count():
		slot_indices.append(index)
	if used > 0:
		item.get_contents().take_from(source, slot_indices)
	if not pieces.is_empty() and not item.get_contents().add_stacks(pieces).ok:
		push_error("DroppedItemSpawner '%s': the pieces did not fit in their dropped item." % name)
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


## Releases item once it holds no stacks, if it is still the same use
## (R-015-50). Deferred: the request can come in the middle of a physics step
## or of the screen's own signal. A screen is the only caller, on close.
func release_if_empty(item: DroppedItem) -> void:
	if item == null:
		return
	_release_if_empty.call_deferred(item, item.uid)


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


func get_save_key() -> StringName:
	return SAVE_KEY


## The stored items of every unloaded zone, then the live ones (R-010-29).
func to_save_data() -> Dictionary:
	var items: Array = []
	for stored: Array in _stored.values():
		items.append_array(stored)
	items.append_array(to_data())
	return {_ITEMS_KEY: items}


## Replaces every item, live and stored; the expired ones are dropped with
## the clock's time before anyone can interact (R-010-30). An entry with no
## known zone or no drop time → push_error and skipped; its stacks are checked
## when its zone is bound (R-010-11). Emits nothing.
func from_save_data(data: Dictionary) -> void:
	var items: Variant = data.get(_ITEMS_KEY)
	if not items is Array or config == null or time_service == null:
		push_error("DroppedItemSpawner '%s': cannot load %s (needs config and time_service)." % [name, data])
		return
	for item: DroppedItem in _items.duplicate():
		_release(item)
	_stored.clear()
	var now: int = time_service.now_unix()
	for entry: Variant in items as Array:
		var fields: Dictionary = entry if entry is Dictionary else {}
		var zone_id: Variant = _valid_zone_of(fields)
		if zone_id == null:
			continue
		var dropped_at: int = SaveFields.to_int(fields.get("dropped_at"), 0)
		if DroppedItemRules.is_expired(dropped_at, now, config.lifetime_s):
			continue
		var stored: Array = _stored.get(zone_id, [])
		stored.append(fields)
		_stored[zone_id as Vector2i] = stored
	if _zone_root != null:
		_restore_stored()


## The bound zone's stored items back, then the expired ones out (R-009-17, R-008-23).
func _restore_stored() -> void:
	if not _stored.has(_zone_id):
		return
	var stored: Array = _stored[_zone_id]
	_stored.erase(_zone_id)
	for data: Dictionary in stored:
		_restore(data)
	discard_expired_now()


## Its zone_id when the catalog knows that zone and the entry has the shape of
## DroppedItem.to_data(); else null, reported.
func _valid_zone_of(fields: Dictionary) -> Variant:
	var zone_id: Variant = SaveFields.to_vector2i(fields.get("zone_id"))
	var catalog: DataCatalog = DataRegistry.get_catalog()
	var known: bool = zone_id != null and catalog != null and catalog.has_zone(zone_id as Vector2i)
	var shaped: bool = (
		fields.get("uid") is String and fields.get("stacks") is Array
		and SaveFields.to_vector3(fields.get("position")) != null
		and SaveFields.is_whole_number(fields.get("dropped_at"))
	)
	if not known or not shaped:
		push_error("DroppedItemSpawner '%s': saved dropped item %s is lost." % [name, fields])
		return null
	return zone_id


func _spawn(world_position: Vector3, slot_count: int) -> DroppedItem:
	if _zone_root == null:
		push_error(
			"DroppedItemSpawner '%s': needs a pool, a time service and a bound zone." % name
		)
		return null
	return _spawn_item(
		Uid.generate(), world_position, _zone_root.to_local(world_position), _now_unix(), slot_count
	)


## A stored item back in its zone, with its uid, position, time and stacks. A
## stack of an item the catalog no longer knows is lost, never the others; a
## malformed entry (the data may come from disk) is lost whole, reported.
func _restore(data: Dictionary) -> void:
	var local: Variant = SaveFields.to_vector3(data.get("position"))
	var item_uid: Variant = data.get("uid")
	var dropped_at: Variant = data.get("dropped_at")
	var stack_list: Variant = data.get("stacks")
	if (
		local == null or not item_uid is String or not SaveFields.is_whole_number(dropped_at)
		or not stack_list is Array
	):
		push_error("DroppedItemSpawner '%s': a malformed dropped item was lost: %s." % [name, data])
		return
	var stacks: Array[ItemStack] = _restore_stacks(stack_list as Array)
	if stacks.is_empty() or _zone_root == null:
		return
	var local_position: Vector3 = local
	var item: DroppedItem = _spawn_item(
		item_uid as String,
		_zone_root.to_global(local_position),
		local_position,
		SaveFields.to_int(dropped_at, 0),
		_restored_slot_count(data, stacks.size())
	)
	if item != null and not item.get_contents().add_stacks(stacks).ok:
		push_error("DroppedItemSpawner '%s': a restored item lost stacks." % name)


## The saved slot count when it is a whole number from stack_count to
## MAX_RESTORED_SLOTS; one slot per stack when it is missing (a save from
## before spec 015) or, reported, when it is not valid (R-015-55).
func _restored_slot_count(data: Dictionary, stack_count: int) -> int:
	if not data.has("slot_count"):
		return stack_count
	var saved: Variant = data.get("slot_count")
	var count: int = SaveFields.to_int(saved, -1)
	if count < stack_count or count > MAX_RESTORED_SLOTS:
		push_error(
			"DroppedItemSpawner '%s': saved slot count %s is not valid for %d stacks; one slot per stack."
			% [name, saved, stack_count]
		)
		return stack_count
	return count


## durability and uid are optional, -1 and "" by default: a file saved before
## spec 011 has no pieces, so its stacks load as they did (plan 011 D12).
func _restore_stacks(stack_list: Array) -> Array[ItemStack]:
	var stacks: Array[ItemStack] = []
	for entry: Variant in stack_list:
		var stack_data: Dictionary = entry if entry is Dictionary else {}
		var stack: ItemStack = _stack_from_data(stack_data)
		if stack == null:
			push_error(
				"DroppedItemSpawner '%s': stack %s lost on restore (unknown item, bad quantity or invalid piece)."
				% [name, stack_data]
			)
			continue
		stacks.append(stack)
	return stacks


## Null when the item is unknown, a field is malformed or the piece is not
## valid (InventoryRules.is_valid_stack, R-011-11).
func _stack_from_data(stack_data: Dictionary) -> ItemStack:
	var catalog: DataCatalog = DataRegistry.get_catalog()
	var item_id: StringName = StringName(str(stack_data.get("item_id", "")))
	var quantity: int = SaveFields.to_int(stack_data.get("quantity"), 0)
	var durability: Variant = stack_data.get("durability", -1)
	var stack_uid: Variant = stack_data.get("uid", "")
	if (
		catalog == null or not catalog.has_item(item_id) or quantity <= 0
		or not SaveFields.is_whole_number(durability) or not stack_uid is String
	):
		return null
	var stack: ItemStack = ItemStack.new(catalog.get_item(item_id), quantity)
	stack.durability = SaveFields.to_int(durability, -1)
	stack.uid = stack_uid
	return stack if InventoryRules.is_valid_stack(stack) else null


func _now_unix() -> int:
	return time_service.now_unix() if time_service != null else 0


## world_position and local_position are the same point; both are passed so
## neither is rounded through the other.
func _spawn_item(
	item_uid: String,
	world_position: Vector3,
	local_position: Vector3,
	dropped_at_unix: int,
	slot_count: int
) -> DroppedItem:
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
	item.setup(item_uid, _zone_id, local_position, dropped_at_unix, slot_count)
	item.opened.connect(_on_item_opened)
	_items.append(item)
	if _expiry_timer.is_stopped():
		_expiry_timer.start()
	return item


func _release(item: DroppedItem) -> void:
	_items.erase(item)
	item.opened.disconnect(_on_item_opened)
	item_removed.emit(item)
	item.reset()
	pool.release(item)
	if _items.is_empty():
		_expiry_timer.stop()


func _on_item_opened(item: DroppedItem, opener: Node3D) -> void:
	item_opened.emit(item, opener)


func _release_if_empty(item: DroppedItem, item_uid: String) -> void:
	# It may have expired before this call, and even be in use again as another
	# drop: the uid tells them apart.
	if _items.has(item) and item.uid == item_uid and item.get_contents().is_empty():
		_release(item)


func _on_expiry_timer_timeout() -> void:
	discard_expired_now()
