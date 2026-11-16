extends GutTest
## Hits on the robot (spec 006): a hit takes its damage from the battery, 1:1
## (R-006-16), is announced with the damage and the attacker (R-006-17), and a
## robot with a depleted battery takes none (R-006-18). Enemies find the robot
## through its player group. The damage here is a test input, not a balance
## value.

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const DAMAGE := 5.0
## Passive drain of the physics frames that may run during a test.
const TOLERANCE := 0.05

var _robot: Robot
var _attacker: Node3D


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_attacker = Node3D.new()
	_attacker.name = "Attacker"
	add_child_autofree(_attacker)
	watch_signals(_robot)


func test_r_006_16_robot_in_player_group() -> void:
	assert_true(_robot.is_in_group(Robot.PLAYER_GROUP), "enemies find the robot by group")
	var players: Array[Node] = get_tree().get_nodes_in_group(Robot.PLAYER_GROUP)
	assert_true(players.has(_robot), "the tree lists it as a player")


func test_r_006_16_hit_consumes_battery() -> void:
	var before: float = _robot.battery.get_current()
	_robot.receive_hit(DAMAGE, _attacker)
	assert_almost_eq(_robot.battery.get_current(), before - DAMAGE, TOLERANCE, "1:1 in battery")


func test_r_006_16_hit_can_deplete_the_battery() -> void:
	watch_signals(_robot.battery)
	_robot.receive_hit(_robot.battery.get_maximum() * 2.0, _attacker)
	assert_true(_robot.battery.is_depleted(), "a hit larger than the charge depletes it")
	assert_signal_emit_count(_robot.battery, "battery_depleted", 1)


func test_r_006_17_hit_received_signal() -> void:
	_robot.receive_hit(DAMAGE, _attacker)
	assert_signal_emitted_with_parameters(_robot, "hit_received", [DAMAGE, _attacker])
	assert_signal_emit_count(_robot, "hit_received", 1)


func test_r_006_17_negative_damage_reports_error() -> void:
	var before: float = _robot.battery.get_current()
	_robot.receive_hit(-DAMAGE, _attacker)
	assert_push_error("receive_hit")
	assert_almost_eq(_robot.battery.get_current(), before, TOLERANCE, "nothing consumed")
	assert_signal_not_emitted(_robot, "hit_received")


func test_r_006_18_depleted_ignores_hit() -> void:
	_robot.battery.consume(_robot.battery.get_current())
	assert_true(_robot.battery.is_depleted(), "the battery is depleted")
	watch_signals(_robot.battery)
	_robot.receive_hit(DAMAGE, _attacker)
	assert_signal_not_emitted(_robot, "hit_received", "a depleted robot takes no hit")
	assert_signal_not_emitted(_robot.battery, "battery_changed", "and its battery does not change")
