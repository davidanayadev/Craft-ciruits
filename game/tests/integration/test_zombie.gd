extends GutTest
## Zombie scene (spec 006) with real physics: its structure and that it is
## configured only by an EnemyData (R-006-10), it walks to the player along the
## navmesh at the speed of its data (R-006-13), stops, faces the player and
## hits once per interval (R-006-15), each hit drains the robot's battery
## (R-006-16), a depleted robot is neither targeted nor hit (R-006-18), a dead
## zombie stops acting and announces it (R-006-21) and a reused instance
## starts from scratch with its new data (R-006-22).
## Values come from the real .tres files (BALANCE §3.1 single source).

const ZOMBIE_SCENE := preload("res://scenes/entities/zombie.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const ZONE_SCENE := preload("res://scenes/farm_zone/farm_zone_green.tscn")
const SLOW_PATH := "res://resources/enemies/zombie_slow.tres"
const FAST_PATH := "res://resources/enemies/zombie_fast.tres"
const BRAIN_SEED := 7
const HOME := Vector3(40.0, 0.0, 40.0)
## Technical budget of plan 006 §5 (R-006-28): 8 zombies fit in PMV §3.2.
const MAX_TRIANGLES := 2000
## Frames for the zombie to see the robot and reach ATTACK: one transition per frame.
const SETTLE_FRAMES := 5
## Passive battery drain of the robot while a test waits (BALANCE §1.1), with slack.
const DRAIN_SLACK := 0.5
## Physics frames the navigation map may take to synchronise (plan 006 §5.1).
const NAV_SYNC_MAX_FRAMES := 30
const ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"attack"]
const UID_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const UID_B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

var _slow: EnemyData
var _fast: EnemyData


func before_each() -> void:
	_slow = load(SLOW_PATH) as EnemyData
	_fast = load(FAST_PATH) as EnemyData


func _new_zombie() -> Zombie:
	var zombie: Zombie = ZOMBIE_SCENE.instantiate() as Zombie
	add_child_autofree(zombie)
	return zombie


func _active_zombie(data: EnemyData, home: Vector3 = HOME) -> Zombie:
	var zombie: Zombie = _new_zombie()
	zombie.activate(data, home, BRAIN_SEED)
	return zombie


func _new_robot(at: Vector3) -> Robot:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.global_position = at
	return robot


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


## Waits until the navigation map of the scene has synchronised its regions.
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


func test_r_006_10_scene_structure() -> void:
	var zombie: Zombie = _new_zombie()
	assert_true(zombie is CharacterBody3D, "the zombie is a CharacterBody3D")
	var shape: CollisionShape3D = zombie.get_node("CollisionShape3D") as CollisionShape3D
	assert_not_null(shape, "it has a collision shape")
	if shape != null:
		assert_not_null(shape.shape, "with a shape assigned")
	assert_not_null(zombie.get_node("%Health") as HealthComponent, "%Health is a HealthComponent")
	var agent: NavigationAgent3D = zombie.get_node("%NavAgent") as NavigationAgent3D
	assert_not_null(agent, "%NavAgent is a NavigationAgent3D")
	if agent != null:
		assert_false(agent.avoidance_enabled, "avoidance stays off (spec 006, question 8)")
	var player: AnimationPlayer = zombie.get_node("%AnimationPlayer") as AnimationPlayer
	assert_not_null(player, "it has an AnimationPlayer")
	if player == null:
		return
	for animation: StringName in ANIMATIONS:
		assert_true(player.has_animation(animation), "animation '%s'" % animation)


func test_r_006_10_model_within_triangle_budget() -> void:
	var zombie: Zombie = _new_zombie()
	var triangles: int = _count_triangles(zombie)
	assert_gt(triangles, 0, "the zombie has a visible model")
	assert_lte(triangles, MAX_TRIANGLES, "low-poly model (%d triangles)" % triangles)


func test_r_006_10_activate_reads_enemy_data() -> void:
	for data: EnemyData in [_slow, _fast]:
		var zombie: Zombie = _active_zombie(data)
		assert_same(zombie.get_data(), data, "%s: keeps its EnemyData" % data.id)
		assert_eq(zombie.get_health().get_maximum(), data.hp_max, "%s: max HP from data" % data.id)
		assert_eq(zombie.get_health().get_current(), data.hp_max, "%s: starts at full HP" % data.id)
		assert_eq(zombie.get_state(), EnemyBrain.State.IDLE, "%s: starts idle" % data.id)
		assert_eq(zombie.global_position, HOME, "%s: placed at its home" % data.id)
		assert_true(zombie.is_physics_processing(), "%s: acts once activated" % data.id)


