class_name InteractorComponent
extends Area3D
## Lives on an entity that can interact (the robot): keeps track of the
## nearest enabled InteractableComponent in range (architecture §9.1) and
## reports every change of target. Per-entity state (constitution P4).

## null = no target.
signal target_changed(target: InteractableComponent)

## interaction_range_m is the radius of the detection sphere (BALANCE §11).
@export var config: ControlConfigData

var _target: InteractableComponent = null
var _has_target: bool = false
var _range: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(InteractableComponent.PHYSICS_LAYER, true)
	monitoring = true
	monitorable = false
	if config == null:
		push_error("InteractorComponent '%s': config must be assigned." % name)
		return
	_range = config.interaction_range_m
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = _range
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = sphere
	add_child(collision)


func _physics_process(_delta: float) -> void:
	var candidates: Array[InteractableComponent] = []
	for area: Area3D in get_overlapping_areas():
		var interactable: InteractableComponent = area as InteractableComponent
		if interactable != null:
			candidates.append(interactable)
	_set_target(pick_nearest(global_position, candidates))


func get_range() -> float:
	return _range


func get_target() -> InteractableComponent:
	# A target freed with its object since the last physics frame is no target.
	return _target if is_instance_valid(_target) else null


## Calls interact(interactor) on the current target; false when there is none.
func interact_with_target(interactor: Node3D) -> bool:
	var target: InteractableComponent = get_target()
	if target == null or not target.enabled:
		return false
	target.interact(interactor)
	return true


## The enabled candidate closest to origin, or null. Ties go to the first one.
static func pick_nearest(
	origin: Vector3, candidates: Array[InteractableComponent]
) -> InteractableComponent:
	var nearest: InteractableComponent = null
	var nearest_distance: float = INF
	for candidate: InteractableComponent in candidates:
		if not candidate.enabled:
			continue
		var distance: float = origin.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _set_target(target: InteractableComponent) -> void:
	# _has_target catches a target freed in the meantime: get_target() already
	# reads as none, but that change was never reported.
	if target == get_target() and _has_target == (target != null):
		return
	_target = target
	_has_target = target != null
	target_changed.emit(target)
