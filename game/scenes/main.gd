extends Node
## Main scene boot (architecture §6): wires the persistent skeleton together
## (robot <-> camera rig; UI input joins in as the HUD grows). References go
## through unique names, never deep hardcoded paths (P6).
## Zones (spec 009): ZoneLoader keeps one zone in ZoneSlot. The game starts by
## travelling to the base; while a travel runs Main shows the loading screen,
## freezes World and blocks the robot's input. The signals of each zone are
## wired when it loads.
## It also opens the screens (spec 005): the container screen (spec 012) when the local robot
## opens a box and the inventory on the storage button, and blocks the robot's
## input while one is open. UIManager sits before Hud in UI, so the HUD is
## drawn on top of the screens.
## The pools live under World and not in the zone, so they outlive it and are
## reused between visits (spec 006); ZoneLoader prewarms them.
## Combat (spec 007): the HUD attack button feeds the robot's input, and the
## feedback and the debug XP are bound to the local robot.
## Death (spec 008): DeathController applies the ruleset; Main shows the
## transfer screen, freezes World meanwhile and, when it ends, travels to the
## base and brings the robot back there (spec 009). Thrown items and enemy loot
## become dropped items, which live under World and outside the zone.
## Building (spec 009) is BuildFlow's: bench, build screen, placement and the
## "Edit base" button. Chests and generators (spec 012) are StructureUseFlow's,
## and the generators' maximum battery bonus reaches the robot from here.
## The save (spec 010) is SaveFlow's: it loads the Profile and the World before
## anything starts; Main then gives the death controller the World's ruleset
## and travels to the saved location, or to the base. A save of a newer
## version blocks the game: World stays frozen and nothing travels.

@onready var _robot: Robot = %Robot
@onready var _camera_rig: CameraRig = %CameraRig
@onready var _touch_controls: TouchControls = %TouchControls
@onready var _hud: Hud = %Hud
@onready var _ui_manager: UIManager = %UIManager
@onready var _world: Node3D = %World
@onready var _zone_loader: ZoneLoader = %ZoneLoader
@onready var _dropped_items: DroppedItemSpawner = %DroppedItems
@onready var _death_controller: DeathController = %DeathController
@onready var _transfer_screen: TransferScreen = %TransferScreen
@onready var _loading_screen: LoadingScreen = %LoadingScreen
@onready var _combat_feedback: CombatFeedback = %CombatFeedback
@onready var _debug_hud: DebugHud = %DebugHud
@onready var _build_flow: BuildFlow = %BuildFlow
@onready var _base_structures: BaseStructures = %BaseStructures
@onready var _save_flow: SaveFlow = %SaveFlow
@onready var _structure_use_flow: StructureUseFlow = %StructureUseFlow

## The transfer ended and the robot comes back when the travel to the base ends.
var _respawn_pending: bool = false
## A death and a travel freeze World each for their own reason (the same names
## as PlayerInput's); it runs again only when no reason is left.
var _freeze_reasons: Dictionary[StringName, bool] = {}


func _ready() -> void:
	_robot.camera_rig = _camera_rig
	_camera_rig.target = _robot
	_hud.bind(_robot)
	_hud.interact_pressed.connect(_robot.request_interact)
	_hud.storage_pressed.connect(_on_storage_pressed)
	_ui_manager.modal_state_changed.connect(
		_robot.player_input.set_input_blocked.bind(PlayerInput.REASON_SCREEN)
	)
	_touch_controls.joystick.sample_changed.connect(_on_joystick_sample_changed)
	_touch_controls.joystick.released.connect(_on_joystick_released)
	_hud.attack_held_changed.connect(_robot.player_input.set_attack_button_held)
	_combat_feedback.bind(_robot, _camera_rig, _hud)
	_debug_hud.bind(_robot)
	_debug_hud.bind_base_structures(_base_structures)
	_build_flow.bind(_robot, _hud, _zone_loader)
	_structure_use_flow.bind(_robot, _hud)
	_wire_battery_bonus()
	_dropped_items.time_service = GameManager.get_time_service()
	_robot.throw_requested.connect(_on_throw_requested)
	if not _save_flow.start(_robot, _hud, _debug_hud, _zone_loader):
		_set_world_frozen(true, PlayerInput.REASON_SCREEN)
		return
	_wire_death()
	_wire_travel()
	_travel_to_start()


## The saved zone and position of the local player (R-010-34), or the base's
## spawn point for a new World (R-009-08, R-010-19) or a location that cannot
## be used (R-010-36).
func _travel_to_start() -> void:
	var location: LocationComponent = _robot.location
	var base_id: Vector2i = DataRegistry.get_base_zone().zone_id
	if not location.has_restored_location():
		_zone_loader.travel_to(base_id)
		return
	var zone_id: Vector2i = location.get_restored_zone_id()
	var local_position: Vector3 = location.get_restored_local_position()
	var catalog: DataCatalog = DataRegistry.get_catalog()
	if not catalog.has_zone(zone_id) or not catalog.get_zone(zone_id).contains_local_position(local_position):
		push_error("Main: the saved location %s %s cannot be used; starting in the base." % [zone_id, local_position])
		_zone_loader.travel_to(base_id)
		return
	_zone_loader.travel_to_position(zone_id, local_position)


## Before the World loads, so the robot's saved charge is accepted up to the
## maximum with the generator's bonus (spec 012, plan D9, R-012-14). In co-op
## each robot connects when it joins (v2.0).
func _wire_battery_bonus() -> void:
	_base_structures.max_battery_bonus_changed.connect(_robot.battery.set_maximum_bonus)
	_robot.battery.set_maximum_bonus(_base_structures.get_max_battery_bonus())


