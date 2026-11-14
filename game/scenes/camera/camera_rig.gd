class_name CameraRig
extends Node3D
## Isometric camera rig (R-002-01/02): applies CameraConfigData and rigidly
## follows the target, keeping the same angle and distance.

@export var config: CameraConfigData
@export var target: Node3D

@onready var camera: Camera3D = %Camera


func _ready() -> void:
	apply_config()


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
