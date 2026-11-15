class_name FarmZone
extends Node3D
## A farm zone (spec 004): ground, decoration, boundaries, a spawn point and
## hand-placed box markers. generate() fills it from the world seed; the zone
## never reads the seed itself, so whoever loads it (main.gd now, ZoneLoader
## in spec 009) decides the world, and tests can generate it with any seed.
## Positions are local to the zone, whose origin is the centre of its grid cell.

## A box of this zone was interacted with while it held items (spec 005).
## Relayed here so whoever loads the zone connects one signal, not every box.
signal box_opened(box: LootBox, opener: Node3D)

@export var data: ZoneData
@export var box_scene: PackedScene

var _boxes: Array[LootBox] = []
var _generated: bool = false

@onready var _spawn_point: Marker3D = %SpawnPoint
@onready var _box_markers: Node3D = %BoxMarkers
@onready var _boxes_root: Node3D = %Boxes


## Places the boxes once (second call → push_error, no change). How many and
## on which markers comes from the box_placement stream; the contents of each
## box from the box_loot stream and its marker index, so they depend neither
## on the opening order nor on how many boxes there are.
func generate(world_seed: int) -> void:
	if _generated:
		push_error("FarmZone '%s': generate() was already called." % name)
		return
	if data == null or box_scene == null:
		push_error("FarmZone '%s': data and box_scene must be assigned." % name)
		return
	_generated = true
	var markers: Array[Node] = _box_markers.get_children()
	var rng: RandomNumberGenerator = SeededRng.create(
		world_seed, data.zone_id, SeededRng.STREAM_BOX_PLACEMENT
	)
	var picked: Array[int] = ZonePopulation.pick_box_markers(
		markers.size(), data.box_count_min, data.box_count_max, rng
	)
	for marker_index: int in picked:
		_place_box(markers[marker_index] as Marker3D, marker_index, world_seed)


func get_spawn_position() -> Vector3:
	return _spawn_point.global_position


func get_boxes() -> Array[LootBox]:
	return _boxes


func _place_box(marker: Marker3D, marker_index: int, world_seed: int) -> void:
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
		SeededRng.derive_seed(world_seed, data.zone_id, SeededRng.STREAM_BOX_LOOT, marker_index)
	)
	box.opened.connect(_on_box_opened.bind(box))
	_boxes.append(box)


func _on_box_opened(opener: Node3D, box: LootBox) -> void:
	box_opened.emit(box, opener)
