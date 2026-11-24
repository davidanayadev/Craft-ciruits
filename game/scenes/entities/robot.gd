class_name Robot
extends CharacterBody3D
## Player robot (spec 002): reads PlayerInput, applies LocomotionSystem results
## and moves with real physics. Presentation and wiring only (P3).
## It also feeds its gait to its BatteryComponent every physics frame (spec 003)
## and interacts with the target of its InteractorComponent (spec 004).
## It owns its inventory, sized by its chassis level (spec 005): it gives the
## level table to its ExperienceComponent and grows the inventory on every
## level_changed (spec 014). Experience goes before InventoryComponent in
## robot.tscn: saved parts load in tree order, so on load the inventory already
## has the slots of the loaded level when it reads its own (R-014-16).
## Enemies find it through PLAYER_GROUP and hit it with receive_hit() (spec 006).
## It swings its MeleeAttackComponent, pays each swing with battery and earns
## the XP of the enemies it kills (spec 007).
## It asks to throw items and takes its place again after a death, but it does
## not know the dropped items nor the ruleset (spec 008).
## It asks to build at the repair bench, and tells the base grid how much
## floor it covers, so no structure is placed on it (spec 009).

## A hit landed on this robot. Degradation of pieces connects here (spec 015).
signal hit_received(damage: float, attacker: Node3D)
## The player wants quantity of that inventory slot on the ground. Whoever
## owns the dropped items makes the change (spec 008).
signal throw_requested(player: Robot, slot_index: int, quantity: int)
## The player picked a recipe to build; nothing is charged until it is placed
## (R-009-65). Whoever owns the placement flow opens it.
signal build_requested(player: Robot, recipe: RecipeData)
## A request to use a consumable was refused; the HUD shows tr(error_key) (spec 012, plan D19).
signal use_refused(error_key: StringName)

## Group of every player entity; set in robot.tscn. Enemies look their target
## up here instead of holding a reference, so co-op needs no change.
const PLAYER_GROUP := &"players"
const ANIMATION_ATTACK := &"attack"

@export var movement_stats: MovementStatsData
@export var control_config: ControlConfigData
## XP thresholds and inventory slots per chassis level (spec 014); assigned once, here.
@export var chassis_levels: ChassisLevelData
## Yaw source for camera-relative movement; null falls back to world axes.
@export var camera_rig: Node3D

## Who this player is in kills, saves and, later, the network. A generated one
## until the Profile's player_uuid arrives with set_player_uid() (spec 010).
var player_uid: String = ""

@onready var player_input: PlayerInput = %PlayerInput
@onready var battery: BatteryComponent = %BatteryComponent
@onready var interactor: InteractorComponent = %Interactor
@onready var inventory: InventoryComponent = %InventoryComponent
@onready var melee: MeleeAttackComponent = %MeleeAttack
@onready var experience: ExperienceComponent = %Experience
@onready var location: LocationComponent = %Location
@onready var _animation_player: AnimationPlayer = %AnimationPlayer
@onready var _body_shape: CollisionShape3D = %BodyShape


func _ready() -> void:
	player_uid = Uid.generate()
	melee.attacker_uid = player_uid
	melee.swing_started.connect(_on_swing_started)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	if chassis_levels == null:
		push_error("Robot '%s': chassis_levels must be assigned." % name)
		return
	experience.set_level_table(chassis_levels)
	experience.level_changed.connect(_on_level_changed)
	_on_level_changed(experience.get_level())


func _physics_process(delta: float) -> void:
	if player_input.is_interact_just_pressed():
		request_interact()
	if player_input.is_use_consumable_just_pressed():
		request_use_consumable()
	_move(delta)
	# After moving and turning: the impact uses the facing of this very step
	# (R-007-14).
	melee.tick(
		delta, player_input.poll_attack(), battery.is_depleted(), player_input.is_input_blocked()
	)


## Interacts with the nearest interactable in range, if any. Both input paths
## end here: the interact action and the HUD button. A robot with a depleted
## battery (R-004-16) or with its input blocked by a screen (R-005-27) does
## nothing.
func request_interact() -> void:
	if battery.is_depleted() or player_input.is_input_blocked():
		return
	interactor.interact_with_target(self)


## Asks to throw quantity of an inventory slot at its feet. A robot with a
## depleted battery asks for nothing.
func request_throw(slot_index: int, quantity: int) -> void:
	if battery.is_depleted():
		return
	throw_requested.emit(self, slot_index, quantity)


## Asks to build what recipe makes. A robot with a depleted battery asks for nothing.
func request_build(recipe: RecipeData) -> void:
	if battery.is_depleted():
		return
	build_requested.emit(self, recipe)


