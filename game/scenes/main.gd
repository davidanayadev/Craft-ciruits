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

@onready var _robot: Robot = %Robot
@onready var _camera_rig: CameraRig = %CameraRig
@onready var _touch_controls: TouchControls = %TouchControls
@onready var _hud: Hud = %Hud
@onready var _ui_manager: UIManager = %UIManager
@onready var _world: Node3D = %World
@onready var _zone: FarmZone = %GreenZone
@onready var _zombie_pool: ObjectPool = %ZombiePool
@onready var _game_over_screen: GameOverScreen = %GameOverScreen
@onready var _impact_pool: ObjectPool = %ImpactPool
@onready var _combat_feedback: CombatFeedback = %CombatFeedback
@onready var _debug_hud: DebugHud = %DebugHud


func _ready() -> void:
	_zone.generate(GameManager.get_world_seed())
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
	_robot.battery.battery_depleted.connect(_on_battery_depleted)
	_game_over_screen.restart_requested.connect(_on_restart_requested)
	_wire_combat()


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
	_zone.spawn_enemies(GameManager.get_world_seed(), ZombieSpawner.FIRST_VISIT, _zombie_pool)


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
		InventoryScreen.SCREEN_ID, {InventoryScreen.CONTEXT_INVENTORY: _robot.inventory}
	)


## Provisional game over (spec 003); spec 008 replaces it with the ruleset and
## the respawn. Disabling World freezes the robot and the zone without pausing
## the tree, so no global state survives the reload.
func _on_battery_depleted() -> void:
	# Deferred: the signal arrives in the middle of the robot's physics frame,
	# and disabling World there removes its body from the physics space while
	# it is still moving.
	_freeze_world.call_deferred()
	_ui_manager.close_all()
	_game_over_screen.open()


func _freeze_world() -> void:
	_world.process_mode = Node.PROCESS_MODE_DISABLED


func _on_restart_requested() -> void:
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("Main: could not reload the scene to restart (error %d)." % error)
