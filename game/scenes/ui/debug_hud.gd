class_name DebugHud
extends CanvasLayer
## Debug-build-only overlay: shows FPS to measure the mobile budget on a real
## device (constitution P12) and the XP of the player it is bound to, until
## the game HUD shows it (spec 007, R-007-22). Never visible in release builds,
## so its text is exempt from i18n (P11 covers player-visible strings).
## "Fill base" (spec 009) places a structure on every free cell of the base,
## through BaseStructures.place and paying like a player, to measure the
## frame rate with the base full (R-009-22).

@onready var _fps_label: Label = %FpsLabel
@onready var _xp_label: Label = %XpLabel
@onready var _refresh: Timer = %Refresh
@onready var _fill_base_button: Button = %FillBaseButton

var _player: Robot = null
var _structures: BaseStructures = null


func _ready() -> void:
	visible = OS.is_debug_build()
	if not visible:
		_refresh.stop()
	_fill_base_button.pressed.connect(fill_base)


## Shows the XP of the given player and follows its changes.
func bind(player: Robot) -> void:
	_player = player
	player.experience.xp_changed.connect(_on_xp_changed)
	_on_xp_changed(player.experience.get_total())


## Where "Fill base" places; without it the button does nothing.
func bind_base_structures(structures: BaseStructures) -> void:
	_structures = structures


## Every free cell gets the first structure recipe of the bench; the player
## is given exactly the cost of each one right before paying it.
func fill_base() -> void:
	if _player == null or _structures == null or not _structures.is_bound():
		return
	var recipe: RecipeData = _first_structure_recipe()
	if recipe == null:
		return
	var area: Vector2i = _structures.grid_config.area_size_cells
	for y: int in area.y:
		for x: int in area.x:
			var cell: Vector2i = Vector2i(x, y)
			if not _structures.can_place(recipe.result_structure, cell):
				continue
			var cost: Dictionary[StringName, int] = CraftingSystem.cost_of(recipe)
			for item_id: StringName in cost:
				_player.inventory.add(item_id, cost[item_id])
			_structures.place(_player, recipe, cell)


func _first_structure_recipe() -> RecipeData:
	for recipe: RecipeData in DataRegistry.get_catalog().get_recipes():
		if recipe.station == RecipeData.Station.WORKBENCH and recipe.result_structure != null:
			return recipe
	return null


func _on_refresh_timeout() -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_xp_changed(total: int) -> void:
	_xp_label.text = "XP: %d" % total
