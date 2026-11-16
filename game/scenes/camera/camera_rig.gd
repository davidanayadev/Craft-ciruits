class_name CameraRig
extends Node3D
## Isometric camera rig (R-002-01/02): applies CameraConfigData and rigidly
## follows the target, keeping the same angle and distance.
## It can shake (spec 007): the camera is displaced in the plane of the screen
## with its offsets, so the position that follows the target is never touched.

## Seed of the shake directions. Presentation only: the world seed has no say.
const SHAKE_SEED := 1

@export var config: CameraConfigData
@export var target: Node3D

var _shake_strength_m: float = 0.0
var _shake_duration_s: float = 0.0
var _shake_seconds_left: float = 0.0
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var camera: Camera3D = %Camera


func _ready() -> void:
	_shake_rng.seed = SHAKE_SEED
	set_process(false)
	apply_config()


func _process(delta: float) -> void:
	advance_shake(delta)


func _physics_process(_delta: float) -> void:
	if target != null:
		global_position = target.global_position


func apply_config() -> void:
	if config == null:
		push_error("CameraRig: config is required (resources/config/camera.tres)")
		return
	rotation = Vector3(0.0, deg_to_rad(config.yaw_degrees), 0.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = config.ortho_size
	camera.rotation = Vector3(-deg_to_rad(config.pitch_degrees), 0.0, 0.0)
	var pitch: float = deg_to_rad(config.pitch_degrees)
	# Placed so the camera looks exactly at the rig origin from config.distance.
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * config.distance


## Shakes the camera: at most strength_m metres off, fading to 0 over
## duration_s seconds. A new shake replaces the current one unless the current
## one still has more strength left.
func shake(strength_m: float, duration_s: float) -> void:
	if strength_m <= 0.0 or duration_s <= 0.0:
		return
	if _current_shake_strength() > strength_m:
		return
	_shake_strength_m = strength_m
	_shake_duration_s = duration_s
	_shake_seconds_left = duration_s
	set_process(true)


func is_shaking() -> bool:
	return _shake_seconds_left > 0.0


## Advances the shake by delta seconds; _process calls it while shaking.
func advance_shake(delta: float) -> void:
	if not is_shaking():
		return
	_shake_seconds_left -= delta
	var offset: Vector2 = Vector2.ZERO
	if is_shaking():
		offset = Vector2.from_angle(_shake_rng.randf_range(0.0, TAU)) * _current_shake_strength()
	else:
		_shake_seconds_left = 0.0
		set_process(false)
	camera.h_offset = offset.x
	camera.v_offset = offset.y


## Strength left of the current shake: linear from its strength down to 0.
func _current_shake_strength() -> float:
	if not is_shaking():
		return 0.0
	return _shake_strength_m * _shake_seconds_left / _shake_duration_s