func test_r_006_10_inactive_until_activated() -> void:
	var zombie: Zombie = _new_zombie()
	assert_false(zombie.is_physics_processing(), "a zombie without data does not act")
	assert_null(zombie.get_data(), "it has no data yet")
	assert_eq(zombie.get_state(), EnemyBrain.State.IDLE, "and reports IDLE")


func test_r_006_10_activate_without_data_reports_error() -> void:
	var zombie: Zombie = _new_zombie()
	zombie.name = "Broken"
	zombie.activate(null, HOME, BRAIN_SEED)
	assert_push_error("Broken")
	assert_false(zombie.is_physics_processing(), "it stays inactive")


func test_r_006_13_moves_toward_player_at_data_speed() -> void:
	var zone: FarmZone = ZONE_SCENE.instantiate() as FarmZone
	add_child_autofree(zone)
	var synced: bool = await _wait_for_navigation(zone)
	assert_true(synced, "the navigation map synchronised")
	if not synced:
		return
	# Open ground of the green zone, nothing between the two.
	var start: Vector3 = Vector3(-6.0, 0.0, 22.0)
	var robot: Robot = _new_robot(start + Vector3(_fast.ai.vision_radius - 1.0, 0.0, 0.0))
	# A second life: the speed must be the one of the new data, not of the
	# slow zombie this instance was before (R-006-22).
	var zombie: Zombie = _active_zombie(_slow, start)
	zombie.activate(_fast, start, BRAIN_SEED)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(zombie.get_state(), EnemyBrain.State.CHASE, "a player in vision is chased")
	var from: Vector3 = zombie.global_position
	var gap_before: float = _flat_distance(from, robot.global_position)
	var seconds: float = 1.0
	await wait_physics_frames(_frames_for(seconds))
	var walked: float = _flat_distance(zombie.global_position, from)
	var gap_after: float = _flat_distance(zombie.global_position, robot.global_position)
	assert_almost_eq(walked, _fast.move_speed * seconds, 0.4, "walks at the speed of its data")
	assert_almost_eq(gap_before - gap_after, walked, 0.1, "straight toward the player")
	assert_almost_eq(zombie.velocity.length(), _fast.move_speed, 0.01, "velocity from data")
	assert_eq(zombie.velocity.y, 0.0, "movement is horizontal")


func test_r_006_15_stops_and_faces_player() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	var offset: Vector3 = Vector3(1.0, 0.0, 1.0).normalized() * (_slow.ai.attack_range * 0.9)
	var robot: Robot = _new_robot(HOME + offset)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(zombie.get_state(), EnemyBrain.State.ATTACK, "a player in range is attacked")
	assert_eq(zombie.velocity, Vector3.ZERO, "it stops to attack")
	var before: Vector3 = zombie.global_position
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(zombie.global_position, before, "and stays where it is")
	var forward: Vector3 = -zombie.global_transform.basis.z
	var to_robot: Vector3 = (robot.global_position - zombie.global_position).normalized()
	assert_gt(forward.dot(to_robot), 0.99, "facing the player")
	var player: AnimationPlayer = zombie.get_node("%AnimationPlayer") as AnimationPlayer
	assert_eq(player.current_animation, "attack", "with the attack animation")


func test_r_006_16_hit_drains_robot_battery() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	var robot: Robot = _new_robot(HOME + Vector3(_slow.ai.attack_range * 0.9, 0.0, 0.0))
	watch_signals(robot)
	var start: float = robot.battery.get_current()
	await wait_physics_frames(_frames_for(_slow.attack_interval * 0.5))
	assert_signal_not_emitted(robot, "hit_received", "no hit before a full interval in range")
	await wait_physics_frames(_frames_for(_slow.attack_interval * 0.5) + SETTLE_FRAMES * 2)
	assert_signal_emit_count(robot, "hit_received", 1, "one hit after one interval")
	assert_signal_emitted_with_parameters(robot, "hit_received", [_slow.hit_damage, zombie])
	var lost: float = start - robot.battery.get_current()
	assert_between(lost, _slow.hit_damage, _slow.hit_damage + DRAIN_SLACK, "battery lost per hit")


