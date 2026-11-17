extends GutTest
## Zone data (spec 004): the green zone is zone (0, 0) (R-004-02), fits in one
## cell of the global grid (R-004-03) and gets the box count of BALANCE §7.1
## (R-004-21) and its zombies (R-006-23). The expected values mirror BALANCE.md
## §7 and §7.1; update both together.
## Spec 009: every zone has a kind and a scene, and the base is zone (0, -1)
## (R-009-01, architecture §14).
## Spec 010: a local position is inside the zone's playable area (R-010-36).

const GREEN_ZONE_PATH := "res://resources/zones/green_zone.tres"
const BASE_ZONE_PATH := "res://resources/zones/base.tres"
const WORLD_GRID_PATH := "res://resources/config/world_grid.tres"

var _zone: ZoneData
var _grid: WorldGridConfigData


func before_each() -> void:
	_zone = load(GREEN_ZONE_PATH) as ZoneData
	_grid = load(WORLD_GRID_PATH) as WorldGridConfigData


func test_r_004_02_green_zone_id() -> void:
	assert_not_null(_zone, "green_zone.tres exists and is a ZoneData")
	if _zone == null:
		return
	assert_eq(_zone.zone_id, Vector2i(0, 0), "the green zone is zone (0, 0)")


func test_r_004_03_cell_size_matches_balance() -> void:
	assert_not_null(_grid, "world_grid.tres exists and is a WorldGridConfigData")
	if _grid == null:
		return
	assert_eq(_grid.cell_size_m, 80.0, "global map cell (BALANCE §7)")


func test_r_004_03_green_zone_size_fits_in_cell() -> void:
	if _zone == null or _grid == null:
		fail_test("zone or grid resource is missing")
		return
	assert_eq(_zone.size_m, Vector2(50.0, 50.0), "green zone size (BALANCE §7.1)")
	assert_lte(_zone.size_m.x, _grid.cell_size_m, "width fits in one cell")
	assert_lte(_zone.size_m.y, _grid.cell_size_m, "depth fits in one cell")


func test_r_004_21_box_counts_match_balance() -> void:
	if _zone == null:
		fail_test("green_zone.tres is missing")
		return
	assert_eq(_zone.box_count_min, 5, "minimum boxes (BALANCE §7.1)")
	assert_eq(_zone.box_count_max, 7, "maximum boxes (BALANCE §7.1)")


func test_r_006_23_enemy_counts_match_balance() -> void:
	if _zone == null:
		fail_test("green_zone.tres is missing")
		return
	assert_eq(_zone.enemy_count_min, 5, "minimum zombies (BALANCE §7.1)")
	assert_eq(_zone.enemy_count_max, 8, "maximum zombies (BALANCE §7.1)")


func test_r_006_23_enemy_spawns_match_balance() -> void:
	# BALANCE §7.1: first one of each kind, then each of the rest is slow or
	# fast with the same chance.
	if _zone == null:
		fail_test("green_zone.tres is missing")
		return
	var ids: Array[StringName] = []
	for entry: EnemySpawnEntryData in _zone.enemy_spawns:
		if entry == null or entry.enemy == null:
			fail_test("green_zone.tres has a spawn entry without enemy")
			continue
		ids.append(entry.enemy.id)
		assert_eq(entry.min_count, 1, "one %s guaranteed" % entry.enemy.id)
		assert_eq(entry.weight, _zone.enemy_spawns[0].weight, "%s: equal share" % entry.enemy.id)
		assert_gt(entry.weight, 0, "%s takes part in the rest" % entry.enemy.id)
		assert_true(DataRegistry.get_catalog().has_enemy(entry.enemy.id), "catalog enemy")
	var expected: Array[StringName] = [&"zombie_slow", &"zombie_fast"]
	assert_eq(ids, expected, "slow and fast zombies")


func test_r_009_01_zone_kinds_and_scenes() -> void:
	var base: ZoneData = load(BASE_ZONE_PATH) as ZoneData
	if _zone == null or base == null:
		fail_test("green_zone.tres or base.tres is missing")
		return
	assert_eq(_zone.kind, ZoneData.Kind.FARM, "the green zone is a farm zone")
	assert_eq(_zone.scene_path, "res://scenes/farm_zone/farm_zone_green.tscn", "green zone scene")
	assert_true(_zone.counts_visits(), "a farm zone counts visits")
	assert_eq(base.kind, ZoneData.Kind.BASE, "the base is a BASE zone")
	assert_eq(base.scene_path, "res://scenes/base/base.tscn", "base scene")
	assert_false(base.counts_visits(), "the base counts no visits (question 12)")


