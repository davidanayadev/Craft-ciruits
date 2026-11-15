extends GutTest
## SeededRng (spec 004, R-004-09): the RNG of a zone depends only on the world
## seed, the zone_id, the stream name and an index, so a world is the same on
## every load (constitution P9).

const WORLD_SEED := 12345
const ZONE := Vector2i(0, 0)
const DRAWS := 16


func _sequence(rng: RandomNumberGenerator) -> Array[int]:
	var values: Array[int] = []
	for i: int in DRAWS:
		values.append(rng.randi())
	return values


func test_r_004_09_same_inputs_same_sequence() -> void:
	var first: Array[int] = _sequence(
		SeededRng.create(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_PLACEMENT)
	)
	var second: Array[int] = _sequence(
		SeededRng.create(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_PLACEMENT)
	)
	assert_eq(first, second, "same world seed, zone and stream give the same sequence")


func test_r_004_09_other_zone_other_sequence() -> void:
	var origin: Array[int] = _sequence(
		SeededRng.create(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_PLACEMENT)
	)
	for zone: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]:
		var other: Array[int] = _sequence(
			SeededRng.create(WORLD_SEED, zone, SeededRng.STREAM_BOX_PLACEMENT)
		)
		assert_ne(other, origin, "zone %s differs from zone (0, 0)" % zone)


func test_r_004_09_swapped_zone_coordinates_differ() -> void:
	var a: int = SeededRng.derive_seed(WORLD_SEED, Vector2i(1, 2), SeededRng.STREAM_BOX_PLACEMENT)
	var b: int = SeededRng.derive_seed(WORLD_SEED, Vector2i(2, 1), SeededRng.STREAM_BOX_PLACEMENT)
	assert_ne(a, b, "(1, 2) and (2, 1) are different zones")


func test_r_004_09_other_world_seed_other_seed() -> void:
	var a: int = SeededRng.derive_seed(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_PLACEMENT)
	var b: int = SeededRng.derive_seed(WORLD_SEED + 1, ZONE, SeededRng.STREAM_BOX_PLACEMENT)
	assert_ne(a, b, "another world seed gives another seed")


func test_r_004_09_other_stream_or_index_other_seed() -> void:
	var placement: int = SeededRng.derive_seed(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_PLACEMENT)
	var loot: int = SeededRng.derive_seed(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_LOOT)
	var loot_next: int = SeededRng.derive_seed(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_LOOT, 1)
	assert_ne(placement, loot, "each stream has its own seed")
	assert_ne(loot, loot_next, "each index has its own seed")


func test_r_004_09_create_uses_derived_seed() -> void:
	var rng: RandomNumberGenerator = SeededRng.create(
		WORLD_SEED, ZONE, SeededRng.STREAM_BOX_LOOT, 3
	)
	var expected: int = SeededRng.derive_seed(WORLD_SEED, ZONE, SeededRng.STREAM_BOX_LOOT, 3)
	var actual: int = rng.seed
	assert_eq(actual, expected, "the RNG is seeded with derive_seed()")


## Pins the derivation. The expected values were computed outside Godot
## (Python hashlib + struct) from the byte layout documented in SeededRng.
## Changing them breaks every saved world: that needs a migration, not a new
## expected value.
func test_r_004_09_known_answer() -> void:
	assert_eq(
		SeededRng.derive_seed(12345, Vector2i(0, 0), &"box_placement"),
		-2840244921402737779,
		"zero zone, default index"
	)
	assert_eq(
		SeededRng.derive_seed(-7, Vector2i(3, -2), &"box_loot", 4),
		5202283440625251761,
		"negative seed and coordinate, non-zero index"
	)
