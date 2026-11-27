class_name SeededRng
extends RefCounted
## Seeded randomness for world generation (spec 004, constitution P9).
## Every RNG comes from the world seed and a zone_id, so a world is the same on
## every load. Streams keep unrelated uses apart: adding a new use of
## randomness to a zone does not move what an older stream already placed.
##
## The derivation is a contract with saved worlds: test_seeded_rng.gd pins it
## with known answers. Changing it needs a save migration.

const STREAM_BOX_PLACEMENT := &"box_placement"
const STREAM_BOX_LOOT := &"box_loot"
const STREAM_ENEMY_SPAWN := &"enemy_spawn"
const STREAM_ENEMY_BRAIN := &"enemy_brain"
const STREAM_ENEMY_DROP := &"enemy_drop"
## The hostile robots of a visit (spec 016), apart from the zombies so they never
## move what the zombie streams already placed or dropped.
const STREAM_HOSTILE_ROBOT_SPAWN := &"hostile_robot_spawn"
const STREAM_HOSTILE_ROBOT_BRAIN := &"hostile_robot_brain"
const STREAM_HOSTILE_ROBOT_DROP := &"hostile_robot_drop"

const _HEADER_SIZE := 20
const _ZONE_X_OFFSET := 8
const _ZONE_Y_OFFSET := 12
const _INDEX_OFFSET := 16


## SHA-256 over: world_seed (s64 LE) ‖ zone_id.x (s32 LE) ‖ zone_id.y (s32 LE)
## ‖ index (s32 LE) ‖ stream (UTF-8). The seed is the first 8 bytes of the
## digest as s64 LE. Standard hash and fixed byte layout, so a non-Godot
## server can reproduce it.
static func derive_seed(
	world_seed: int, zone_id: Vector2i, stream: StringName, index: int = 0
) -> int:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_HEADER_SIZE)
	bytes.encode_s64(0, world_seed)
	bytes.encode_s32(_ZONE_X_OFFSET, zone_id.x)
	bytes.encode_s32(_ZONE_Y_OFFSET, zone_id.y)
	bytes.encode_s32(_INDEX_OFFSET, index)
	bytes.append_array(String(stream).to_utf8_buffer())
	var context: HashingContext = HashingContext.new()
	var error: Error = context.start(HashingContext.HASH_SHA256)
	if error == OK:
		error = context.update(bytes)
	if error != OK:
		push_error("SeededRng: SHA-256 failed (%s)." % error_string(error))
		return 0
	return context.finish().decode_s64(0)


## Seed of one element of one visit (spec 008): the seed of the visit, then
## the seed of the element from it. Two chained derive_seed(), so derive_seed
## itself and everything it already placed stay as they are.
static func derive_seed_for_visit(
	world_seed: int, zone_id: Vector2i, stream: StringName, visit: int, index: int
) -> int:
	var visit_seed: int = derive_seed(world_seed, zone_id, stream, visit)
	return derive_seed(visit_seed, zone_id, stream, index)


static func create(
	world_seed: int, zone_id: Vector2i, stream: StringName, index: int = 0
) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = derive_seed(world_seed, zone_id, stream, index)
	return rng
