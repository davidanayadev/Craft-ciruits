class_name CombatFeedback
extends Node
## Combat feedback of the local player (spec 007): the one place that turns
## combat signals into camera shakes, sparks and the red screen edge, with the
## values of CombatFeedbackData. It only listens and only calls presentation:
## never battery, HP or XP (R-007-26).

@export var config: CombatFeedbackData
## Pool of ImpactSparks (R-007-27).
@export var impact_pool: ObjectPool
## Parent of the sparks while they play.
@export var effects_root: Node3D

var _camera_rig: CameraRig
var _hud: Hud


## Hooks the feedback to the local robot. Missing data → push_error, no change.
func bind(robot: Robot, camera_rig: CameraRig, hud: Hud) -> void:
	if config == null or impact_pool == null or effects_root == null:
		push_error("CombatFeedback '%s': config, impact_pool and effects_root must be assigned." % name)
		return
	_camera_rig = camera_rig
	_hud = hud
	robot.melee.hit_dealt.connect(_on_hit_dealt)
	robot.hit_received.connect(_on_hit_received)


## Every burst still playing goes back to the pool at once: a travel is about
## to unload the zone they lit up (R-009-04).
func release_all() -> void:
	if effects_root == null or impact_pool == null:
		return
	for child: Node in effects_root.get_children():
		var sparks: ImpactSparks = child as ImpactSparks
		if sparks != null:
			impact_pool.release(sparks)


func _on_hit_dealt(target: HurtboxComponent) -> void:
	_camera_rig.shake(config.hit_dealt_shake_m, config.hit_dealt_shake_s)
	_play_sparks(target.global_position)


func _on_hit_received(_damage: float, _attacker: Node3D) -> void:
	_camera_rig.shake(config.hit_received_shake_m, config.hit_received_shake_s)
	_hud.flash_damage(config.screen_edge_flash_s)


func _play_sparks(at: Vector3) -> void:
	var instance: Node = impact_pool.acquire()
	var sparks: ImpactSparks = instance as ImpactSparks
	if sparks == null:
		push_error("CombatFeedback '%s': the pool '%s' does not hold ImpactSparks." % [name, impact_pool.name])
		if instance != null:
			impact_pool.release(instance)
		return
	sparks.position = effects_root.to_local(at)
	effects_root.add_child(sparks)
	if not sparks.finished.is_connected(_on_sparks_finished):
		sparks.finished.connect(_on_sparks_finished)
	sparks.play()


func _on_sparks_finished(sparks: ImpactSparks) -> void:
	# Deferred: the signal comes from the node that is about to leave the tree.
	_release_sparks.call_deferred(sparks)


func _release_sparks(sparks: ImpactSparks) -> void:
	if is_instance_valid(sparks) and sparks.get_parent() == effects_root:
		impact_pool.release(sparks)
