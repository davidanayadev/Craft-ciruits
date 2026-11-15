extends GutTest
## Robot scene integration: body shape (R-002-04), real-physics collision
## (R-002-09) and stop without sliding (R-002-08). Input is driven through the
## InputMap actions, the same path the game uses (R-002-13).

const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")

var _robot: Robot


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)


func after_each() -> void:
	Input.action_release(&"move_forward")


func test_r_002_04_robot_is_characterbody_with_capsule() -> void:
	assert_true(_robot is CharacterBody3D, "robot is a CharacterBody3D")
	# Direct children only: the body's own collider. The interactor's detection
	# sphere (spec 004) is a child of its Area3D and is not part of the body.
	var shapes: Array[Node] = _robot.find_children("*", "CollisionShape3D", false, false)
	assert_eq(shapes.size(), 1, "one collision shape")
	if shapes.is_empty():
		return
	var collision: CollisionShape3D = shapes[0] as CollisionShape3D
	assert_true(collision.shape is CapsuleShape3D, "collider is a capsule")


func test_r_002_05_walks_at_walk_speed_through_input_map() -> void:
	Input.action_press(&"move_forward")
	var start: Vector3 = _robot.global_position
	await wait_physics_frames(60)
	var moved: float = _robot.global_position.distance_to(start)
	assert_almost_eq(moved, 3.0, 0.3, "about 3 m after one second walking (BALANCE §4.2)")


func test_r_002_08_stops_without_sliding() -> void:
	Input.action_press(&"move_forward")
	await wait_physics_frames(10)
	Input.action_release(&"move_forward")
	await wait_physics_frames(2)
	var rest_position: Vector3 = _robot.global_position
	await wait_physics_frames(10)
	var slid: float = _robot.global_position.distance_to(rest_position)
	assert_lt(slid, 0.001, "no sliding after releasing input")


func test_r_002_09_blocked_by_obstacle() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 4.0, 1.0)
	collision.shape = box
	wall.add_child(collision)
	add_child_autofree(wall)
	wall.global_position = Vector3(0.0, 1.0, -2.0)
	Input.action_press(&"move_forward")
	await wait_physics_frames(90)
	assert_gt(_robot.global_position.z, -2.0, "the wall stops the robot (1.5 s would reach z=-4.5)")
