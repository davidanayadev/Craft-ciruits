extends GutTest
## UIManager (spec 005, architecture §9.5): a stack of screens opened by id
## from a UIScreenCatalog. modal_state_changed only on none <-> some
## (R-005-27), the pause action and the Android back request close the top
## screen (R-005-28), and a screen that emits close_requested is closed.
## Spec 009: the top screen may keep itself open on "back" (handle_back) and
## every closing path calls on_closed once (R-009-56); is_open() by id.
## The screens are probes packed in memory: the real ones have their own tests.

const UI_MANAGER_SCENE := preload("res://scenes/ui/ui_manager.tscn")
const SCREENS_PATH := "res://resources/ui/screens.tres"
const SCREEN_A := &"probe_a"
const SCREEN_B := &"probe_b"
const SCREEN_SELF_CLOSING := &"self_closing"
const INPUT_FRAMES := 2


class ProbeScreen:
	extends UIScreen

	var context: Dictionary = {}
	var setup_calls: int = 0
	var was_in_tree_at_setup: bool = false
	var keeps_on_back: bool = false
	var back_calls: int = 0
	var closed_calls: int = 0

	func setup(p_context: Dictionary) -> void:
		context = p_context
		setup_calls += 1
		was_in_tree_at_setup = is_inside_tree()

	func handle_back() -> bool:
		back_calls += 1
		return keeps_on_back

	func on_closed() -> void:
		closed_calls += 1


## Asks to be closed as soon as it is set up, like the loot screen of an empty box.
class SelfClosingScreen:
	extends UIScreen

	func setup(_context: Dictionary) -> void:
		close_requested.emit()


class PauseProbe:
	extends Node

	var pauses: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause"):
			pauses += 1


var _pause_probe: PauseProbe
var _manager: UIManager


func before_each() -> void:
	# Added before the manager: _unhandled_input runs from the last node of the
	# tree to the first, so the probe only sees what the manager did not consume.
	_pause_probe = PauseProbe.new()
	add_child_autofree(_pause_probe)
	_manager = UI_MANAGER_SCENE.instantiate() as UIManager
	_manager.catalog = _new_catalog()
	add_child_autofree(_manager)
	watch_signals(_manager)


func after_each() -> void:
	_send_action(&"pause", false)


func _new_probe_scene(screen: UIScreen = ProbeScreen.new()) -> PackedScene:
	var scene: PackedScene = PackedScene.new()
	var error: Error = scene.pack(screen)
	screen.free()
	assert_eq(error, OK, "test setup: the probe screen packs")
	return scene


func _new_catalog() -> UIScreenCatalog:
	var catalog: UIScreenCatalog = UIScreenCatalog.new()
	catalog.screens[SCREEN_A] = _new_probe_scene()
	catalog.screens[SCREEN_B] = _new_probe_scene()
	catalog.screens[SCREEN_SELF_CLOSING] = _new_probe_scene(SelfClosingScreen.new())
	return catalog


## Screens still open, bottom first.
func _open_screens() -> Array[ProbeScreen]:
	var screens: Array[ProbeScreen] = []
	for child: Node in _manager.get_children():
		var screen: ProbeScreen = child as ProbeScreen
		if screen != null and not screen.is_queued_for_deletion():
			screens.append(screen)
	return screens


func _send_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func test_open_instantiates_screen_and_calls_setup() -> void:
	assert_false(_manager.is_modal_open(), "nothing open at the start")
	var context: Dictionary = {&"answer": 42}
	_manager.open(SCREEN_A, context)
	assert_true(_manager.is_modal_open(), "a screen is open")
	var screens: Array[ProbeScreen] = _open_screens()
	assert_eq(screens.size(), 1, "the screen is a child of the manager")
	if screens.size() != 1:
		return
	assert_eq(screens[0].setup_calls, 1, "setup() is called once")
	assert_true(screens[0].was_in_tree_at_setup, "after the screen entered the tree")
	assert_eq(screens[0].context, context, "with the context given to open()")


func test_open_unknown_id_reports_error() -> void:
	_manager.open(&"no_such_screen")
	assert_push_error("no_such_screen")
	assert_false(_manager.is_modal_open(), "nothing was opened")
	assert_signal_not_emitted(_manager, "modal_state_changed")