func test_r_006_18_ignores_depleted_robot() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	var robot: Robot = _new_robot(HOME + Vector3(_slow.ai.attack_range * 0.9, 0.0, 0.0))
	robot.battery.consume(robot.battery.get_current())
	watch_signals(robot)
	await wait_physics_frames(_frames_for(_slow.attack_interval) + SETTLE_FRAMES * 2)
	assert_eq(zombie.get_state(), EnemyBrain.State.IDLE, "a depleted robot is not a target")
	assert_signal_not_emitted(robot, "hit_received", "and is not hit")


func test_r_006_18_stops_attacking_when_battery_runs_out() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	var robot: Robot = _new_robot(HOME + Vector3(_slow.ai.attack_range * 0.9, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(zombie.get_state(), EnemyBrain.State.ATTACK, "attacking a living robot")
	robot.battery.consume(robot.battery.get_current())
	await wait_physics_frames(SETTLE_FRAMES)
	assert_ne(zombie.get_state(), EnemyBrain.State.ATTACK, "it gives up once the battery is out")
	assert_ne(zombie.get_state(), EnemyBrain.State.CHASE, "and does not chase it either")


func test_r_006_21_death_stops_and_announces() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	var robot: Robot = _new_robot(HOME + Vector3(_slow.ai.attack_range * 0.9, 0.0, 0.0))
	await wait_physics_frames(SETTLE_FRAMES)
	watch_signals(zombie)
	watch_signals(robot)
	zombie.get_health().take_damage(_slow.hp_max)
	assert_signal_emitted_with_parameters(zombie, "defeated", [zombie])
	assert_signal_emit_count(zombie, "defeated", 1)
	assert_false(zombie.is_physics_processing(), "a dead zombie stops acting")
	assert_eq(zombie.velocity, Vector3.ZERO, "and stops moving")
	await wait_physics_frames(_frames_for(_slow.attack_interval) + SETTLE_FRAMES)
	assert_signal_not_emitted(robot, "hit_received", "a dead zombie does not hit")


func test_r_006_22_reused_zombie_is_reset() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = ZOMBIE_SCENE
	add_child_autofree(pool)
	var holder: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var robot: Robot = _new_robot(HOME + Vector3(_slow.ai.attack_range * 0.9, 0.0, 0.0))
	var zombie: Zombie = pool.acquire() as Zombie
	holder.add_child(zombie)
	zombie.activate(_slow, HOME, BRAIN_SEED)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(zombie.get_state(), EnemyBrain.State.ATTACK, "first life: attacking")
	zombie.get_health().take_damage(_slow.hp_max)
	pool.release(zombie)
	robot.global_position = HOME + Vector3(100.0, 0.0, 0.0)
	var other_home: Vector3 = HOME + Vector3(0.0, 0.0, 10.0)
	var reused: Zombie = pool.acquire() as Zombie
	assert_same(reused, zombie, "the pool gives the same instance back")
	holder.add_child(reused)
	reused.activate(_fast, other_home, BRAIN_SEED + 1)
	assert_same(reused.get_data(), _fast, "it takes the new EnemyData")
	assert_false(reused.get_health().is_dead(), "alive again")
	assert_eq(reused.get_health().get_current(), _fast.hp_max, "full HP of the new kind")
	assert_eq(reused.get_state(), EnemyBrain.State.IDLE, "back in IDLE")
	assert_eq(reused.global_position, other_home, "at its new home")
	assert_eq(reused.velocity, Vector3.ZERO, "standing still")
	assert_true(reused.is_physics_processing(), "and acting again")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_eq(reused.get_state(), EnemyBrain.State.IDLE, "with no target left from its first life")


func test_r_007_17_scene_has_hurtbox_and_flash() -> void:
	var zombie: Zombie = _new_zombie()
	var hurtbox: HurtboxComponent = zombie.get_node("%Hurtbox") as HurtboxComponent
	assert_not_null(hurtbox, "%Hurtbox is a HurtboxComponent")
	assert_not_null(zombie.get_node("%HitFlash") as HitFlashComponent, "%HitFlash is a HitFlashComponent")
	if hurtbox == null:
		return
	assert_same(zombie.get_hurtbox(), hurtbox, "get_hurtbox() returns it")
	assert_same(hurtbox.health, zombie.get_health(), "it damages the zombie's own health")
	var body: CollisionShape3D = zombie.get_node("CollisionShape3D") as CollisionShape3D
	var shapes: Array[Node] = hurtbox.find_children("*", "CollisionShape3D", false, false)
	assert_eq(shapes.size(), 1, "the hurtbox has one shape")
	if shapes.size() != 1:
		return
	var hurt_shape: CollisionShape3D = shapes[0] as CollisionShape3D
	assert_same(hurt_shape.shape, body.shape, "the same capsule as its body, shared")
	assert_eq(hurt_shape.position, body.position, "in the same place")


func test_r_007_17_enemy_killed_once_with_last_hitter() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	var hurtbox: HurtboxComponent = zombie.get_hurtbox()
	watch_signals(EventBus)
	watch_signals(zombie)
	hurtbox.receive_attack(_slow.hp_max - 1, UID_A)
	assert_signal_not_emitted(EventBus, "enemy_killed", "a hit that does not kill announces nothing")
	hurtbox.receive_attack(1, UID_B)
	assert_signal_emit_count(EventBus, "enemy_killed", 1, "the kill is announced")
	assert_signal_emitted_with_parameters(EventBus, "enemy_killed", [_slow.id, UID_B])
	assert_signal_emit_count(zombie, "defeated", 1, "and the zombie is defeated as before")
	hurtbox.receive_attack(1, UID_A)
	assert_signal_emit_count(EventBus, "enemy_killed", 1, "hits on the dead zombie announce nothing more")


func test_r_007_17_death_without_attacker_is_not_a_kill() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	watch_signals(EventBus)
	zombie.get_health().take_damage(_slow.hp_max)
	assert_signal_not_emitted(EventBus, "enemy_killed", "nobody killed it")


func test_r_007_24_hurt_flashes() -> void:
	var zombie: Zombie = _active_zombie(_slow)
	var flash: HitFlashComponent = zombie.get_node("%HitFlash") as HitFlashComponent
	var body: MeshInstance3D = zombie.get_node("Model/Body") as MeshInstance3D
	assert_false(flash.is_flashing(), "no flash before a hit")
	zombie.get_hurtbox().receive_attack(1, UID_A)
	assert_true(flash.is_flashing(), "a hit makes it flash")
	assert_same(body.material_overlay, flash.material, "white over its meshes")
	assert_eq(flash.meshes.size(), 4, "every mesh of the model flashes")
	flash.advance(flash.feedback.enemy_flash_s)
	assert_false(flash.is_flashing(), "for the flash time of the feedback data")
	assert_null(body.material_overlay, "then it looks as before")


func test_r_007_23_reused_zombie_is_clean() -> void:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = ZOMBIE_SCENE
	add_child_autofree(pool)
	var holder: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var zombie: Zombie = pool.acquire() as Zombie
	holder.add_child(zombie)
	zombie.activate(_slow, HOME, BRAIN_SEED)
	zombie.get_hurtbox().receive_attack(_slow.hp_max, UID_A)
	assert_true(zombie.get_health().is_dead(), "first life: killed")
	pool.release(zombie)
	var reused: Zombie = pool.acquire() as Zombie
	assert_same(reused, zombie, "the pool gives the same instance back")
	holder.add_child(reused)
	reused.activate(_fast, HOME, BRAIN_SEED + 1)
	var flash: HitFlashComponent = reused.get_node("%HitFlash") as HitFlashComponent
	var body: MeshInstance3D = reused.get_node("Model/Body") as MeshInstance3D
	assert_eq(reused.get_health().get_current(), _fast.hp_max, "full HP")
	assert_false(flash.is_flashing(), "no flash")
	assert_null(body.material_overlay, "no flash material left on its meshes")
	assert_eq(reused.get_hurtbox().get_last_attacker_uid(), "", "no record of who hit it")
	assert_true(reused.get_hurtbox().is_alive(), "and it can be hit again")
	watch_signals(EventBus)
	reused.get_health().take_damage(_fast.hp_max)
	assert_signal_not_emitted(EventBus, "enemy_killed", "the kill of its first life is not repeated")
