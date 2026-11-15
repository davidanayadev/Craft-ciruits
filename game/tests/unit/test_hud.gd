extends GutTest
## Battery HUD (R-003-11): a bar and a whole number rounded up at the top left,
## driven only by battery_changed. The robot's physics is switched off so the
## battery only moves when the test says so.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
## ProgressBar snaps its value to its step.
const BAR_TOLERANCE := 0.01

var _hud: Hud
var _robot: Robot
var _bar: ProgressBar
var _label: Label


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child_autofree(_hud)
	_bar = _hud.get_node("%BatteryBar") as ProgressBar
	_label = _hud.get_node("%BatteryLabel") as Label


func test_r_003_11_display_value_rounds_up() -> void:
	assert_eq(Hud.display_value(100.0), 100, "a whole value stays")
	assert_eq(Hud.display_value(87.5), 88, "fractions round up")
	assert_eq(Hud.display_value(0.01), 1, "never 0 while any charge remains")
	assert_eq(Hud.display_value(0.0), 0, "0 only when empty")


func test_r_003_11_shows_current_state_when_bound() -> void:
	_robot.battery.consume(30.0)
	_hud.bind(_robot)
	assert_eq(_label.text, "70", "the number shows the battery it was bound to")
	assert_almost_eq(_bar.value, 70.0, BAR_TOLERANCE, "the bar too")
	assert_eq(_bar.max_value, 100.0, "the bar ends at the maximum battery")


func test_r_003_11_follows_battery_changed() -> void:
	_hud.bind(_robot)
	_robot.battery.consume(12.5)
	assert_eq(_label.text, "88", "87.5 is shown rounded up")
	assert_almost_eq(_bar.value, 87.5, BAR_TOLERANCE, "the bar keeps the real value")
	_robot.battery.consume(87.49)
	assert_eq(_label.text, "1", "0.01 left still shows 1")
	_robot.battery.consume(1.0)
	assert_eq(_label.text, "0", "empty shows 0")
	assert_eq(_bar.value, 0.0, "empty bar")


func test_r_003_11_does_not_poll() -> void:
	_hud.bind(_robot)
	assert_false(_hud.is_processing(), "no _process")
	assert_false(_hud.is_physics_processing(), "no _physics_process")


func test_r_003_11_anchored_top_left_without_own_percentage() -> void:
	assert_eq(_bar.anchor_left, 0.0, "bar anchored to the left edge")
	assert_eq(_bar.anchor_top, 0.0, "bar anchored to the top edge")
	assert_eq(_bar.anchor_right, 0.0, "bar does not stretch across the screen")
	assert_eq(_bar.anchor_bottom, 0.0, "bar does not stretch down the screen")
	assert_false(_bar.show_percentage, "the number comes from the label, not from the bar")
