extends Node
## Main scene boot (architecture §6): wires the persistent skeleton together
## (robot <-> camera rig; UI input joins in as the HUD grows). References go
## through unique names, never deep hardcoded paths (P6).
## Until ZoneLoader exists (spec 009) the green zone sits in ZoneSlot from the
## start: Main generates it from the world seed and puts the robot on its
## spawn point (spec 004).
## It also opens the screens (spec 005): the loot screen when the local robot
## opens a box and the inventory on the storage button, and blocks the robot's
## input while one is open. UIManager sits before Hud in UI, so the HUD is
## drawn on top of the screens.
## The zombie pool lives here, under World and not in the zone, so it outlives
## the zone and is reused between visits (spec 006).
## Combat (spec 007): the HUD attack button feeds the robot's input, and the
## feedback and the debug XP are bound to the local robot. The pool of impact
## sparks lives under World, next to the zombie pool.
## Death (spec 008): DeathController applies the ruleset; Main shows the
## transfer screen, freezes World meanwhile and puts the robot back on the
## respawn point. It also repopulates the zone when its visit counter goes up
## and turns thrown items and enemy loot into dropped items, which live under
## World and outside the zone.

@onready var _robot: Robot = %Robot
@onready var _camera_rig: CameraRig = %CameraRig
@onready var _touch_controls: TouchControls = %TouchControls
@onready var _hud: Hud = %Hud
@onready var _ui_manager: UIManager = %UIManager
@onready var _world: Node3D = %World
@onready var _zone: FarmZone = %GreenZone
@onready var _zombie_pool: ObjectPool = %ZombiePool
@onready var _dropped_item_pool: ObjectPool = %DroppedItemPool
@onready var _dropped_items: DroppedItemSpawner = %DroppedItems
@onready var _death_controller: DeathController = %DeathController
@onready var _transfer_screen: TransferScreen = %TransferScreen
@onready var _impact_pool: ObjectPool = %ImpactPool
@onready var _combat_feedback: CombatFeedback = %CombatFeedback
@onready var _debug_hud: DebugHud = %DebugHud


func _ready() -> void:
	_zone.generate(GameManager.get_world_seed(), _get_visit())
	_spawn_enemies()
	_robot.global_position = _zone.get_spawn_position()
	_robot.camera_rig = _camera_rig
	_camera_rig.target = _robot
	_hud.bind(_robot)
	_hud.interact_pressed.connect(_robot.request_interact)
	_hud.storage_pressed.connect(_on_storage_pressed)
	_zone.box_opened.connect(_on_box_opened)
	_ui_manager.modal_state_changed.connect(_robot.player_input.set_input_blocked)
	_ui_manager.modal_state_changed.connect(_hud.set_modal_open)
	_touch_controls.joystick.sample_changed.connect(_on_joystick_sample_changed)
	_touch_controls.joystick.released.connect(_on_joystick_released)
	_wire_combat()
	_wire_dropped_items()
	_wire_death()


## Attack button, combat feedback and debug XP of the local robot.
func _wire_combat() -> void:
	# At most one burst per enemy and swing, and a burst ends before the next
	# swing, so the zone's maximum of enemies covers every impact.
	if _zone.data != null:
		_impact_pool.prewarm(_zone.data.enemy_count_max)
	_hud.attack_held_changed.connect(_robot.player_input.set_attack_button_held)
	_combat_feedback.bind(_robot, _camera_rig, _hud)
	_debug_hud.bind(_robot)


## Creates every zombie the zone can hold before the game starts, so none is
## instantiated mid-game, and places the ones of this visit.
func _spawn_enemies() -> void:
	if _zone.data != null:
		_zombie_pool.prewarm(_zone.data.enemy_count_max)
	_zone.spawn_enemies(GameManager.get_world_seed(), _get_visit(), _zombie_pool)


## Thrown items and enemy loot become dropped items of the loaded zone.
func _wire_dropped_items() -> void:
	if _zone.data == null:
		return
	# One drop per zombie, one throw per inventory slot and one death, so none
	# is created mid-game; the pool makes more if a session needs them.
	_dropped_item_pool.prewarm(_zone.data.enemy_count_max + _robot.inventory.get_slot_count() + 1)
	_dropped_items.time_service = GameManager.get_time_service()
	_dropped_items.bind_zone(_zone.data.zone_id, _zone)
	# Nothing can be on the ground yet; the loader of spec 009 keeps this call
	# when it brings a zone back with its dropped items (R-008-23).
	_dropped_items.discard_expired_now()
	_robot.throw_requested.connect(_on_throw_requested)
	_zone.enemy_loot_dropped.connect(_on_enemy_loot_dropped)