## Uses one unit of the consumable in slot_index: it leaves that slot and its
## battery_points go to the battery through BatteryComponent.add, in one call
## (spec 012, R-012-23). A ConsumableRules.check_use refusal → its key,
## use_refused, no change (R-012-24). A depleted robot → ERR_INVALID_REQUEST,
## nothing else.
func use_consumable(slot_index: int) -> ActionResult:
	if battery.is_depleted():
		return ActionResult.failure(ActionResult.ERR_INVALID_REQUEST)
	var slots: Array[ItemStack] = inventory.get_slots()
	var checked: ActionResult = ConsumableRules.check_use(
		slots, slot_index, battery.get_current(), battery.get_maximum()
	)
	if not checked.ok:
		if checked.error_key != ActionResult.ERR_INVALID_REQUEST:
			use_refused.emit(checked.error_key)
		return checked
	var amounts: Array[int] = []
	amounts.resize(slots.size())
	amounts.fill(0)
	amounts[slot_index] = 1
	var removed: ActionResult = inventory.remove_from_slots(amounts)
	if not removed.ok:
		return removed
	battery.add((slots[slot_index].item as ConsumableData).battery_points)
	return ActionResult.success()


## The use_consumable action and the inventory's "Use" button (R-012-25):
## slot_index, or the first consumable slot when NO_SLOT (plan D4). Without
## one, ERR_NO_PORTABLE_BATTERY through use_refused. A depleted robot asks for nothing.
func request_use_consumable(slot_index: int = ConsumableRules.NO_SLOT) -> void:
	if battery.is_depleted():
		return
	var index: int = slot_index
	if index == ConsumableRules.NO_SLOT:
		index = ConsumableRules.first_consumable_slot(inventory.get_slots())
	use_consumable(index)


## Radius of the floor circle the robot stands on (R-009-58).
func get_footprint_radius() -> float:
	var capsule: CapsuleShape3D = _body_shape.shape as CapsuleShape3D
	if capsule == null:
		push_error("Robot '%s': its body shape is not a capsule." % name)
		return 0.0
	return capsule.radius


## The Profile's player_uuid (R-010-14); also the attacker uid of its melee.
func set_player_uid(uid: String) -> void:
	player_uid = uid
	melee.attacker_uid = uid


## Arrives in zone_id at world_position, standing still: place_at() plus the
## location it saves (spec 010). ZoneLoader calls it when a travel ends.
func enter_zone(zone_id: Vector2i, zone_root: Node3D, world_position: Vector3) -> void:
	place_at(world_position)
	location.enter(zone_id, zone_root)


## Places itself at world_position, standing still: how it arrives in a zone
## after a travel (spec 009).
func place_at(world_position: Vector3) -> void:
	global_position = world_position
	velocity = Vector3.ZERO


## Places itself at world_position, standing still, and charges
## battery_amount points: how a dead robot comes back (spec 008).
func respawn_at(world_position: Vector3, battery_amount: float) -> void:
	place_at(world_position)
	battery.add(battery_amount)


## Takes a hit: damage battery points, 1:1 (BALANCE §3.1), then hit_received.
## A robot with a depleted battery takes none (R-006-18). Negative damage →
## push_error, no change.
func receive_hit(damage: float, attacker: Node3D) -> void:
	if damage < 0.0:
		push_error("Robot '%s': receive_hit() got a negative damage (%f)." % [name, damage])
		return
	if battery.is_depleted():
		return
	battery.consume(damage)
	hit_received.emit(damage, attacker)


func _move(delta: float) -> void:
	var camera_yaw: float = camera_rig.rotation.y if camera_rig != null else 0.0
	var world_dir: Vector3 = LocomotionSystem.world_direction(
		player_input.get_direction(), camera_yaw
	)
	var run_intent: bool = player_input.is_run_intent()
	velocity = LocomotionSystem.horizontal_velocity(world_dir, run_intent, movement_stats)
	# The gait comes from the intent, not from the real displacement: pushing
	# against a wall drains like walking (plan 003 §7).
	battery.tick(delta, LocomotionSystem.gait(world_dir, run_intent, movement_stats))
	if world_dir != Vector3.ZERO:
		rotation.y = LocomotionSystem.rotate_toward_yaw(
			rotation.y,
			LocomotionSystem.target_yaw(world_dir),
			control_config.turn_speed_rad,
			delta
		)
	move_and_slide()


## Every swing costs battery, hit or miss (R-007-10). The animation is only
## presentation: the impact moment comes from CombatConfigData.
func _on_swing_started(battery_cost: float) -> void:
	battery.consume(battery_cost)
	_animation_player.stop()
	_animation_player.play(ANIMATION_ATTACK)


## The inventory takes the slots of the level; the same count changes nothing (R-014-08).
func _on_level_changed(level: int) -> void:
	inventory.set_slot_count(chassis_levels.get_inventory_slots(level))


## Only this robot's kills count: with several players each one earns its own.
func _on_enemy_killed(enemy_id: StringName, killer_uid: String) -> void:
	experience.reward_kill(enemy_id, killer_uid, player_uid, DataRegistry.get_catalog())