func test_r_009_01_base_zone_id_from_architecture() -> void:
	var base: ZoneData = load(BASE_ZONE_PATH) as ZoneData
	if base == null or _grid == null:
		fail_test("base.tres or world_grid.tres is missing")
		return
	assert_eq(base.zone_id, Vector2i(0, -1), "the base is zone (0, -1) (architecture §14)")
	assert_eq(base.size_m, Vector2(20.0, 20.0), "base size (BALANCE §5.6)")
	assert_lte(base.size_m.x, _grid.cell_size_m, "width fits in one cell")
	assert_eq(base.box_count_max, 0, "no boxes in the base")
	assert_eq(base.enemy_count_max, 0, "no enemies in the base (safe zone)")
	assert_eq(base.enemy_spawns.size(), 0, "no enemy spawns in the base")


func test_r_010_36_contains_local_position() -> void:
	var zone: ZoneData = ZoneData.new()
	zone.size_m = Vector2(20.0, 10.0)
	assert_true(zone.contains_local_position(Vector3.ZERO), "the centre")
	assert_true(zone.contains_local_position(Vector3(10.0, 0.0, 5.0)), "corner edge included")
	assert_true(zone.contains_local_position(Vector3(-10.0, 0.0, -5.0)), "opposite corner included")
	assert_true(zone.contains_local_position(Vector3(0.0, 999.0, 0.0)), "y is ignored")
	assert_false(zone.contains_local_position(Vector3(10.01, 0.0, 0.0)), "beyond x")
	assert_false(zone.contains_local_position(Vector3(-10.01, 0.0, 0.0)), "beyond -x")
	assert_false(zone.contains_local_position(Vector3(0.0, 0.0, 5.01)), "beyond z (depth uses size_m.y)")
	assert_false(zone.contains_local_position(Vector3(0.0, 0.0, -5.01)), "beyond -z")


func test_r_010_36_contains_local_position_real_zones() -> void:
	var base: ZoneData = load(BASE_ZONE_PATH) as ZoneData
	if _zone == null or base == null:
		fail_test("green_zone.tres or base.tres is missing")
		return
	for zone: ZoneData in [_zone, base]:
		var half_x: float = zone.size_m.x / 2.0
		var half_z: float = zone.size_m.y / 2.0
		assert_true(zone.contains_local_position(Vector3(half_x, 0.0, half_z)), "edge of %s" % zone.scene_path)
		assert_true(zone.contains_local_position(Vector3.ZERO), "centre of %s" % zone.scene_path)
		assert_false(
			zone.contains_local_position(Vector3(half_x + 0.5, 0.0, 0.0)), "outside x of %s" % zone.scene_path
		)
		assert_false(
			zone.contains_local_position(Vector3(0.0, 0.0, -half_z - 0.5)), "outside z of %s" % zone.scene_path
		)


func test_r_009_01_scene_root_matches_kind_and_data() -> void:
	for zone: ZoneData in DataRegistry.get_catalog().zones:
		assert_true(ResourceLoader.exists(zone.scene_path), "%s exists" % zone.scene_path)
		var scene: PackedScene = load(zone.scene_path) as PackedScene
		if scene == null:
			fail_test("%s is not a scene" % zone.scene_path)
			continue
		var root: Node = scene.instantiate()
		var root_zone: Zone = root as Zone
		assert_not_null(root_zone, "%s: the root is a Zone" % zone.scene_path)
		if root_zone != null:
			var is_farm: bool = zone.kind == ZoneData.Kind.FARM
			assert_eq(root_zone is FarmZone, is_farm, "%s: FarmZone for FARM" % zone.scene_path)
			assert_eq(root_zone is BaseZone, not is_farm, "%s: BaseZone for BASE" % zone.scene_path)
			assert_same(root_zone.data, zone, "%s: its data is the same ZoneData" % zone.scene_path)
		root.free()