func test_open_same_id_twice_reports_error() -> void:
	_manager.open(SCREEN_A)
	_manager.open(SCREEN_A)
	assert_push_error(String(SCREEN_A))
	assert_eq(_open_screens().size(), 1, "the screen is open only once")


func test_new_screen_goes_on_top() -> void:
	_manager.open(SCREEN_A)
	_manager.open(SCREEN_B)
	var screens: Array[ProbeScreen] = _open_screens()
	assert_eq(screens.size(), 2, "both screens are open")
	_manager.close_top()
	assert_eq(_open_screens().size(), 1, "close_top() closes one")
	if screens.size() == 2:
		assert_same(_open_screens()[0], screens[0], "the first one stays: the top one was closed")
		assert_true(screens[1].is_queued_for_deletion(), "the closed screen is freed")


func test_close_top_pops_at_once() -> void:
	_manager.open(SCREEN_A)
	_manager.close_top()
	assert_false(_manager.is_modal_open(), "is_modal_open() changes in the same call")
	_manager.open(SCREEN_A)
	assert_true(_manager.is_modal_open(), "the same id can be opened again right away")


func test_close_top_with_nothing_open_does_nothing() -> void:
	_manager.close_top()
	_manager.close_all()
	assert_false(_manager.is_modal_open())
	assert_signal_not_emitted(_manager, "modal_state_changed")


func test_r_005_27_modal_state_changed_on_transitions() -> void:
	_manager.open(SCREEN_A)
	assert_signal_emit_count(_manager, "modal_state_changed", 1, "none -> some")
	assert_signal_emitted_with_parameters(_manager, "modal_state_changed", [true])
	_manager.open(SCREEN_B)
	assert_signal_emit_count(_manager, "modal_state_changed", 1, "some -> more is no transition")
	_manager.close_top()
	assert_signal_emit_count(_manager, "modal_state_changed", 1, "one still open")
	_manager.close_top()
	assert_signal_emit_count(_manager, "modal_state_changed", 2, "some -> none")
	assert_signal_emitted_with_parameters(_manager, "modal_state_changed", [false])


func test_r_005_27_close_all_emits_once() -> void:
	_manager.open(SCREEN_A)
	_manager.open(SCREEN_B)
	_manager.close_all()
	assert_false(_manager.is_modal_open(), "everything is closed")
	assert_eq(_open_screens().size(), 0, "no screen left")
	assert_signal_emit_count(_manager, "modal_state_changed", 2, "one for opening, one for closing")


func test_r_005_27_screen_closing_in_setup_leaves_no_modal() -> void:
	_manager.open(SCREEN_SELF_CLOSING)
	assert_false(_manager.is_modal_open(), "a screen that closes in setup() is not left open")
	assert_signal_emit_count(_manager, "modal_state_changed", 2, "opened, then closed")
	var last: Array = get_signal_parameters(_manager, "modal_state_changed", 1)
	var is_open: bool = last[0]
	assert_false(is_open, "the last state reported is closed: the input is not left blocked")


func test_r_005_28_pause_closes_top() -> void:
	_manager.open(SCREEN_A)
	_manager.open(SCREEN_B)
	_send_action(&"pause", true)
	await wait_process_frames(INPUT_FRAMES)
	assert_eq(_open_screens().size(), 1, "the pause action closes only the top screen")
	assert_true(_manager.is_modal_open(), "the one below stays open")
	assert_eq(_pause_probe.pauses, 0, "the manager consumed the action")


func test_r_005_28_nothing_open_does_not_consume_pause() -> void:
	_send_action(&"pause", true)
	await wait_process_frames(INPUT_FRAMES)
	assert_eq(_pause_probe.pauses, 1, "with no screen open the action reaches the game")
	assert_signal_not_emitted(_manager, "modal_state_changed")


func test_r_005_28_back_request_closes_top() -> void:
	_manager.open(SCREEN_A)
	_manager.open(SCREEN_B)
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(_open_screens().size(), 1, "back closes only the top screen")
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(_manager.is_modal_open(), "back again closes the last one")
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(_manager.is_modal_open(), "back with nothing open does nothing")


