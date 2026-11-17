class_name ChargingStation
extends StaticBody3D
## Charging station (spec 009, BALANCE §5.3): a placed structure of the base.
## Interacting fills the player's battery to its maximum at once, at no cost
## and with no limit of uses, through the battery's own method, and announces
## it so spec 010 can save. It writes nothing to disk and holds no state.

@onready var _interactable: InteractableComponent = %Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(interactor: Node3D) -> void:
	var player: Robot = interactor as Robot
	if player == null:
		push_error("ChargingStation '%s': '%s' is not a player." % [name, interactor.name])
		return
	player.battery.recharge_full()
	EventBus.player_recharged.emit(player.player_uid)
