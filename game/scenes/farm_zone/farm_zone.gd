class_name FarmZone
extends Zone
## A farm zone (spec 004): ground, decoration, boundaries, a spawn point and
## hand-placed box markers. generate() fills it from the world seed; the zone
## never reads the seed itself, so whoever loads it (ZoneLoader, spec 009)
## decides the world, and tests can generate it with any seed.
## Positions are local to the zone, whose origin is the centre of its grid cell.
## Where the boxes are never changes; what they hold and which enemies there
## are depend on the visit (BALANCE §7.2). Enemies come from a pool that
## outlives the zone (spec 006). repopulate() starts a new visit (spec 008).
## populate() brings back a saved visit: its open boxes and its dead enemies
## (spec 010).

## A box of this zone was interacted with while it held items (spec 005).
## Relayed here so whoever loads the zone connects one signal, not every box.
signal box_opened(box: LootBox, opener: Node3D)
## An enemy of this zone left loot where it died (spec 008).
signal enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3)

@export var box_scene: PackedScene

const _BOXES_KEY := "boxes"
const _MARKER_KEY := "marker"
const _DEAD_ENEMIES_KEY := "dead_enemies"

var _boxes: Array[LootBox] = []
## Marker of each box, in the same order as _boxes.
var _box_marker_indices: Array[int] = []
var _generated: bool = false
var _visit: int = ZonePopulation.FIRST_VISIT

@onready var _box_markers: Node3D = %BoxMarkers
@onready var _boxes_root: Node3D = %Boxes
@onready var _enemy_markers: Node3D = %EnemyMarkers
@onready var _zombie_spawner: ZombieSpawner = %ZombieSpawner


func _ready() -> void:
	super()
	_zombie_spawner.enemy_loot_dropped.connect(_on_enemy_loot_dropped)


## Places the boxes once (second call → push_error, no change). How many and
## on which markers comes from the box_placement stream, without the visit;
## the contents of each box from the box_loot stream, the visit and its marker
## index, so they depend neither on the opening order nor on how many boxes
## there are (R-008-08).
func generate(world_seed: int, visit: int) -> void:
	if _generated:
		push_error("FarmZone '%s': generate() was already called." % name)
		return
	if data == null or box_scene == null:
		push_error("FarmZone '%s': data and box_scene must be assigned." % name)
		return
	_generated = true
	_visit = visit
	var markers: Array[Node] = _box_markers.get_children()
	var rng: RandomNumberGenerator = SeededRng.create(
		world_seed, data.zone_id, SeededRng.STREAM_BOX_PLACEMENT
	)
	var picked: Array[int] = ZonePopulation.pick_box_markers(
		markers.size(), data.box_count_min, data.box_count_max, rng
	)
	for marker_index: int in picked:
		_place_box(markers[marker_index] as Marker3D, marker_index, world_seed, visit)


## Starts a new visit (R-008-09): the enemies are replaced by those of that
## visit and every box by a closed one on the same marker with the contents of
## that visit; what was left inside goes with the old box. Before generate() →
## push_error, no change.
func repopulate(world_seed: int, visit: int, pool: ObjectPool) -> void:
	if not _generated:
		push_error("FarmZone '%s': repopulate() needs generate() first." % name)
		return
	_visit = visit
	despawn_enemies()
	spawn_enemies(world_seed, visit, pool)
	# Replaced, not reset: a new box is cheaper to get right than undoing the
	# roll of an old one, and this runs once per death, behind the transfer screen.
	var markers: Array[Node] = _box_markers.get_children()
	var marker_indices: Array[int] = _box_marker_indices
	for box: LootBox in _boxes:
		box.queue_free()
	_boxes = []
	_box_marker_indices = []
	for marker_index: int in marker_indices:
		_place_box(markers[marker_index] as Marker3D, marker_index, world_seed, visit)