func test_close_requested_closes_that_screen() -> void:
	_manager.open(SCREEN_A)
	_manager.open(SCREEN_B)
	var screens: Array[ProbeScreen] = _open_screens()
	if screens.size() != 2:
		fail_test("test setup: two screens open")
		return
	screens[0].close_requested.emit()
	assert_eq(_open_screens().size(), 1, "one screen was closed")
	assert_same(_open_screens()[0], screens[1], "the one that asked, not the top one")
	assert_true(_manager.is_modal_open(), "the other one is still open")


func test_manager_lets_touches_through() -> void:
	assert_eq(_manager.mouse_filter, Control.MOUSE_FILTER_IGNORE, "with no screen it blocks nothing")
	assert_eq(_manager.anchor_right, 1.0, "full rect")
	assert_eq(_manager.anchor_bottom, 1.0, "full rect")


func test_real_catalog_lists_both_screens() -> void:
	var catalog: UIScreenCatalog = load(SCREENS_PATH) as UIScreenCatalog
	assert_not_null(catalog, "screens.tres exists and is a UIScreenCatalog")
	if catalog == null:
		return
	for screen_id: StringName in [
		InventoryScreen.SCREEN_ID, ContainerScreen.SCREEN_ID, BenchScreen.SCREEN_ID, PlacementScreen.SCREEN_ID
	]:
		assert_true(catalog.screens.has(screen_id), "'%s' is registered" % screen_id)
		if not catalog.screens.has(screen_id):
			continue
		var screen: Node = catalog.screens[screen_id].instantiate()
		assert_true(screen is UIScreen, "'%s' is a UIScreen" % screen_id)
		screen.free()


func test_r_009_56_handle_back_keeps_screen() -> void:
	_manager.open(SCREEN_A)
	var screen: ProbeScreen = _open_screens()[0]
	screen.keeps_on_back = true
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(screen.back_calls, 1, "the top screen was asked")
	assert_true(_manager.is_open(SCREEN_A), "and it stays open")
	_send_action(&"pause", true)
	await wait_process_frames(INPUT_FRAMES)
	assert_eq(screen.back_calls, 2, "Escape asks it too")
	assert_true(_manager.is_open(SCREEN_A), "still open")
	assert_eq(_pause_probe.pauses, 0, "the manager consumed the action")
	screen.keeps_on_back = false
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(_manager.is_open(SCREEN_A), "closed when the screen lets it")


func test_r_009_56_on_closed_called_on_close_all() -> void:
	_manager.open(SCREEN_A)
	_manager.open(SCREEN_B)
	var screens: Array[ProbeScreen] = _open_screens()
	_manager.close_all()
	for screen: ProbeScreen in screens:
		assert_eq(screen.closed_calls, 1, "on_closed once for each screen")


func test_r_009_56_on_closed_called_on_every_path() -> void:
	_manager.open(SCREEN_A)
	var by_request: ProbeScreen = _open_screens()[0]
	by_request.close_requested.emit()
	assert_eq(by_request.closed_calls, 1, "its own request")
	_manager.open(SCREEN_A)
	var by_top: ProbeScreen = _open_screens()[0]
	_manager.close_top()
	assert_eq(by_top.closed_calls, 1, "close_top")
	_manager.open(SCREEN_A)
	var by_back: ProbeScreen = _open_screens()[0]
	_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(by_back.closed_calls, 1, "back")


func test_r_009_59_is_open_by_id() -> void:
	assert_false(_manager.is_open(SCREEN_A), "nothing open")
	_manager.open(SCREEN_A)
	assert_true(_manager.is_open(SCREEN_A), "A is open")
	assert_false(_manager.is_open(SCREEN_B), "B is not")
	_manager.close_top()
	assert_false(_manager.is_open(SCREEN_A), "closed")


# --- Closing by tapping outside (spec 012) ------------------------------------
# R-012-46, R-012-47 and the open()/closed contract of plan D15. Real mouse
# events are pushed to the viewport; the test runner's own panel is hidden
# meanwhile so it does not catch them.

const SCREEN_TAP := &"tap_probe"
const SCREEN_TAP_B := &"tap_probe_b"
const PANEL_RECT := Rect2(Vector2(400, 300), Vector2(300, 200))
const OUTSIDE := Vector2(40, 40)


class MouseProbe:
	extends Node

	var presses: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed:
			presses += 1


## A full-screen probe with one panel that stops the mouse, like the real screens.
func _new_tap_probe_scene(closes_on_outside_tap: bool) -> PackedScene:
	var screen: ProbeScreen = ProbeScreen.new()
	screen.closes_on_outside_tap = closes_on_outside_tap
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	screen.add_child(panel)
	panel.owner = screen
	return _new_probe_scene(screen)


