extends GutTest
## Hostile robot scene (spec 016) with real physics: it is configured only by its
## own EnemyData and AI (R-016-06), detects by ground distance (R-016-06), walks
## to the player at the speed of its data (R-016-07), hits once per full interval
## in range, wearing the equipped piece and draining the battery (R-016-08),
## ignores a depleted robot (R-016-09), has the structure, budget, collider and
## animations of the scene (R-016-10), hurts and flashes like a zombie
## (R-016-11), announces a kill once with its killer (R-016-12), a death nobody
## dealt gives no kill and no drop (R-016-13), rolls its drop once per life
## (R-016-14) and leaves materials and piece in one signal (R-016-18).
## Values come from the real .tres files (BALANCE single source).

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const HOSTILE_SCENE := preload("res://scenes/entities/hostile_robot.tscn")
const ZONE_SCENE := preload("res://scenes/farm_zone/farm_zone_green.tscn")
const ENEMY_TESTS := preload("res://tests/integration/test_enemy.gd")
const HOSTILE_PATH := "res://resources/enemies/hostile_robot_basic.tres"
const NAVMESH_PATH := "res://resources/zones/green_zone_navmesh.tres"
const BRAIN_SEED := 7
const DROP_SEED := 4321
const HOME := Vector3(40.0, 0.0, 40.0)
## Frames for the robot to see the player and reach ATTACK: one transition per frame.
const SETTLE_FRAMES := 5
## Passive battery drain of the player while a test waits (BALANCE §1.1), with slack.
const DRAIN_SLACK := 0.5
const NAV_SYNC_MAX_FRAMES := 30
const DROP_SEED_SEARCH := 3000
const ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"attack"]
const MODEL_MESHES: Array[StringName] = [
	&"TrackLeft", &"TrackRight", &"Body", &"Head", &"Visor", &"ArmLeft", &"ArmRight",
]
## A height that puts the player out of vision in 3D but not on the ground.
const HIGH := 5.0
const FAR_AWAY := 100.0
const UID_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const UID_B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

var _data: EnemyData


func before_each() -> void:
	_data = load(HOSTILE_PATH) as EnemyData


func _new_hostile() -> Enemy:
	var hostile: Enemy = HOSTILE_SCENE.instantiate() as Enemy
	add_child_autofree(hostile)
	return hostile


func _active_hostile(home: Vector3 = HOME, drop_seed: int = DROP_SEED) -> Enemy:
	var hostile: Enemy = _new_hostile()
	hostile.activate(_data, home, BRAIN_SEED, drop_seed)
	return hostile


func _new_robot(at: Vector3) -> Robot:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.global_position = at
	return robot


func _in_range_offset() -> Vector3:
	return Vector3(_data.ai.attack_range * 0.9, 0.0, 0.0)


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _count_triangles(node: Node) -> int:
	var triangles: int = 0
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		triangles += mesh_instance.mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		triangles += _count_triangles(child)
	return triangles


func _wait_for_navigation(zone: Node3D) -> bool:
	var map: RID = zone.get_world_3d().navigation_map
	for i: int in NAV_SYNC_MAX_FRAMES:
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			map, Vector3(-20.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), true
		)
		if path.size() >= 2:
			return true
	return false


func _rolled(drop_seed: int) -> Array[ItemStack]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = drop_seed
	return LootSystem.roll_enemy_drop(_data.drop_table, _data.piece_drop, rng)


## First seed whose roll gives a piece (or no piece), or -1.
func _find_drop_seed(with_piece: bool) -> int:
	for drop_seed: int in DROP_SEED_SEARCH:
		var stacks: Array[ItemStack] = _rolled(drop_seed)
		var has_piece: bool = not stacks.is_empty() and stacks[-1].item is PieceData
		if has_piece == with_piece:
			return drop_seed
	return -1


