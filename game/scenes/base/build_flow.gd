class_name BuildFlow
extends Node
## Building and editing in the base (spec 009): the repair bench opens the
## build screen for the local player, a picked recipe opens the placement
## screen, and the HUD "Edit base" button, shown only while the base is
## loaded, opens and closes edit mode. It only opens screens: BaseStructures
## decides and changes the state.

@export var ui_manager: UIManager
@export var base_structures: BaseStructures

var _player: Robot = null
var _hud: Hud = null


## Hooks the flow to the local player and its HUD; zone_loader tells which
## zone is loaded.
func bind(player: Robot, hud: Hud, zone_loader: ZoneLoader) -> void:
	_player = player
	_hud = hud
	player.build_requested.connect(_on_build_requested)
	hud.edit_base_pressed.connect(_on_edit_base_pressed)
	zone_loader.zone_loaded.connect(_on_zone_loaded)


func _on_zone_loaded(zone: Zone) -> void:
	var base: BaseZone = zone as BaseZone
	_hud.set_edit_base_available(base != null)
	if base != null and not base.bench_used.is_connected(_on_bench_used):
		base.bench_used.connect(_on_bench_used)


## Only the local player's screens (architecture §9.5).
func _on_bench_used(user: Node3D) -> void:
	if user != _player:
		return
	ui_manager.open(
		BuildScreen.SCREEN_ID,
		{BuildScreen.CONTEXT_PLAYER: _player, BuildScreen.CONTEXT_BASE: base_structures}
	)


## Nothing is charged until the structure is placed (R-009-65).
func _on_build_requested(player: Robot, recipe: RecipeData) -> void:
	if player != _player or not base_structures.is_bound() or ui_manager.is_modal_open():
		return
	ui_manager.open(
		PlacementScreen.SCREEN_ID,
		{
			PlacementScreen.CONTEXT_PLAYER: _player,
			PlacementScreen.CONTEXT_BASE: base_structures,
			PlacementScreen.CONTEXT_RECIPE: recipe,
		}
	)


## Pressed again it leaves edit mode. With another screen open it does
## nothing: placement is never stacked on another screen.
func _on_edit_base_pressed() -> void:
	if ui_manager.is_open(PlacementScreen.SCREEN_ID):
		ui_manager.close_top()
		return
	if ui_manager.is_modal_open() or not base_structures.is_bound() or _player.battery.is_depleted():
		return
	ui_manager.open(
		PlacementScreen.SCREEN_ID,
		{PlacementScreen.CONTEXT_PLAYER: _player, PlacementScreen.CONTEXT_BASE: base_structures}
	)
