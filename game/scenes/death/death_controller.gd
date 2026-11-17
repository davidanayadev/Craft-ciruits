class_name DeathController
extends Node
## Applies the world's ruleset to the death of each bound robot and brings it
## back (spec 008). It only reads the fields of the ruleset, never its id, so
## another mode is another RulesetData. It holds no player state: "dead" is
## "battery at 0 until respawn()", and what the robot carried lives in the
## dropped item. The zone a robot died in is the one bound to dropped_items.

@export var dropped_items: DroppedItemSpawner

## The ruleset of the world; set by whoever loads it.
var ruleset: RulesetData


## From now on this robot's deaths follow the ruleset.
func bind(robot: Robot) -> void:
	# battery_depleted comes once per arrival at 0, whatever emptied it.
	robot.battery.battery_depleted.connect(_on_battery_depleted.bind(robot))


## Puts a dead robot at world_position with the battery of the ruleset and
## returns true. No ruleset, or a robot that is not dead → push_error, no
## change and false.
func respawn(robot: Robot, world_position: Vector3) -> bool:
	if ruleset == null or not robot.battery.is_depleted():
		push_error("DeathController: respawn() needs a ruleset and a robot with no battery.")
		return false
	robot.respawn_at(world_position, robot.battery.get_maximum() * ruleset.respawn_battery_ratio)
	EventBus.player_respawned.emit(robot.player_uid)
	return true


func _on_battery_depleted(robot: Robot) -> void:
	if ruleset == null or dropped_items == null:
		push_error("DeathController: needs a ruleset and dropped_items to react to a death.")
		return
	# A dead robot does not hit: a pending impact could kill an enemy whose
	# return to the pool would run after the zone is repopulated.
	robot.melee.cancel_swing()
	if ruleset.drops_inventory:
		dropped_items.drop_inventory(robot.inventory, robot.global_position)
	if not ruleset.keeps_xp:
		robot.experience.reset()
	GameManager.increment_visit_count(dropped_items.get_zone_id())
	# Last, so listeners already see the inventory on the ground.
	EventBus.player_died.emit(robot.player_uid)
