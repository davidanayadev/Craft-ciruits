class_name DeathController
extends Node
## Applies the world's ruleset to the death of each bound robot and brings it
## back (spec 008). It only reads the fields of the ruleset, never its id, so
## another mode is another RulesetData. It holds no player state: "dead" is
## "battery at 0 until respawn()", and what the robot carried lives in the
## dropped item, equipped pieces included (spec 015). The zone a robot died in
## is the one bound to dropped_items; only a zone that counts visits gets a new
## one (spec 009, question 12).

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
		_drop_carried(robot)
	if not ruleset.keeps_xp:
		robot.experience.reset()
	_count_visit(dropped_items.get_zone_id())
	# Last, so listeners already see the inventory on the ground.
	EventBus.player_died.emit(robot.player_uid)


## The inventory and the equipped pieces that fall go into one dropped item:
## arms and legs, and the Core unless the ruleset keeps it (spec 015, R-015-25,
## R-015-27). The pieces leave the equipment only when the item was created
## (plan 015 D12): nothing is lost when there is no zone to drop into.
func _drop_carried(robot: Robot) -> void:
	var slots: Array[PieceData.SlotType] = [PieceData.SlotType.ARMS, PieceData.SlotType.LEGS]
	if not ruleset.keeps_core:
		slots.append(PieceData.SlotType.CORE)
	var pieces: Array[ItemStack] = []
	for slot: PieceData.SlotType in slots:
		var piece: ItemStack = robot.equipment.get_piece(slot)
		if piece != null:
			pieces.append(piece)
	var item: DroppedItem = dropped_items.drop_inventory(robot.inventory, robot.global_position, pieces)
	if item != null and not pieces.is_empty():
		var _taken: Array[ItemStack] = robot.equipment.take_slots(slots)


## A zone the catalog does not know is a bug: reported, and no visit counted.
func _count_visit(zone_id: Vector2i) -> void:
	var catalog: DataCatalog = DataRegistry.get_catalog()
	if catalog == null or not catalog.has_zone(zone_id):
		push_error("DeathController: the robot died in an unknown zone %s." % zone_id)
		return
	if catalog.get_zone(zone_id).counts_visits():
		GameManager.increment_visit_count(zone_id)