func _wire_death() -> void:
	_death_controller.ruleset = GameManager.get_ruleset()
	_death_controller.bind(_robot)
	GameManager.zone_visit_changed.connect(_on_zone_visit_changed)
	EventBus.player_died.connect(_on_player_died)
	_transfer_screen.finished.connect(_on_transfer_finished)


## Visit number of the loaded zone; FIRST_VISIT without zone data.
func _get_visit() -> int:
	if _zone.data == null:
		return ZonePopulation.FIRST_VISIT
	return GameManager.get_visit_count(_zone.data.zone_id)


func _on_joystick_sample_changed(sample: JoystickLogic.Sample) -> void:
	_robot.player_input.set_joystick_sample(sample)


func _on_joystick_released() -> void:
	_robot.player_input.clear_joystick()


## Opens the loot screen on the box and the opener's inventory (R-005-16).
func _on_box_opened(box: LootBox, opener: Node3D) -> void:
	var inventory: InventoryComponent = InventoryComponent.find_in(opener)
	if inventory == null:
		push_error(
			"Main: '%s' opened the box '%s' but has no InventoryComponent." % [opener.name, box.name]
		)
		return
	# Only the local player's screens: in co-op another robot opening a box
	# must not open a screen on this client (architecture §9.5).
	if opener != _robot:
		return
	_ui_manager.open(
		LootScreen.SCREEN_ID,
		{LootScreen.CONTEXT_SOURCE: box.get_contents(), LootScreen.CONTEXT_INVENTORY: inventory}
	)


## Storage closes whatever screen is on top, or opens the inventory (R-005-24).
func _on_storage_pressed() -> void:
	if _robot.battery.is_depleted():
		return
	if _ui_manager.is_modal_open():
		_ui_manager.close_top()
		return
	_ui_manager.open(
		InventoryScreen.SCREEN_ID,
		{
			InventoryScreen.CONTEXT_INVENTORY: _robot.inventory,
			InventoryScreen.CONTEXT_THROWER: _robot,
		}
	)


## The thrown quantity falls at the robot's feet (R-008-39). The selector
## never asks for an invalid quantity; if one arrives it is a bug.
func _on_throw_requested(player: Robot, slot_index: int, quantity: int) -> void:
	var result: ActionResult = _dropped_items.drop_from_slot(
		player.inventory, slot_index, quantity, player.global_position
	)
	if not result.ok:
		push_error(
			"Main: could not throw %d of slot %d (%s)." % [quantity, slot_index, result.error_key]
		)


func _on_enemy_loot_dropped(stacks: Array[ItemStack], world_position: Vector3) -> void:
	_dropped_items.drop_stacks(stacks, world_position)


## A new visit of the loaded zone: new enemies and closed boxes (R-008-09).
func _on_zone_visit_changed(zone_id: Vector2i, visit: int) -> void:
	if _zone.data == null or zone_id != _zone.data.zone_id:
		return
	# Deferred: the signal arrives in the middle of a physics step (a death),
	# and repopulating takes bodies out of the tree.
	_repopulate_zone.call_deferred(visit)


func _repopulate_zone(visit: int) -> void:
	_zone.repopulate(GameManager.get_world_seed(), visit, _zombie_pool)
	# Before anyone can interact again (R-008-23).
	_dropped_items.discard_expired_now()


## The local player died: nothing but the transfer screen until it ends
## (R-008-29). In co-op another robot's death shows nothing on this client.
func _on_player_died(player_uid: String) -> void:
	if player_uid != _robot.player_uid:
		return
	# close_all() unblocks the input through modal_state_changed, so the block
	# goes after it.
	_ui_manager.close_all()
	_robot.player_input.set_input_blocked(true)
	# The screen swallows the release of a finger that was down, so the stick
	# and the attack button are let go here.
	_touch_controls.joystick.cancel()
	_robot.player_input.set_attack_button_held(false)
	_transfer_screen.play()
	# Deferred: the signal arrives in the middle of the robot's physics frame,
	# and disabling World there removes its body from the physics space while
	# it is still moving. It runs after the repopulation queued by the death.
	_set_world_frozen.call_deferred(true)


## The one place that decides where a dead robot comes back: the zone's spawn
## point until the base exists (spec 009 changes it to travelling there).
func _on_transfer_finished() -> void:
	# A rejected respawn is a bug already reported: the game stays stopped
	# instead of running with a dead robot.
	if not _death_controller.respawn(_robot, _zone.get_spawn_position()):
		return
	_set_world_frozen(false)
	_robot.player_input.set_input_blocked(false)


## Disabling World freezes the robot, the zone and the expiry timer without
## pausing the tree.
func _set_world_frozen(frozen: bool) -> void:
	_world.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
