class_name MeleeAttackComponent
extends Node3D
## Melee attack of one entity (spec 007): the state of its swing and its
## hitbox, a box in front of the owner. Per-entity state (constitution P4).
## It has no _physics_process and reads no input or battery: the owner feeds it
## through tick(), so the rhythm is testable with hand-made deltas and the
## rules stay in CombatSystem.
## The hitbox exists only at the impact: one instant shape query that sees
## nothing but HurtboxComponents (R-007-12), with the transform of that very
## physics step, so it faces where the owner faces (R-007-14).

## A swing began; the owner pays the cost, hit or miss (R-007-10).
signal swing_started(battery_cost: float)
## The impact damaged this target. Emitted once per target and swing.
signal hit_dealt(target: HurtboxComponent)

## One arm until spec 014 derives it from StatsComponent (R-007-02).
@export var attack: AttackStatsData
@export var config: CombatConfigData
## Collision geometry that covers the owner's body, not gameplay values: the
## reach and the width come from config.
@export var hitbox_height_m: float = 0.0
@export var hitbox_center_y_m: float = 0.0

## Who the kills count for; set by the owner.
var attacker_uid: String = ""

## INF: the first swing starts at once.
var _seconds_since_swing: float = INF
var _impact_pending: bool = false
var _shape: BoxShape3D = null


func _ready() -> void:
	if not CombatSystem.is_valid_attack(attack) or config == null:
		push_error("MeleeAttackComponent '%s': needs a valid attack and a config." % name)
		return
	# Built in code so no two instances share the shape.
	_shape = BoxShape3D.new()
	_shape.size = Vector3(config.hitbox_width_m, hitbox_height_m, config.hitbox_reach_m)


## Advances the swing by delta seconds: lands the pending impact when its
## moment comes, then starts a new swing if the owner wants one and
## CombatSystem allows it. A press that cannot start a swing is not kept
## (R-007-07). A swing already started ends even if the battery runs out or a
## screen opens: its cost is paid.
func tick(delta: float, wants_to_swing: bool, battery_depleted: bool, input_blocked: bool) -> void:
	if _shape == null:
		return
	var seconds_before: float = _seconds_since_swing
	_seconds_since_swing += delta
	if _impact_pending and CombatSystem.impact_reached(
		seconds_before, _seconds_since_swing, config.impact_time_s
	):
		_impact_pending = false
		apply_impact(find_targets())
	if wants_to_swing and CombatSystem.can_start_swing(
		_seconds_since_swing, attack, battery_depleted, input_blocked
	):
		_seconds_since_swing = 0.0
		_impact_pending = true
		swing_started.emit(attack.battery_cost)


## Deals the damage of the attack once to each distinct living target
## (R-007-11). Public so the rule is testable without physics.
func apply_impact(targets: Array[HurtboxComponent]) -> void:
	var damage: int = CombatSystem.damage_per_hit(attack)
	var hit: Array[HurtboxComponent] = []
	for target: HurtboxComponent in targets:
		if target == null or hit.has(target) or not target.is_alive():
			continue
		hit.append(target)
		target.receive_attack(damage, attacker_uid)
		hit_dealt.emit(target)


## Hurtboxes inside the hitbox right now. Empty outside the tree.
func find_targets() -> Array[HurtboxComponent]:
	var targets: Array[HurtboxComponent] = []
	if _shape == null or not is_inside_tree():
		return targets
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for hit: Dictionary in space.intersect_shape(build_query()):
		var hurtbox: HurtboxComponent = hit["collider"] as HurtboxComponent
		if hurtbox != null:
			targets.append(hurtbox)
	return targets


## The impact query: the box in front of the owner, against hurtbox areas
## only. No bodies and no other layer, so the owner, loot boxes and scenery
## can never be hit.
func build_query() -> PhysicsShapeQueryParameters3D:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = get_hitbox_transform()
	query.collision_mask = 1 << (HurtboxComponent.PHYSICS_LAYER - 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return query


## Global transform of the box: from the owner's centre to the reach, towards
## -Z, which is where entities face (LocomotionSystem.target_yaw).
func get_hitbox_transform() -> Transform3D:
	var center: Vector3 = Vector3(0.0, hitbox_center_y_m, -config.hitbox_reach_m / 2.0)
	return global_transform * Transform3D(Basis.IDENTITY, center)


func get_hitbox_shape() -> BoxShape3D:
	return _shape


## True between the start of a swing and its impact.
func is_impact_pending() -> bool:
	return _impact_pending