func test_r_016_06_activate_uses_its_own_ai() -> void:
	var hostile: Enemy = _active_hostile()
	assert_same(hostile.get_data(), _data, "keeps the hostile robot's EnemyData")
	assert_not_null(_data.ai, "its data has an AI")
	var own_ai: EnemyAiData = load("res://resources/ai/hostile_robot_ai.tres") as EnemyAiData
	assert_eq(_data.ai.resource_path, own_ai.resource_path, "its own AI resource")
	assert_eq(hostile.get_health().get_maximum(), _data.hp_max, "max HP from data")
	assert_eq(hostile.get_health().get_current(), _data.hp_max, "full HP")
	assert_eq(hostile.get_state(), EnemyBrain.State.IDLE, "starts idle")
	assert_eq(hostile.global_position, HOME, "placed at its home")
	assert_true(hostile.is_physics_processing(), "acts once activated")


func test_r_016_06_detects_by_ground_distance() -> void:
	var vision: float = _data.ai.vision_radius
	var hostile: Enemy = _active_hostile()
	var robot: Robot = _new_robot(HOME + Vector3(vision - 0.5, HIGH, 0.0))
	# No floor under it: it stays at its height, so only the ground distance counts.
	robot.set_physics_process(false)
	var straight: float = (robot.global_position - hostile.global_position).length()
	assert_gt(straight, vision, "beyond the radius in 3D")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(hostile.get_state(), EnemyBrain.State.CHASE, "inside the radius on the ground: chased")


func test_r_016_06_ignores_player_outside_ground_radius() -> void:
	var vision: float = _data.ai.vision_radius
	var hostile: Enemy = _active_hostile()
	var robot: Robot = _new_robot(HOME + Vector3(vision + 0.5, 0.0, 0.0))
	robot.set_physics_process(false)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_ne(hostile.get_state(), EnemyBrain.State.CHASE, "outside the radius on the ground: not chased")
	assert_ne(hostile.get_state(), EnemyBrain.State.ATTACK, "and not attacked")


func test_r_016_07_moves_toward_player_at_data_speed() -> void:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(zone)
	var synced: bool = await _wait_for_navigation(zone)
	assert_true(synced, "the navigation map synchronised")
	if not synced:
		return
	var start: Vector3 = Vector3(-6.0, 0.0, 22.0)
	var robot: Robot = _new_robot(start + Vector3(_data.ai.vision_radius - 1.0, 0.0, 0.0))
	var hostile: Enemy = _active_hostile(start)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(hostile.get_state(), EnemyBrain.State.CHASE, "a player in vision is chased")
	var from: Vector3 = hostile.global_position
	var gap_before: float = _flat_distance(from, robot.global_position)
	var seconds: float = 1.0
	await wait_physics_frames(_frames_for(seconds))
	var walked: float = _flat_distance(hostile.global_position, from)
	var gap_after: float = _flat_distance(hostile.global_position, robot.global_position)
	assert_almost_eq(walked, _data.move_speed * seconds, 0.4, "walks at the speed of its data")
	assert_almost_eq(gap_before - gap_after, walked, 0.1, "straight toward the player")
	assert_almost_eq(hostile.velocity.length(), _data.move_speed, 0.01, "velocity from data")


func test_r_016_08_hits_after_full_interval() -> void:
	var hostile: Enemy = _active_hostile()
	var robot: Robot = _new_robot(HOME + _in_range_offset())
	watch_signals(robot)
	var start: float = robot.battery.get_current()
	await wait_physics_frames(_frames_for(_data.attack_interval * 0.5))
	assert_signal_not_emitted(robot, "hit_received", "no hit before a full interval in range")
	await wait_physics_frames(_frames_for(_data.attack_interval * 0.5) + SETTLE_FRAMES * 2)
	assert_signal_emit_count(robot, "hit_received", 1, "one hit after one interval")
	assert_signal_emitted_with_parameters(robot, "hit_received", [_data.hit_damage, hostile])
	var lost: float = start - robot.battery.get_current()
	assert_between(lost, _data.hit_damage, _data.hit_damage + DRAIN_SLACK, "battery lost per hit")


