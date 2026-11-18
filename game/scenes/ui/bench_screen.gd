class_name BenchScreen
extends UIScreen
## The repair bench screen (spec 011, R-011-21): tabs Build, Craft and Repair,
## opening on Build. It replaces the build screen of spec 009, whose logic is
## now BenchBuildSection. Picking a structure closes it and asks the player to
## build (R-009-65); crafting and repairing keep it open (R-011-26). Every
## section follows the player's inventory_changed, never _process (R-011-25).

enum Tab { BUILD, CRAFT, REPAIR }

const SCREEN_ID := &"bench"
## The Robot that uses the bench.
const CONTEXT_PLAYER := &"player"
## The BaseStructures of the world.
const CONTEXT_BASE := &"base"
## The RepairBench that crafts and repairs.
const CONTEXT_BENCH := &"bench"
## Same order as Tab.
const TAB_TITLE_KEYS: Array[StringName] = [&"BUILD_TITLE", &"CRAFT_TITLE", &"REPAIR_TITLE"]

var _player: Robot = null

@onready var _tabs: TabContainer = %Tabs
@onready var _build: BenchBuildSection = %BuildSection
@onready var _craft: BenchCraftSection = %CraftSection
@onready var _repair: BenchRepairSection = %RepairSection


## Missing or wrong context → push_error, no entries. Connects the player's
## inventory_changed.
func setup(context: Dictionary) -> void:
	_set_tab_titles()
	var player: Robot = context.get(CONTEXT_PLAYER) as Robot
	var structures: BaseStructures = context.get(CONTEXT_BASE) as BaseStructures
	var bench: RepairBench = context.get(CONTEXT_BENCH) as RepairBench
	if player == null or structures == null or bench == null:
		push_error(
			"BenchScreen: the context needs '%s', '%s' and '%s'."
			% [CONTEXT_PLAYER, CONTEXT_BASE, CONTEXT_BENCH]
		)
		return
	_player = player
	_build.setup(player, structures)
	_craft.setup(player, bench)
	_repair.setup(player, bench, DataRegistry.get_catalog().repair_costs)
	_build.build_picked.connect(_on_build_picked)
	player.inventory.inventory_changed.connect(_on_inventory_changed)
	show_tab(Tab.BUILD)


func get_current_tab() -> Tab:
	return _tabs.current_tab as Tab


func show_tab(tab: Tab) -> void:
	_tabs.current_tab = tab


func on_closed() -> void:
	if _player != null and _player.inventory.inventory_changed.is_connected(_on_inventory_changed):
		_player.inventory.inventory_changed.disconnect(_on_inventory_changed)


## Translated here rather than trusting TabBar to translate its titles (plan 011 D10).
func _set_tab_titles() -> void:
	for i: int in TAB_TITLE_KEYS.size():
		_tabs.set_tab_title(i, tr(TAB_TITLE_KEYS[i]))


func _on_inventory_changed() -> void:
	_build.refresh()
	_craft.refresh()
	_repair.refresh()


## Closed first, so the placement screen is not stacked on this one.
func _on_build_picked(recipe: RecipeData) -> void:
	close_requested.emit()
	_player.request_build(recipe)
