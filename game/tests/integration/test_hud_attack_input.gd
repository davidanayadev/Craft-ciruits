extends GutTest
## Clicks on the HUD are not attacks (spec 007, R-007-15), in the main scene
## with real mouse events: a left click on a HUD button is consumed by the
## button and starts no swing, although the left button is bound to `attack`;
## a click on the scenery does swing, and the attack button swings once.
## Mouse positions go in window coordinates (plan 007 §5.1, point 3).
## Spec 009: the game starts by travelling to the base; the tests wait for it,
## since the input is blocked while a travel runs.

const MAIN_SCENE := preload("res://scenes/main.tscn")
## Frames for a parsed event to reach the GUI and the next physics step.
const INPUT_FRAMES := 4
const TRAVEL_TIMEOUT_S := 10.0

var _main: Node
var _robot: Robot
var _hud: Hud
## The test runner draws its own panel over the right side of the screen,
## where the attack button is; it is hidden while these tests click.
var _runner_layer: CanvasLayer


func before_all() -> void:
	_runner_layer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer


func before_each() -> void:
	# First: Main reads the visit counter of its zone in _ready.
	GameManager.clear_visit_counts()
	if _runner_layer != null:
		_runner_layer.visible = false
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)
	_robot = _main.get_node("%Robot") as Robot
	_hud = _main.get_node("%Hud") as Hud
	var loader: ZoneLoader = _main.get_node("%ZoneLoader") as ZoneLoader
	if loader.is_travelling():
		await wait_for_signal(loader.travel_finished, TRAVEL_TIMEOUT_S)
	watch_signals(_robot.melee)
	await wait_process_frames(2)


func after_each() -> void:
	Input.action_release(&"attack")
	GameManager.clear_visit_counts()
	if _runner_layer != null:
		_runner_layer.visible = true


func _click(viewport_position: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_MOUSE
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = get_viewport().get_final_transform() * viewport_position
	event.global_position = event.position
	Input.parse_input_event(event)
	await wait_process_frames(INPUT_FRAMES)
	await wait_physics_frames(INPUT_FRAMES)


func _centre_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func test_r_007_15_click_on_hud_button_is_not_attack() -> void:
	var storage: Button = _hud.get_node("%StorageButton") as Button
	var ui_manager: UIManager = _main.get_node("%UIManager") as UIManager
	await _click(_centre_of(storage), true)
	assert_true(Input.is_action_pressed(&"attack"), "the click does set the attack action")
	await _click(_centre_of(storage), false)
	assert_true(ui_manager.is_modal_open(), "the storage button got the click")
	ui_manager.close_all()
	await wait_physics_frames(INPUT_FRAMES)
	assert_signal_not_emitted(_robot.melee, "swing_started", "and the robot did not swing")


func test_r_007_15_click_on_scenery_attacks() -> void:
	var empty_spot: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.75, 0.3)
	await _click(empty_spot, true)
	await _click(empty_spot, false)
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "a click on the scenery is an attack")


func test_r_007_15_click_on_attack_button_swings_once() -> void:
	var attack: Button = _hud.get_node("%AttackButton") as Button
	watch_signals(_hud)
	await _click(_centre_of(attack), true)
	assert_signal_emitted_with_parameters(_hud, "attack_held_changed", [true])
	await _click(_centre_of(attack), false)
	assert_signal_emitted_with_parameters(_hud, "attack_held_changed", [false])
	assert_signal_emit_count(_robot.melee, "swing_started", 1, "one swing: from the button, not also from the click")