func test_r_016_08_hit_wears_equipped_piece() -> void:
	var hostile: Enemy = _active_hostile()
	var robot: Robot = _new_robot(HOME + _in_range_offset())
	var legs: ItemStack = robot.equipment.get_piece(PieceData.SlotType.LEGS)
	assert_not_null(legs, "a new robot has its basic legs equipped")
	if legs == null:
		return
	var wear: float = robot.stats.get_stat(StatIds.DURABILITY_PER_HIT)
	var expected: int = DegradationSystem.durability_after_hit(legs.durability, wear)
	watch_signals(robot)
	await wait_physics_frames(_frames_for(_data.attack_interval) + SETTLE_FRAMES * 2)
	assert_signal_emit_count(robot, "hit_received", 1, "one hit")
	var worn: ItemStack = robot.equipment.get_piece(PieceData.SlotType.LEGS)
	assert_not_null(worn, "the legs did not break")
	if worn != null:
		assert_eq(worn.durability, expected, "the hit wore the first intact piece by the degradation rule")
	assert_not_null(hostile, "kept alive for the whole test")


func test_r_016_08_leaving_range_restarts_wait() -> void:
	var hostile: Enemy = _active_hostile()
	var robot: Robot = _new_robot(HOME + _in_range_offset())
	watch_signals(robot)
	await wait_physics_frames(_frames_for(_data.attack_interval * 0.75))
	assert_signal_not_emitted(robot, "hit_received", "no hit yet")
	robot.global_position = HOME + Vector3(FAR_AWAY, 0.0, 0.0)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_ne(hostile.get_state(), EnemyBrain.State.ATTACK, "it stopped attacking")
	robot.global_position = hostile.global_position + _in_range_offset()
	await wait_physics_frames(_frames_for(_data.attack_interval * 0.5) + SETTLE_FRAMES)
	assert_signal_not_emitted(robot, "hit_received", "the wait started over: no hit before a full interval")
	await wait_physics_frames(_frames_for(_data.attack_interval * 0.5) + SETTLE_FRAMES)
	assert_signal_emit_count(robot, "hit_received", 1, "one hit a full interval after coming back")


func test_r_016_09_ignores_depleted_robot() -> void:
	var hostile: Enemy = _active_hostile()
	var robot: Robot = _new_robot(HOME + _in_range_offset())
	robot.battery.consume(robot.battery.get_current())
	watch_signals(robot)
	await wait_physics_frames(_frames_for(_data.attack_interval) + SETTLE_FRAMES * 2)
	assert_eq(hostile.get_state(), EnemyBrain.State.IDLE, "a depleted robot is not a target")
	assert_signal_not_emitted(robot, "hit_received", "and is not hit")


func test_r_016_10_scene_structure() -> void:
	var hostile: Enemy = _new_hostile()
	assert_true(hostile is CharacterBody3D, "a CharacterBody3D")
	var shape: CollisionShape3D = hostile.get_node("CollisionShape3D") as CollisionShape3D
	assert_not_null(shape, "it has a collision shape")
	if shape != null:
		assert_true(shape.shape is CapsuleShape3D, "a capsule")
	var model: Node3D = hostile.get_node("Model") as Node3D
	assert_not_null(model, "it has a Model")
	if model != null:
		for mesh_name: StringName in MODEL_MESHES:
			assert_not_null(model.get_node_or_null(NodePath(mesh_name)) as MeshInstance3D, "mesh %s" % mesh_name)
	assert_not_null(hostile.get_node("%Health") as HealthComponent, "%Health")
	assert_not_null(hostile.get_node("%Hurtbox") as HurtboxComponent, "%Hurtbox")
	assert_not_null(hostile.get_node("%HitFlash") as HitFlashComponent, "%HitFlash")
	var agent: NavigationAgent3D = hostile.get_node("%NavAgent") as NavigationAgent3D
	assert_not_null(agent, "%NavAgent")
	if agent != null:
		assert_false(agent.avoidance_enabled, "avoidance stays off")
	var player: AnimationPlayer = hostile.get_node("%AnimationPlayer") as AnimationPlayer
	assert_not_null(player, "it has an AnimationPlayer")
	if player == null:
		return
	for animation: StringName in ANIMATIONS:
		assert_true(player.has_animation(animation), "animation '%s'" % animation)


func test_r_016_10_model_within_triangle_budget() -> void:
	var budget: int = ENEMY_TESTS.MAX_TRIANGLES
	var hostile: Enemy = _new_hostile()
	var triangles: int = _count_triangles(hostile)
	assert_gt(triangles, 0, "a visible model")
	assert_lte(triangles, budget, "within the zombie budget (%d triangles)" % triangles)


