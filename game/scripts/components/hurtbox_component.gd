class_name HurtboxComponent
extends Area3D
## Makes an entity hittable (spec 007): what a melee hitbox detects. The entity
## adds a collision shape as a child and points `health` at its
## HealthComponent. It remembers who hit it last, so its owner can say who
## killed it without HealthComponent knowing about players.

## 3D physics layer reserved for hurtboxes, named "hurtbox" in project.godot.
## The only place where the number lives.
const PHYSICS_LAYER := 3

## An attack lowered the HP. Feedback (flash) connects here.
signal hurt(damage: int, attacker_uid: String)

@export var health: HealthComponent

var _last_attacker_uid: String = ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(PHYSICS_LAYER, true)
	monitoring = false
	monitorable = true
	if health == null:
		push_error("HurtboxComponent '%s': health must be assigned." % name)


## Takes damage HP from the entity in the name of attacker_uid. Negative damage
## → push_error, no change. An entity that is dead or not alive yet ignores it.
func receive_attack(damage: int, attacker_uid: String) -> void:
	if damage < 0:
		push_error("HurtboxComponent '%s': receive_attack() got a negative damage (%d)." % [name, damage])
		return
	if not is_alive():
		return
	# Before the damage: died is emitted inside take_damage(), and whoever
	# listens to it asks for the final hitter.
	_last_attacker_uid = attacker_uid
	health.take_damage(damage)
	hurt.emit(damage, attacker_uid)


## False before the first life of the entity and after its death.
func is_alive() -> bool:
	return health != null and health.get_maximum() > 0 and not health.is_dead()


## "" when nobody hit it in this life.
func get_last_attacker_uid() -> String:
	return _last_attacker_uid


## Starts a new life: forgets who hit it. The HP is reset by the owner.
func reset() -> void:
	_last_attacker_uid = ""