## After the World is loaded: its ruleset decides the deaths (R-010-20).
func _wire_death() -> void:
	_death_controller.ruleset = GameManager.get_ruleset()
	_death_controller.bind(_robot)
	EventBus.player_died.connect(_on_player_died)
	_transfer_screen.finished.connect(_on_transfer_finished)


func _wire_travel() -> void:
	_zone_loader.travel_started.connect(_on_travel_started)
	_zone_loader.zone_loaded.connect(_on_zone_loaded)
	_zone_loader.travel_finished.connect(_on_travel_finished)
	_zone_loader.travel_failed.connect(_on_travel_failed)


func _on_joystick_sample_changed(sample: JoystickLogic.Sample) -> void:
	_robot.player_input.set_joystick_sample(sample)


func _on_joystick_released() -> void:
	_robot.player_input.clear_joystick()


## Nothing but the loading screen until the travel ends (R-009-07).
func _on_travel_started(_zone_id: Vector2i) -> void:
	_ui_manager.close_all()
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_TRAVEL)
	_release_touch_input()
	_combat_feedback.release_all()
	_loading_screen.show_loading()
	# Deferred: an exit request arrives in the middle of the robot's physics step.
	_set_world_frozen.call_deferred(true, PlayerInput.REASON_TRAVEL)


## The signals of the zone that just loaded; they go away with it.
func _on_zone_loaded(zone: Zone) -> void:
	var farm: FarmZone = zone as FarmZone
	if farm != null:
		farm.box_opened.connect(_on_box_opened)
		farm.enemy_loot_dropped.connect(_on_enemy_loot_dropped)


## A respawn waits for the base: if this travel went elsewhere (the robot died
## in the very step it used an exit), it goes on to the base.
func _on_travel_finished(_zone_id: Vector2i) -> void:
	_end_travel()
	if not _respawn_pending:
		return
	if _zone_loader.get_current_zone() is BaseZone:
		_respawn_at(_zone_loader.get_current_zone())
	else:
		_travel_to_base_for_respawn()


## A failed respawn travel brings the robot back where it is, as in spec 008:
## the failure is already reported and the game does not stay stopped.
func _on_travel_failed(_zone_id: Vector2i) -> void:
	_end_travel()
	if _respawn_pending:
		_respawn_at(_zone_loader.get_current_zone())


## A death still keeps World frozen and the input blocked for its own reason.
func _end_travel() -> void:
	_loading_screen.hide_loading()
	_set_world_frozen(false, PlayerInput.REASON_TRAVEL)
	_robot.player_input.set_input_blocked(false, PlayerInput.REASON_TRAVEL)


## Opens the container screen on the box and the opener's inventory (R-012-37).
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
		ContainerScreen.SCREEN_ID,
		{
			ContainerScreen.CONTEXT_CONTAINER: box.get_contents(),
			ContainerScreen.CONTEXT_INVENTORY: inventory,
			ContainerScreen.CONTEXT_TITLE: ContainerScreen.LOOT_TITLE_KEY,
		}
	)


## Storage closes whatever screen is on top, or opens the inventory (R-005-24).
func _on_storage_pressed() -> void:
	if _robot.battery.is_depleted() or _zone_loader.is_travelling() or _save_flow.is_game_blocked():
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


## The local player died: nothing but the transfer screen until it ends
## (R-008-29). In co-op another robot's death shows nothing on this client.
func _on_player_died(player_uid: String) -> void:
	if player_uid != _robot.player_uid:
		return
	_ui_manager.close_all()
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_DEATH)
	_release_touch_input()
	_transfer_screen.play()
	# Deferred: the signal arrives in the middle of the robot's physics frame,
	# and disabling World there removes its body from the physics space while
	# it is still moving. It runs after the repopulation queued by the death.
	_set_world_frozen.call_deferred(true, PlayerInput.REASON_DEATH)


## The one place that decides where a dead robot comes back: the base's spawn
## point, through a travel (R-009-51), also when it died inside the base
## (R-009-52). The robot respawns when that travel ends. A travel already
## running (an exit used in the step of the death) is waited for.
func _on_transfer_finished() -> void:
	_respawn_pending = true
	if not _zone_loader.is_travelling():
		_travel_to_base_for_respawn()


## A refused travel is a bug already reported: the robot comes back where it is.
func _travel_to_base_for_respawn() -> void:
	if not _zone_loader.travel_to(DataRegistry.get_base_zone().zone_id).ok:
		_respawn_at(_zone_loader.get_current_zone())


func _respawn_at(zone: Zone) -> void:
	_respawn_pending = false
	# A rejected respawn is a bug already reported: the game stays stopped
	# instead of running with a dead robot, and the save is let go.
	if zone == null or not _death_controller.respawn(_robot, zone.get_spawn_position()):
		_save_flow.release_death_hold()
		return
	_set_world_frozen(false, PlayerInput.REASON_DEATH)
	_robot.player_input.set_input_blocked(false, PlayerInput.REASON_DEATH)


## The screens swallow the release of a finger that was down, so the stick and
## the attack button are let go here.
func _release_touch_input() -> void:
	_touch_controls.joystick.cancel()
	_robot.player_input.set_attack_button_held(false)


## Disabling World freezes the robot, the zone and the expiry timer without
## pausing the tree. Frozen while any reason is active.
func _set_world_frozen(frozen: bool, reason: StringName) -> void:
	if frozen:
		_freeze_reasons[reason] = true
	else:
		_freeze_reasons.erase(reason)
	var any_reason: bool = not _freeze_reasons.is_empty()
	_world.process_mode = Node.PROCESS_MODE_DISABLED if any_reason else Node.PROCESS_MODE_INHERIT
