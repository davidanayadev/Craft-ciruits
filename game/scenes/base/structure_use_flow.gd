class_name StructureUseFlow
extends Node
## Chests and generators in the base (spec 012), like BuildFlow does with the
## bench: a chest used by the local player opens the container screen on its
## contents (R-012-27) and, when that screen closes after the contents changed,
## announces chest_closed so the World saves (R-012-44, plan D15); a generator
## used by the local player asks BaseStructures to collect, and an empty one
## shows the time left (R-012-20). It only opens screens and shows notices:
## BaseStructures decides and changes the state.

@export var ui_manager: UIManager
@export var base_structures: BaseStructures

var _player: Robot = null
var _hud: Hud = null
## The chest whose screen is open; "" when none (one container screen at a time).
var _open_chest_uid: String = ""
var _open_chest_contents: InventoryComponent = null
var _open_chest_changed: bool = false


## Hooks the flow to the local player and its HUD.
func bind(player: Robot, hud: Hud) -> void:
	_player = player
	_hud = hud
	base_structures.structure_used.connect(_on_structure_used)


## Only the local player's screens and notices (architecture §9.5).
func _on_structure_used(structure_uid: String, user: Node3D) -> void:
	if user != _player:
		return
	var contents: InventoryComponent = base_structures.get_chest_contents(structure_uid)
	if contents != null:
		_open_chest(structure_uid, contents)
	else:
		_collect(structure_uid)


func _open_chest(structure_uid: String, contents: InventoryComponent) -> void:
	var screen: UIScreen = ui_manager.open(
		ContainerScreen.SCREEN_ID,
		{
			ContainerScreen.CONTEXT_CONTAINER: contents,
			ContainerScreen.CONTEXT_INVENTORY: _player.inventory,
			ContainerScreen.CONTEXT_KIND: ContainerScreen.Kind.CHEST,
		}
	)
	if screen == null:
		return
	_open_chest_uid = structure_uid
	_open_chest_contents = contents
	_open_chest_changed = false
	contents.inventory_changed.connect(_on_open_chest_changed)
	screen.closed.connect(_on_chest_screen_closed, CONNECT_ONE_SHOT)


func _on_open_chest_changed() -> void:
	_open_chest_changed = true


## Also when a travel or a death closes every screen: the save then waits for
## SaveManager to release its hold (plan D15).
func _on_chest_screen_closed() -> void:
	_open_chest_contents.inventory_changed.disconnect(_on_open_chest_changed)
	if _open_chest_changed:
		EventBus.chest_closed.emit(_open_chest_uid, _player.player_uid)
	_open_chest_uid = ""
	_open_chest_contents = null
	_open_chest_changed = false


## A full inventory already shows its notice through overflowed (R-005-20).
func _collect(structure_uid: String) -> void:
	var result: ActionResult = base_structures.collect_batteries(_player, structure_uid)
	if result.error_key == WindGeneratorComponent.MSG_GENERATOR_EMPTY:
		var time_left: int = base_structures.seconds_to_next_battery(structure_uid)
		_hud.show_notice(result.error_key, [WindGenerator.format_time_left(time_left)])