## generate() plus the saved state of that visit (get_visit_state(), spec
## 010): the boxes that were open come back open with what was left, and the
## dead enemies stay dead. Same seed and visit, so the boxes are the same
## (R-010-35). {} is a visit nothing happened in yet.
func populate(world_seed: int, visit: int, pool: ObjectPool, saved_state: Dictionary) -> void:
	generate(world_seed, visit)
	if not _generated:
		return
	_restore_boxes(saved_state.get(_BOXES_KEY, []))
	spawn_enemies(world_seed, visit, pool, _saved_dead_enemies(saved_state))


## The visit given to generate() or repopulate().
func get_visit() -> int:
	return _visit


## {"boxes": [{"marker": int, "contents": {...}}], "dead_enemies": [int]} of
## the visit in progress: the open boxes only, by marker.
func get_visit_state() -> Dictionary:
	var boxes: Array = []
	for i: int in _boxes.size():
		var box_state: Variant = _boxes[i].get_save_state()
		if box_state == null:
			continue
		var entry: Dictionary = box_state
		entry[_MARKER_KEY] = _box_marker_indices[i]
		boxes.append(entry)
	return {_BOXES_KEY: boxes, _DEAD_ENEMIES_KEY: _zombie_spawner.get_dead_indices()}


func get_boxes() -> Array[LootBox]:
	return _boxes


## Places the zombies of the given visit, taken from the pool, but the dead
## ones (spec 010). Calling it again without despawn_enemies() → push_error,
## no change.
func spawn_enemies(
	world_seed: int, visit: int, pool: ObjectPool, dead_indices: Array[int] = []
) -> void:
	if data == null:
		push_error("FarmZone '%s': data must be assigned." % name)
		return
	_zombie_spawner.spawn(
		data, _enemy_markers.get_children(), world_seed, visit, pool, dead_indices
	)


## Returns every zombie to the pool. Whoever unloads the zone calls it first
## (ZoneLoader, spec 009), so the pooled instances are not freed with it.
func despawn_enemies() -> void:
	_zombie_spawner.despawn_all()


func get_enemies() -> Array[Zombie]:
	return _zombie_spawner.get_active()


func _place_box(marker: Marker3D, marker_index: int, world_seed: int, visit: int) -> void:
	if marker == null:
		push_error("FarmZone '%s': box marker %d is not a Marker3D." % [name, marker_index])
		return
	var box: LootBox = box_scene.instantiate() as LootBox
	if box == null:
		push_error("FarmZone '%s': box_scene is not a LootBox." % name)
		return
	_boxes_root.add_child(box)
	box.global_transform = marker.global_transform
	box.setup(
		SeededRng.derive_seed_for_visit(
			world_seed, data.zone_id, SeededRng.STREAM_BOX_LOOT, visit, marker_index
		)
	)
	box.opened.connect(_on_box_opened.bind(box))
	_boxes.append(box)
	_box_marker_indices.append(marker_index)


## Each saved box opened again on its marker; a marker with no box → push_error.
func _restore_boxes(saved: Variant) -> void:
	if not saved is Array:
		push_error("FarmZone '%s': saved boxes %s are lost." % [name, saved])
		return
	for entry: Variant in saved as Array:
		var fields: Dictionary = entry if entry is Dictionary else {}
		var index: int = _box_marker_indices.find(SaveFields.to_int(fields.get(_MARKER_KEY), -1))
		if index == -1:
			push_error("FarmZone '%s': saved box %s has no box on its marker." % [name, entry])
			continue
		_boxes[index].restore_opened(fields)


func _saved_dead_enemies(saved_state: Dictionary) -> Array[int]:
	var dead: Array[int] = []
	var saved: Variant = saved_state.get(_DEAD_ENEMIES_KEY, [])
	if not saved is Array:
		push_error("FarmZone '%s': saved dead enemies %s are lost." % [name, saved])
		return dead
	for index: Variant in saved as Array:
		if SaveFields.is_whole_number(index):
			dead.append(SaveFields.to_int(index, 0))
		else:
			push_error("FarmZone '%s': saved dead enemy %s is lost." % [name, index])
	return dead


func _on_box_opened(opener: Node3D, box: LootBox) -> void:
	box_opened.emit(box, opener)


func _on_enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3) -> void:
	enemy_loot_dropped.emit(stacks, world_position)
