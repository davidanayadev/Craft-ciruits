extends GutTest
## InteractorComponent (spec 004, architecture §9.1): offers the nearest
## enabled interactable in range and reports every change of target, including
## to none (R-004-12), never a disabled one (R-004-15), with the range of
## controls.tres (R-004-17).
## The choice is a pure function; the detection tests use real physics.

const CONTROLS_PATH := "res://resources/config/controls.tres"
## Area overlaps are reported one or two physics frames after a move.
const SETTLE_FRAMES := 4
## Radius of the test targets: small, so the range is the interactor's.
const TARGET_RADIUS := 0.05
const FAR_AWAY := Vector3(100.0, 0.0, 0.0)

var _config: ControlConfigData
var _interactor: InteractorComponent


func before_each() -> void:
	_config = load(CONTROLS_PATH) as ControlConfigData
	_interactor = InteractorComponent.new()
	_interactor.config = _config
	add_child_autofree(_interactor)
	watch_signals(_interactor)


func _new_target(position: Vector3) -> InteractableComponent:
	var target: InteractableComponent = InteractableComponent.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = TARGET_RADIUS
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	target.add_child(collision)
	add_child_autofree(target)
	target.global_position = position
	return target


func _settle() -> void:
	await wait_physics_frames(SETTLE_FRAMES)


func test_r_004_12_pick_nearest() -> void:
	var near: InteractableComponent = _new_target(Vector3(1.0, 0.0, 0.0))
	var far: InteractableComponent = _new_target(Vector3(0.0, 0.0, -1.5))
	var candidates: Array[InteractableComponent] = [far, near]
	assert_same(InteractorComponent.pick_nearest(Vector3.ZERO, candidates), near, "nearest wins")
	assert_same(
		InteractorComponent.pick_nearest(Vector3(0.0, 0.0, -2.0), candidates),
		far,
		"from another origin the other one is nearest"
	)


func test_r_004_12_pick_nearest_without_candidates_is_none() -> void:
	var none: Array[InteractableComponent] = []
	assert_null(InteractorComponent.pick_nearest(Vector3.ZERO, none))


func test_r_004_15_pick_nearest_skips_disabled() -> void:
	var near: InteractableComponent = _new_target(Vector3(1.0, 0.0, 0.0))
	var far: InteractableComponent = _new_target(Vector3(1.5, 0.0, 0.0))
	near.enabled = false
	var candidates: Array[InteractableComponent] = [near, far]
	assert_same(InteractorComponent.pick_nearest(Vector3.ZERO, candidates), far)
	far.enabled = false
	assert_null(InteractorComponent.pick_nearest(Vector3.ZERO, candidates), "all disabled: none")


func test_r_004_17_radius_from_config() -> void:
	assert_eq(_interactor.get_range(), _config.interaction_range_m, "range from controls.tres")
	var shapes: Array[Node] = _interactor.find_children("*", "CollisionShape3D", false, false)
	assert_eq(shapes.size(), 1, "one detection shape")
	if shapes.size() != 1:
		return
	var sphere: SphereShape3D = (shapes[0] as CollisionShape3D).shape as SphereShape3D
	assert_not_null(sphere, "the detection shape is a sphere")
	if sphere != null:
		assert_eq(sphere.radius, _config.interaction_range_m, "its radius is the range")


func test_r_004_17_missing_config_reports_error() -> void:
	var orphan: InteractorComponent = InteractorComponent.new()
	orphan.name = "Orphan"
	add_child_autofree(orphan)
	assert_push_error("Orphan")


func test_r_004_12_detects_only_interaction_layer() -> void:
	var layer_bit: int = 1 << (InteractableComponent.PHYSICS_LAYER - 1)
	assert_eq(_interactor.collision_mask, layer_bit, "detects only the interaction layer")
	assert_eq(_interactor.collision_layer, 0, "is on no layer")
	assert_true(_interactor.monitoring, "monitors")
	assert_false(_interactor.monitorable, "cannot be detected")


func test_r_004_12_target_changed_on_enter_and_exit() -> void:
	var in_range: Vector3 = Vector3(_config.interaction_range_m * 0.5, 0.0, 0.0)
	var first: InteractableComponent = _new_target(in_range)
	var second: InteractableComponent = _new_target(FAR_AWAY + in_range)
	await _settle()
	assert_same(_interactor.get_target(), first, "the target in range")
	assert_signal_emit_count(_interactor, "target_changed", 1)
	assert_signal_emitted_with_parameters(_interactor, "target_changed", [first])
	_interactor.global_position = FAR_AWAY
	await _settle()
	assert_same(_interactor.get_target(), second, "the other target after moving next to it")
	assert_signal_emitted_with_parameters(_interactor, "target_changed", [second])
	_interactor.global_position = -FAR_AWAY
	await _settle()
	assert_null(_interactor.get_target(), "no target away from both")
	assert_signal_emitted_with_parameters(_interactor, "target_changed", [null])
	assert_signal_emit_count(_interactor, "target_changed", 3, "one signal per change")


func test_r_004_12_nearest_of_two_in_range() -> void:
	var reach: float = _config.interaction_range_m
	var far: InteractableComponent = _new_target(Vector3(reach * 0.8, 0.0, 0.0))
	var near: InteractableComponent = _new_target(Vector3(0.0, 0.0, reach * 0.4))
	await _settle()
	assert_same(_interactor.get_target(), near, "the nearest of the two in range")
	_interactor.global_position = Vector3(reach * 0.7, 0.0, 0.0)
	await _settle()
	assert_same(_interactor.get_target(), far, "the other one once it is nearer")


func test_r_004_12_out_of_range_is_not_a_target() -> void:
	_new_target(Vector3(_config.interaction_range_m + 0.5, 0.0, 0.0))
	await _settle()
	assert_null(_interactor.get_target(), "beyond the interaction range")
	assert_signal_not_emitted(_interactor, "target_changed")


func test_r_004_12_no_signal_without_change() -> void:
	_new_target(Vector3(_config.interaction_range_m * 0.5, 0.0, 0.0))
	await _settle()
	await wait_physics_frames(20)
	assert_signal_emit_count(_interactor, "target_changed", 1, "silent while the target stays")


func test_r_004_15_disabled_is_not_a_target() -> void:
	var target: InteractableComponent = _new_target(
		Vector3(_config.interaction_range_m * 0.5, 0.0, 0.0)
	)
	await _settle()
	assert_same(_interactor.get_target(), target)
	target.enabled = false
	await _settle()
	assert_null(_interactor.get_target(), "a disabled interactable is no longer offered")
	assert_signal_emitted_with_parameters(_interactor, "target_changed", [null])


func test_r_004_12_freed_target_becomes_none() -> void:
	var target: InteractableComponent = _new_target(
		Vector3(_config.interaction_range_m * 0.5, 0.0, 0.0)
	)
	await _settle()
	target.free()
	await _settle()
	assert_null(_interactor.get_target(), "a freed target is dropped")
	assert_signal_emit_count(_interactor, "target_changed", 2)


func test_r_004_14_interact_with_target() -> void:
	var user: Node3D = Node3D.new()
	add_child_autofree(user)
	assert_false(_interactor.interact_with_target(user), "nothing to interact with")
	var target: InteractableComponent = _new_target(
		Vector3(_config.interaction_range_m * 0.5, 0.0, 0.0)
	)
	watch_signals(target)
	await _settle()
	assert_true(_interactor.interact_with_target(user), "interacts with the current target")
	assert_signal_emitted_with_parameters(target, "interacted", [user])
