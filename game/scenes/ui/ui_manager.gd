class_name UIManager
extends Control
## Stack of pop-up screens (architecture §9.5). Screens are opened by id from
## the catalog and added on top as children. The pause action (Escape) and the
## Android back request go to the top one, which handles them itself
## (UIScreen.handle_back, spec 009) or is closed; a tap outside the top
## screen's panel takes the same path (spec 012). It never pauses the tree: whoever
## listens to modal_state_changed decides what a screen blocks.

## Only when going from no screen to some, and back.
signal modal_state_changed(is_open: bool)

@export var catalog: UIScreenCatalog

## Bottom first; _screen_ids runs in parallel.
var _screens: Array[UIScreen] = []
var _screen_ids: Array[StringName] = []


func _unhandled_input(event: InputEvent) -> void:
	if is_modal_open() and event.is_action_pressed(&"pause"):
		_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_modal_open():
		_back()


## The screen it opened (spec 012, plan D15); unknown id or id already open →
## push_error, no change, null.
func open(screen_id: StringName, context: Dictionary = {}) -> UIScreen:
	if _screen_ids.has(screen_id):
		push_error("UIManager: screen '%s' is already open." % screen_id)
		return null
	var screen: UIScreen = _instantiate(screen_id)
	if screen == null:
		return null
	add_child(screen)
	_screens.append(screen)
	_screen_ids.append(screen_id)
	screen.close_requested.connect(_close.bind(screen))
	screen.back_requested.connect(_on_back_requested.bind(screen))
	if _screens.size() == 1:
		modal_state_changed.emit(true)
	screen.setup(context)
	return screen


## Closes that screen wherever it is in the stack, as Escape would on top
## (spec 015, plan D13). Not open → nothing.
func close(screen: UIScreen) -> void:
	_close(screen)


## Nothing open → no-op.
func close_top() -> void:
	if not _screens.is_empty():
		_close(_screens[_screens.size() - 1])


func close_all() -> void:
	if _screens.is_empty():
		return
	for index: int in range(_screens.size() - 1, -1, -1):
		_remove_at(index)
	modal_state_changed.emit(false)


func is_modal_open() -> bool:
	return not _screens.is_empty()


func is_open(screen_id: StringName) -> bool:
	return _screen_ids.has(screen_id)


## The top screen handles "back" itself or is closed.
func _back() -> void:
	var top: UIScreen = _screens[_screens.size() - 1]
	if not top.handle_back():
		_close(top)


## A tap outside the panel is "back", the same path as Escape, and only for
## the screen on top (R-012-46).
func _on_back_requested(screen: UIScreen) -> void:
	if not _screens.is_empty() and _screens[_screens.size() - 1] == screen:
		_back()


func _instantiate(screen_id: StringName) -> UIScreen:
	if catalog == null or not catalog.screens.has(screen_id):
		push_error("UIManager: unknown screen id '%s'." % screen_id)
		return null
	var scene: PackedScene = catalog.screens[screen_id]
	var node: Node = scene.instantiate() if scene != null else null
	var screen: UIScreen = node as UIScreen
	if screen == null:
		push_error("UIManager: the scene of screen '%s' is not a UIScreen." % screen_id)
		if node != null:
			node.free()
	return screen


func _close(screen: UIScreen) -> void:
	var index: int = _screens.find(screen)
	if index == -1:
		return
	_remove_at(index)
	if _screens.is_empty():
		modal_state_changed.emit(false)


## Out of the stack at once, so is_modal_open() is already right; freed later
## because the request may arrive in the middle of a signal of that screen.
func _remove_at(index: int) -> void:
	var screen: UIScreen = _screens[index]
	_screens.remove_at(index)
	_screen_ids.remove_at(index)
	screen.on_closed()
	screen.closed.emit()
	screen.queue_free()