func _with_tap_probes() -> void:
	_manager.catalog.screens[SCREEN_TAP] = _new_tap_probe_scene(true)
	_manager.catalog.screens[SCREEN_TAP_B] = _new_tap_probe_scene(true)


func _tap(viewport_position: Vector2) -> void:
	var runner: CanvasLayer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if runner != null:
		runner.visible = false
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = viewport_position
		event.global_position = viewport_position
		get_viewport().push_input(event, true)
	if runner != null:
		runner.visible = true


func test_r_012_46_open_returns_the_screen() -> void:
	var screen: UIScreen = _manager.open(SCREEN_A)
	assert_not_null(screen, "open() returns the screen it opened")
	assert_same(screen, _open_screens()[0], "that very screen")
	assert_null(_manager.open(SCREEN_A), "already open: null")
	assert_null(_manager.open(&"nope"), "unknown id: null")
	assert_push_error_count(2)


func test_r_012_46_closed_on_every_path() -> void:
	for path: String in ["request", "top", "back", "all"]:
		var screen: UIScreen = _manager.open(SCREEN_A)
		watch_signals(screen)
		match path:
			"request":
				screen.close_requested.emit()
			"top":
				_manager.close_top()
			"back":
				_manager.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
			"all":
				_manager.close_all()
		assert_signal_emit_count(screen, "closed", 1, "closed once by %s" % path)
		assert_eq((screen as ProbeScreen).closed_calls, 1, "after on_closed (%s)" % path)


func test_r_012_46_off_by_default() -> void:
	var plain: UIScreen = UIScreen.new()
	assert_false(plain.closes_on_outside_tap, "a screen does not close on an outside tap unless it says so")
	plain.free()
	_manager.catalog.screens[SCREEN_TAP] = _new_tap_probe_scene(false)
	var _screen: UIScreen = _manager.open(SCREEN_TAP)
	_tap(OUTSIDE)
	assert_true(_manager.is_open(SCREEN_TAP), "it stays open")


func test_r_012_46_outside_tap_closes_top() -> void:
	_with_tap_probes()
	var screen: UIScreen = _manager.open(SCREEN_TAP)
	watch_signals(screen)
	_tap(PANEL_RECT.get_center())
	assert_true(_manager.is_open(SCREEN_TAP), "a tap inside the panel does not close it")
	_tap(OUTSIDE)
	assert_signal_emit_count(screen, "back_requested", 1, "one tap, one request")
	assert_false(_manager.is_open(SCREEN_TAP), "a tap outside the panel closes it")


func test_r_012_46_outside_tap_goes_through_handle_back() -> void:
	_with_tap_probes()
	var screen: ProbeScreen = _manager.open(SCREEN_TAP) as ProbeScreen
	screen.keeps_on_back = true
	_tap(OUTSIDE)
	assert_eq(screen.back_calls, 1, "the screen was asked, as with Escape")
	assert_true(_manager.is_open(SCREEN_TAP), "and it kept itself open")


func test_r_012_46_only_the_top_screen() -> void:
	_with_tap_probes()
	var bottom: UIScreen = _manager.open(SCREEN_TAP)
	var top: UIScreen = _manager.open(SCREEN_TAP_B)
	bottom.back_requested.emit()
	assert_true(_manager.is_open(SCREEN_TAP), "a screen below is never closed by its own request")
	assert_true(_manager.is_open(SCREEN_TAP_B), "nor the top one")
	_tap(OUTSIDE)
	assert_false(_manager.is_open(SCREEN_TAP_B), "the tap closes the top screen")
	assert_true(_manager.is_open(SCREEN_TAP), "and only that one")
	assert_false(top.is_inside_tree() and not top.is_queued_for_deletion(), "the top screen is gone")


func test_r_012_47_outside_tap_is_accepted() -> void:
	_with_tap_probes()
	var probe: MouseProbe = MouseProbe.new()
	add_child_autofree(probe)
	var _screen: UIScreen = _manager.open(SCREEN_TAP)
	_tap(OUTSIDE)
	assert_false(_manager.is_open(SCREEN_TAP), "closed")
	assert_eq(probe.presses, 0, "the press never reached the game")
