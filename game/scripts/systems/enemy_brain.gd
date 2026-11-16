class_name EnemyBrain
extends RefCounted
## Enemy AI state machine (spec 006): Idle, Patrol, Chase, Attack. Pure rules:
## the distance to the target and delta come by parameter, so it runs without
## nodes or scene tree, and the entity that owns it only moves and animates.
## It knows nothing about zombies: any enemy with an EnemyAiData can use it.
## Pauses and patrol points come from the RNG given at creation, so the same
## seed gives the same behaviour.

enum State { IDLE, PATROL, CHASE, ATTACK }

var _ai: EnemyAiData
var _attack_interval: float
var _rng: RandomNumberGenerator
var _state: State = State.IDLE
var _home: Vector3 = Vector3.ZERO
var _patrol_point: Vector3 = Vector3.ZERO
var _pause_left: float = 0.0
var _attack_timer: float = 0.0


func _init(ai: EnemyAiData, attack_interval: float, rng: RandomNumberGenerator) -> void:
	_ai = ai
	_attack_interval = attack_interval
	_rng = rng


## Back to IDLE around home (global coordinates), with a new pause and the
## attack wait at 0.
func reset(home: Vector3) -> void:
	_home = home
	_patrol_point = home
	_enter_idle()


## Advances one step and returns true when a hit lands in it.
## target_distance is the distance on the ground to the nearest living player,
## or INF when there is none. patrol_arrived says whether the owner reached
## get_patrol_point(). At most one transition per step, and a step that
## changes state never hits.
func tick(delta: float, target_distance: float, patrol_arrived: bool) -> bool:
	match _state:
		State.IDLE:
			_tick_idle(delta, target_distance)
		State.PATROL:
			_tick_patrol(target_distance, patrol_arrived)
		State.CHASE:
			_tick_chase(target_distance)
		State.ATTACK:
			return _tick_attack(delta, target_distance)
	return false


func get_state() -> State:
	return _state


## Where to walk to while in PATROL, in the same coordinates as home.
func get_patrol_point() -> Vector3:
	return _patrol_point


func _tick_idle(delta: float, target_distance: float) -> void:
	if target_distance <= _ai.vision_radius:
		_state = State.CHASE
		return
	_pause_left -= delta
	if _pause_left <= 0.0:
		_enter_patrol()


func _tick_patrol(target_distance: float, patrol_arrived: bool) -> void:
	if target_distance <= _ai.vision_radius:
		_state = State.CHASE
	elif patrol_arrived:
		_enter_idle()


func _tick_chase(target_distance: float) -> void:
	# Giving up is checked first: a target that vanished (INF) is never attacked.
	if target_distance > _ai.give_up_distance:
		_enter_patrol()
	elif target_distance <= _ai.attack_range:
		_attack_timer = 0.0
		_state = State.ATTACK


func _tick_attack(delta: float, target_distance: float) -> bool:
	if target_distance > _ai.give_up_distance:
		_enter_patrol()
		return false
	if target_distance > _ai.attack_range:
		# Leaving the range restarts the wait (BALANCE §3.1).
		_attack_timer = 0.0
		_state = State.CHASE
		return false
	_attack_timer += delta
	if _attack_timer < _attack_interval:
		return false
	# Keeping the remainder makes the rate independent of the frame rate.
	_attack_timer -= _attack_interval
	return true


func _enter_idle() -> void:
	_state = State.IDLE
	_attack_timer = 0.0
	_pause_left = _rng.randf_range(_ai.patrol_pause_min, _ai.patrol_pause_max)


func _enter_patrol() -> void:
	_state = State.PATROL
	_attack_timer = 0.0
	var angle: float = _rng.randf_range(0.0, TAU)
	# The square root spreads the points evenly over the disc, not towards its centre.
	var distance: float = _ai.patrol_radius * sqrt(_rng.randf())
	_patrol_point = _home + Vector3(cos(angle), 0.0, sin(angle)) * distance
