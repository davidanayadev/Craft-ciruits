extends RefCounted
## Test support (spec 016, T-016-10): finds, in the visits of a farm zone, a
## hostile robot whose seeded drop includes a piece, and computes that drop
## from the data and the drop seed (never copied numbers). Without class_name:
## preload it.

const MAX_VISITS := 200


## A robot of one visit and what its drop table rolls for it.
class Found:
	extends RefCounted
	var robot: Enemy
	var visit: int
	var spawn_index: int
	## The roll of LootSystem.roll_enemy_drop with the robot's drop seed.
	var stacks: Array[ItemStack] = []

	## The piece of the drop; null when it holds none.
	func piece() -> ItemStack:
		for stack: ItemStack in stacks:
			if stack.item is PieceData:
				return stack
		return null


## The drop seed of robot spawn_index of visit, as the spawner derives it.
static func drop_seed(zone: FarmZone, world_seed: int, visit: int, spawn_index: int) -> int:
	return SeededRng.derive_seed_for_visit(
		world_seed, zone.data.zone_id, SeededRng.STREAM_HOSTILE_ROBOT_DROP, visit, spawn_index
	)


static func roll(
	data: EnemyData, zone: FarmZone, world_seed: int, visit: int, spawn_index: int
) -> Array[ItemStack]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = drop_seed(zone, world_seed, visit, spawn_index)
	return LootSystem.roll_enemy_drop(data.drop_table, data.piece_drop, rng)


## Replaces the enemies of zone with the hostile robots of the first visit whose
## drop includes a piece, and returns that robot. null (robots despawned) when
## no visit up to MAX_VISITS has one.
static func place_robot_with_piece(
	zone: FarmZone, pool: ObjectPool, world_seed: int
) -> Found:
	zone.despawn_enemies()
	for visit: int in MAX_VISITS:
		zone.spawn_hostile_robots(world_seed, visit, pool)
		var robots: Array[Enemy] = zone.get_hostile_robots()
		for index: int in robots.size():
			var stacks: Array[ItemStack] = roll(robots[index].get_data(), zone, world_seed, visit, index)
			var found: Found = Found.new()
			found.robot = robots[index]
			found.visit = visit
			found.spawn_index = index
			found.stacks = stacks
			if found.piece() != null:
				return found
		zone.despawn_enemies()
	return null