func test_r_016_10_collider_fits_navmesh_agent() -> void:
	var navmesh: NavigationMesh = load(NAVMESH_PATH) as NavigationMesh
	var hostile: Enemy = _new_hostile()
	var shape: CollisionShape3D = hostile.get_node("CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = shape.shape as CapsuleShape3D
	assert_not_null(capsule, "a capsule")
	if capsule == null:
		return
	assert_lte(capsule.radius, navmesh.agent_radius, "radius fits the navmesh agent")
	assert_lte(capsule.height, navmesh.agent_height, "height fits the navmesh agent")


func test_r_016_10_animation_follows_state() -> void:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(zone)
	var synced: bool = await _wait_for_navigation(zone)
	assert_true(synced, "the navigation map synchronised")
	if not synced:
		return
	var start: Vector3 = Vector3(-6.0, 0.0, 22.0)
	var hostile: Enemy = _active_hostile(start)
	var player: AnimationPlayer = hostile.get_node("%AnimationPlayer") as AnimationPlayer
	assert_eq(player.current_animation, "idle", "idle when idle")
	var robot: Robot = _new_robot(start + Vector3(_data.ai.vision_radius - 1.0, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(hostile.get_state(), EnemyBrain.State.CHASE, "chasing")
	assert_eq(player.current_animation, "walk", "walk when chasing")
	robot.global_position = hostile.global_position + _in_range_offset()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(hostile.get_state(), EnemyBrain.State.ATTACK, "attacking")
	assert_eq(player.current_animation, "attack", "attack when attacking")


func test_r_016_10_every_mesh_flashes() -> void:
	var hostile: Enemy = _new_hostile()
	var flash: HitFlashComponent = hostile.get_node("%HitFlash") as HitFlashComponent
	var model: Node = hostile.get_node("Model")
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), MODEL_MESHES.size(), "the model has its meshes")
	assert_eq(flash.meshes.size(), meshes.size(), "as many flash meshes as model meshes")
	for mesh: Node in meshes:
		var instance: MeshInstance3D = mesh as MeshInstance3D
		assert_true(flash.meshes.has(instance), "%s flashes" % instance.name)


func test_r_016_11_hit_lowers_health_and_flashes() -> void:
	var hostile: Enemy = _active_hostile()
	var flash: HitFlashComponent = hostile.get_node("%HitFlash") as HitFlashComponent
	var body: MeshInstance3D = hostile.get_node("Model/Body") as MeshInstance3D
	assert_false(flash.is_flashing(), "no flash before a hit")
	hostile.get_hurtbox().receive_attack(1, UID_A)
	assert_eq(hostile.get_health().get_current(), _data.hp_max - 1, "the hit lowers its health")
	assert_true(flash.is_flashing(), "and makes it flash")
	assert_same(body.material_overlay, flash.material, "white over its meshes")
	flash.advance(flash.feedback.enemy_flash_s)
	assert_false(flash.is_flashing(), "for the flash time of the feedback data")
	assert_null(body.material_overlay, "then it looks as before")


func test_r_016_12_enemy_killed_once_with_killer() -> void:
	var hostile: Enemy = _active_hostile()
	var hurtbox: HurtboxComponent = hostile.get_hurtbox()
	watch_signals(EventBus)
	watch_signals(hostile)
	hurtbox.receive_attack(_data.hp_max - 1, UID_A)
	assert_signal_not_emitted(EventBus, "enemy_killed", "a hit that does not kill announces nothing")
	hurtbox.receive_attack(1, UID_B)
	assert_signal_emit_count(EventBus, "enemy_killed", 1, "the kill is announced")
	assert_signal_emitted_with_parameters(EventBus, "enemy_killed", [&"hostile_robot_basic", UID_B])
	assert_signal_emit_count(hostile, "defeated", 1, "and it is defeated")
	hurtbox.receive_attack(1, UID_A)
	assert_signal_emit_count(EventBus, "enemy_killed", 1, "hits on the dead robot announce nothing more")


func test_r_016_13_death_without_attacker_no_xp_no_drop() -> void:
	var hostile: Enemy = _active_hostile(HOME, _find_drop_seed(true))
	watch_signals(EventBus)
	watch_signals(hostile)
	hostile.get_health().take_damage(_data.hp_max)
	assert_signal_emit_count(hostile, "defeated", 1, "it died")
	assert_signal_not_emitted(EventBus, "enemy_killed", "nobody killed it: no XP")
	assert_signal_not_emitted(hostile, "loot_dropped", "and it drops nothing")


func test_r_016_14_kill_rolls_once() -> void:
	var loot_seed: int = _find_drop_seed(true)
	assert_ne(loot_seed, -1, "a seed rolls a piece")
	if loot_seed == -1:
		return
	var expected: Array[ItemStack] = _rolled(loot_seed)
	var hostile: Enemy = _active_hostile(HOME, loot_seed)
	watch_signals(hostile)
	hostile.get_hurtbox().receive_attack(_data.hp_max, UID_A)
	hostile.get_hurtbox().receive_attack(1, UID_B)
	hostile.get_hurtbox().receive_attack(1, UID_B)
	assert_signal_emit_count(hostile, "loot_dropped", 1, "one roll per life")
	var parameters: Array = get_signal_parameters(hostile, "loot_dropped")
	var stacks: Array[ItemStack] = parameters[0]
	assert_eq(stacks.size(), expected.size(), "the stacks of the seeded roll")
	for i: int in mini(stacks.size(), expected.size()):
		assert_eq(stacks[i].item.id, expected[i].item.id, "same item")
		assert_eq(stacks[i].quantity, expected[i].quantity, "same quantity")
		assert_eq(stacks[i].durability, expected[i].durability, "same durability")


func test_r_016_18_drop_is_one_signal_with_all_stacks() -> void:
	var loot_seed: int = _find_drop_seed(true)
	assert_ne(loot_seed, -1, "a seed rolls a piece")
	if loot_seed == -1:
		return
	var at: Vector3 = HOME + Vector3(3.0, 0.0, -2.0)
	var hostile: Enemy = _active_hostile(at, loot_seed)
	watch_signals(hostile)
	hostile.get_hurtbox().receive_attack(_data.hp_max, UID_A)
	assert_signal_emit_count(hostile, "loot_dropped", 1, "one signal with everything")
	var parameters: Array = get_signal_parameters(hostile, "loot_dropped")
	var stacks: Array[ItemStack] = parameters[0]
	var position: Vector3 = parameters[1]
	assert_gt(stacks.size(), 1, "materials and a piece")
	if stacks.is_empty():
		return
	assert_true(stacks[-1].item is PieceData, "the piece goes last")
	for i: int in stacks.size() - 1:
		assert_false(stacks[i].item is PieceData, "the others are materials")
	assert_eq(position, hostile.global_position, "where the robot died")


func test_r_016_06_reused_robot_is_reset() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = HOSTILE_SCENE
	add_child_autofree(pool)
	var holder: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var hostile: Enemy = pool.acquire() as Enemy
	holder.add_child(hostile)
	hostile.activate(_data, HOME, BRAIN_SEED, DROP_SEED)
	hostile.get_hurtbox().receive_attack(_data.hp_max, UID_A)
	assert_true(hostile.get_health().is_dead(), "first life: killed")
	pool.release(hostile)
	var reused: Enemy = pool.acquire() as Enemy
	assert_same(reused, hostile, "the pool gives the same instance back")
	holder.add_child(reused)
	reused.activate(_data, HOME, BRAIN_SEED + 1, DROP_SEED)
	var flash: HitFlashComponent = reused.get_node("%HitFlash") as HitFlashComponent
	var body: MeshInstance3D = reused.get_node("Model/Body") as MeshInstance3D
	assert_eq(reused.get_health().get_current(), _data.hp_max, "full HP")
	assert_false(flash.is_flashing(), "no flash")
	assert_null(body.material_overlay, "no flash material left on its meshes")
	assert_eq(reused.get_hurtbox().get_last_attacker_uid(), "", "no record of who hit it")
	assert_eq(reused.get_state(), EnemyBrain.State.IDLE, "back in IDLE")
	assert_true(reused.get_hurtbox().is_alive(), "it can be hit again")
	watch_signals(EventBus)
	reused.get_health().take_damage(_data.hp_max)
	assert_signal_not_emitted(EventBus, "enemy_killed", "the kill of its first life is not repeated")
