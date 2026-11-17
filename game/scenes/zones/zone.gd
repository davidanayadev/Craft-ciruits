class_name Zone
extends Node3D
## What every zone scene offers ZoneLoader (spec 009, architecture §6): its
## data, where players appear and the requests of its exit point. FarmZone and
## BaseZone extend it; the loader asks data.kind for what is specific to each.
## Every zone scene has a %SpawnPoint and an %ExitPoint.

## A player interacted with the exit point. Relayed so whoever loads the zone
## connects one signal.
signal exit_requested(destination: ZoneData, traveller: Node3D)

@export var data: ZoneData

@onready var _spawn_point: Marker3D = %SpawnPoint
@onready var _exit_point: ExitPoint = %ExitPoint


func _ready() -> void:
	_exit_point.travel_requested.connect(_on_exit_travel_requested)


func get_spawn_position() -> Vector3:
	return _spawn_point.global_position


func _on_exit_travel_requested(destination: ZoneData, traveller: Node3D) -> void:
	exit_requested.emit(destination, traveller)
