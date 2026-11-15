extends Node
## Autoload "GameManager": global state of the current game (architecture §5).
## Never per-player state (PMV §4.5 hook 7). No class_name: it would clash
## with the autoload name.

const DEV_WORLD_PATH := "res://resources/config/dev_world.tres"

var _world_seed: int = 0


func _ready() -> void:
	var dev_world: DevWorldConfigData = load(DEV_WORLD_PATH) as DevWorldConfigData
	if dev_world == null:
		push_error("GameManager: %s is missing or is not a DevWorldConfigData." % DEV_WORLD_PATH)
		return
	_world_seed = dev_world.world_seed


func get_world_seed() -> int:
	return _world_seed
