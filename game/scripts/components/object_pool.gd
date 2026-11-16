class_name ObjectPool
extends Node
## Generic pool of instances of one scene (spec 006, architecture §11): enemies
## now, projectiles, particles and dropped items later. Reusing instances
## avoids creating and freeing nodes in the middle of the game, which stutters
## on mobile (constitution P12).
## Stored instances stay outside the tree. The pool does not reset them: the
## scene offers its own activate()/reset, because only it knows its state.

@export var scene: PackedScene

var _free: Array[Node] = []
## Instance ids of everything this pool created, in use or stored. Ids and not
## references: an instance in use can be freed by whoever holds it.
var _owned: Dictionary[int, bool] = {}


func _notification(what: int) -> void:
	# Stored instances have no parent, so nothing else would free them.
	if what == NOTIFICATION_PREDELETE:
		for instance: Node in _free:
			if is_instance_valid(instance):
				instance.free()


## A stored instance, or a new one when none is left. It comes outside the
## tree: the caller adds it where it belongs. No scene → push_error and null.
func acquire() -> Node:
	if not _free.is_empty():
		return _free.pop_back()
	return _create()


## Takes the instance out of its parent and stores it. Null, an instance this
## pool did not create or one that is already stored → push_error, no change.
func release(instance: Node) -> void:
	if instance == null or not _owned.has(instance.get_instance_id()):
		push_error("ObjectPool '%s': release() got a node that is not from this pool." % name)
		return
	if _free.has(instance):
		push_error("ObjectPool '%s': '%s' was already released." % [name, instance.name])
		return
	var parent: Node = instance.get_parent()
	if parent != null:
		parent.remove_child(instance)
	_free.append(instance)


## Creates instances until count are stored, so none is created mid-game.
func prewarm(count: int) -> void:
	while _free.size() < count:
		var instance: Node = _create()
		if instance == null:
			return
		_free.append(instance)


func get_free_count() -> int:
	return _free.size()


func _create() -> Node:
	if scene == null:
		push_error("ObjectPool '%s': scene must be assigned." % name)
		return null
	var instance: Node = scene.instantiate()
	_owned[instance.get_instance_id()] = true
	return instance
