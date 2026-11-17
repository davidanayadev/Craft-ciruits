class_name SaveFlow
extends Node
## The scene side of the save (spec 010, plan D14): starts the game from the
## Profile and the World, holds the saves while the state is in a transition
## (a travel, the death of the local player, R-010-43), shows the save notices
## in the HUD and handles "New world" of the debug HUD. SaveManager decides
## and writes; this node only wires the scene to it.

@export var ui_manager: UIManager

var _robot: Robot = null
var _zone_loader: ZoneLoader = null
var _blocked: bool = false


## Connects the notices to the HUD first (a damaged file is reported while
## loading), loads the Profile (the robot takes its uuid, R-010-14) and the
## World. False when a newer file blocks the game (R-010-55): the NoticeScreen
## is open and nothing else may start.
func start(robot: Robot, hud: Hud, debug_hud: DebugHud, zone_loader: ZoneLoader) -> bool:
	_robot = robot
	_zone_loader = zone_loader
	SaveManager.save_notice.connect(hud.show_notice)
	var profile: ActionResult = SaveManager.load_profile()
	if _blocks(profile):
		return false
	robot.set_player_uid(SaveManager.get_player_uuid())
	if _blocks(SaveManager.load_game()):
		return false
	debug_hud.show_world_seed(GameManager.get_world_seed())
	debug_hud.new_world_requested.connect(_on_new_world_requested)
	zone_loader.travel_started.connect(_on_travel_started)
	zone_loader.travel_finished.connect(_on_travel_ended)
	zone_loader.travel_failed.connect(_on_travel_ended)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	return true


func is_game_blocked() -> bool:
	return _blocked


## The death hold, for the branch where a respawn was rejected (a bug already
## reported): the robot without battery is saved rather than nothing at all.
func release_death_hold() -> void:
	SaveManager.release_saves(PlayerInput.REASON_DEATH)


func _exit_tree() -> void:
	SaveManager.release_saves(PlayerInput.REASON_TRAVEL)
	SaveManager.release_saves(PlayerInput.REASON_DEATH)


## Only a newer file stops the game; any other failure was already reported
## and the game goes on.
func _blocks(result: ActionResult) -> bool:
	if result.ok or result.error_key != SaveManager.MSG_SAVE_NEWER_VERSION:
		return false
	_blocked = true
	ui_manager.open(NoticeScreen.SCREEN_ID, {NoticeScreen.CONTEXT_MESSAGE: result.error_key})
	return true


func _on_travel_started(_zone_id: Vector2i) -> void:
	SaveManager.hold_saves(PlayerInput.REASON_TRAVEL)


func _on_travel_ended(_zone_id: Vector2i) -> void:
	SaveManager.release_saves(PlayerInput.REASON_TRAVEL)


func _on_player_died(player_uid: String) -> void:
	if player_uid == _robot.player_uid:
		SaveManager.hold_saves(PlayerInput.REASON_DEATH)


func _on_player_respawned(player_uid: String) -> void:
	if player_uid == _robot.player_uid:
		SaveManager.release_saves(PlayerInput.REASON_DEATH)


## The World and its backup go; the scene starts again and creates a new one
## (plan D12). Ignored during a travel.
func _on_new_world_requested() -> void:
	if _zone_loader.is_travelling():
		return
	if SaveManager.delete_save().ok:
		get_tree().reload_current_scene()
