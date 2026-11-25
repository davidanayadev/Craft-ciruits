class_name DroppedItemFlow
extends Node
## Dropped items as containers (spec 015, plan D13), like StructureUseFlow does
## with chests: a dropped item opened by the local player opens the container
## screen on its contents (R-015-45); when that screen closes, the spawner
## releases the item if it was emptied (R-015-50); and if the item leaves while
## its screen is open (it expired), the screen closes (R-015-49). It only opens
## and closes screens: the spawner owns the items and the screen moves stacks.

@export var ui_manager: UIManager
@export var dropped_items: DroppedItemSpawner

var _player: Robot = null
## The item whose screen is open, and that screen; null when none.
var _open_item: DroppedItem = null
var _open_screen: UIScreen = null


## Hooks the flow to the local player.
func bind(player: Robot) -> void:
	_player = player
	dropped_items.item_opened.connect(_on_item_opened)
	dropped_items.item_removed.connect(_on_item_removed)


## Only the local player's screens (architecture §9.5).
func _on_item_opened(item: DroppedItem, opener: Node3D) -> void:
	if opener != _player or _open_screen != null:
		return
	var screen: UIScreen = ui_manager.open(
		ContainerScreen.SCREEN_ID,
		{
			ContainerScreen.CONTEXT_CONTAINER: item.get_contents(),
			ContainerScreen.CONTEXT_INVENTORY: _player.inventory,
			ContainerScreen.CONTEXT_KIND: ContainerScreen.Kind.DROPPED,
		}
	)
	if screen == null:
		return
	_open_item = item
	_open_screen = screen
	screen.closed.connect(_on_screen_closed, CONNECT_ONE_SHOT)


## Any path that closes the screen: back, a tap outside, a travel, a death or
## the item expiring. An item that already left is not released again: the
## spawner checks it (plan 015 D13).
func _on_screen_closed() -> void:
	var item: DroppedItem = _open_item
	_open_item = null
	_open_screen = null
	dropped_items.release_if_empty(item)


## The open item expired or its zone unloaded: its screen goes with it (R-015-49).
func _on_item_removed(item: DroppedItem) -> void:
	if item == _open_item and _open_screen != null:
		ui_manager.close(_open_screen)
