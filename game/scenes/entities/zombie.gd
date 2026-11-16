class_name Zombie
extends CharacterBody3D
## Zombie (spec 006): asks its EnemyBrain what to do, walks with its
## NavigationAgent3D, animates and hits. Presentation and wiring only (P3):
## the rules live in EnemyBrain and every number comes from its EnemyData.
## Instances are pooled: activate() starts a new life from scratch, so the
## same instance can come back as another kind of zombie.

## Its HealthComponent reached 0. Whoever placed it returns it to the pool.
signal defeated(zombie: Zombie)

const ANIMATION_IDLE := &"idle"
const ANIMATION_WALK := &"walk"
const ANIMATION_ATTACK := &"attack"

var _data: EnemyData
var _brain: EnemyBrain
## Patrol point the agent is already heading to, to set its target only once.
var _patrol_point: Vector3 = Vector3.INF

@onready var _health: HealthComponent = %Health
@onready var _nav_agent: NavigationAgent3D = %NavAgent
@onready var _animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	set_physics_process(false)
	_health.died.connect(_on_died)


func _exit_tree() -> void:
	# Back to the pool, dead or alive: it acts again only after activate(), so
	# reuse does not depend on the order of add_child() and activate().
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var target: Robot = _find_target()
	var distance: float = INF
	if target != null:
		distance = _flat_offset_to(target.global_position).length()
	var patrol_arrived: bool = (
		_brain.get_state() == EnemyBrain.State.PATROL and _nav_agent.is_navigation_finished()
	)
	var hit_lands: bool = _brain.tick(delta, distance, patrol_arrived)
	if hit_lands and target != null:
		target.receive_hit(_data.hit_damage, self)
	_act(target)


## Starts a new life as the given kind of enemy, standing at home (global
## coordinates). Call it once the zombie is inside the tree; whoever adds it
## should place it at home first, so its body does not jump there from where it
## entered. brain_seed seeds its pauses and patrol points. Missing data →
## push_error and it stays inactive.
func activate(data: EnemyData, home: Vector3, brain_seed: int) -> void:
	if data == null or data.ai == null or not is_inside_tree():
		push_error("Zombie '%s': activate() needs an EnemyData with ai, inside the tree." % name)
		return
	_data = data
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = brain_seed
	_brain = EnemyBrain.new(data.ai, data.attack_interval, rng)
	_brain.reset(home)
	_patrol_point = Vector3.INF
	global_position = home
	velocity = Vector3.ZERO
	_health.reset(data.hp_max)
	_animation_player.play(ANIMATION_IDLE)
	set_physics_process(true)


func get_data() -> EnemyData:
	return _data


## IDLE until it is activated.
func get_state() -> EnemyBrain.State:
	if _brain == null:
		return EnemyBrain.State.IDLE
	return _brain.get_state()


func get_health() -> HealthComponent:
	return _health


## Nearest player with battery left; a depleted one is not a target (R-006-18).
## Looked up by group on every step, so it needs no reference to any player
## and works unchanged with several of them.
func _find_target() -> Robot:
	var nearest: Robot = null
	var nearest_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Robot.PLAYER_GROUP):
		var robot: Robot = node as Robot
		if robot == null or robot.battery.is_depleted():
			continue
		var distance: float = _flat_offset_to(robot.global_position).length()
		if distance < nearest_distance:
			nearest = robot
			nearest_distance = distance
	return nearest


func _act(target: Robot) -> void:
	match _brain.get_state():
		EnemyBrain.State.IDLE:
			_stand(ANIMATION_IDLE)
		EnemyBrain.State.PATROL:
			_head_to_patrol_point()
			_walk()
		EnemyBrain.State.CHASE:
			if target != null:
				_nav_agent.target_position = target.global_position
			_walk()
		EnemyBrain.State.ATTACK:
			if target != null:
				_face(_flat_offset_to(target.global_position))
			_stand(ANIMATION_ATTACK)


func _stand(animation: StringName) -> void:
	velocity = Vector3.ZERO
	_play(animation)


func _walk() -> void:
	var direction: Vector3 = _flat_offset_to(_nav_agent.get_next_path_position()).normalized()
	velocity = direction * _data.move_speed
	_face(direction)
	_play(ANIMATION_WALK if direction != Vector3.ZERO else ANIMATION_IDLE)
	move_and_slide()


func _head_to_patrol_point() -> void:
	var point: Vector3 = _brain.get_patrol_point()
	if point == _patrol_point:
		return
	_patrol_point = point
	_nav_agent.target_position = _project_on_navmesh(point)


## Closest walkable point, so a patrol point inside an obstacle or beyond the
## fence can still be reached and the patrol ends (R-006-12).
func _project_on_navmesh(point: Vector3) -> Vector3:
	var map: RID = _nav_agent.get_navigation_map()
	# Before its first synchronisation the map cannot be queried (engine error).
	# The agent then resolves the raw point once the map is ready.
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return point
	return NavigationServer3D.map_get_closest_point(map, point)


func _face(direction: Vector3) -> void:
	if direction != Vector3.ZERO:
		rotation.y = LocomotionSystem.target_yaw(direction)


func _play(animation: StringName) -> void:
	if _animation_player.current_animation != animation:
		_animation_player.play(animation)


func _flat_offset_to(point: Vector3) -> Vector3:
	return Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)


func _on_died() -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	_animation_player.stop()
	defeated.emit(self)
