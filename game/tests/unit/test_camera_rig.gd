extends GutTest
## CameraRig shake (spec 007, R-007-24 and R-007-25): the camera is displaced
## in the plane of the screen, never by more than the strength, fades back to
## its place when the time is over, and a stronger shake is not cut short by a
## weaker one. Time advances by hand through advance_shake().
## The numbers are arbitrary test inputs, exact in binary, not balance values.

const RIG_SCENE := preload("res://scenes/camera/camera_rig.tscn")
const STRENGTH := 0.5
const DURATION := 0.5
const STEP := 0.125

var _rig: CameraRig


func before_each() -> void:
	_rig = RIG_SCENE.instantiate() as CameraRig
	add_child_autofree(_rig)


func _offset() -> Vector2:
	return Vector2(_rig.camera.h_offset, _rig.camera.v_offset)


func test_r_007_24_idle_at_start() -> void:
	assert_false(_rig.is_shaking(), "no shake at start")
	assert_false(_rig.is_processing(), "and no per-frame work")
	assert_eq(_offset(), Vector2.ZERO, "the camera is in its place")


func test_r_007_24_shake_displaces_camera() -> void:
	var camera_position: Vector3 = _rig.camera.position
	var rig_position: Vector3 = _rig.global_position
	_rig.shake(STRENGTH, DURATION)
	assert_true(_rig.is_shaking(), "shaking")
	assert_true(_rig.is_processing(), "it processes while it shakes")
	_rig.advance_shake(STEP)
	assert_gt(_offset().length(), 0.0, "the camera is displaced")
	assert_eq(_rig.camera.position, camera_position, "through its offsets, not its position")
	assert_eq(_rig.global_position, rig_position, "and the rig stays on its target")


func test_r_007_24_shake_never_beyond_strength() -> void:
	_rig.shake(STRENGTH, DURATION)
	var previous_limit: float = STRENGTH
	for step: int in 3:
		_rig.advance_shake(STEP)
		var limit: float = STRENGTH * (DURATION - STEP * (step + 1)) / DURATION
		assert_almost_eq(_offset().length(), limit, 0.0001, "step %d: the strength left" % (step + 1))
		assert_lt(_offset().length(), previous_limit, "weaker than the step before")
		previous_limit = limit


func test_r_007_24_shake_returns_to_zero() -> void:
	_rig.shake(STRENGTH, DURATION)
	for step: int in 4:
		_rig.advance_shake(STEP)
	assert_false(_rig.is_shaking(), "the shake ends at its duration")
	assert_eq(_offset(), Vector2.ZERO, "the camera is back in its place")
	assert_false(_rig.is_processing(), "and it stops processing")
	_rig.advance_shake(STEP)
	assert_eq(_offset(), Vector2.ZERO, "and stays there")


func test_r_007_24_stronger_shake_wins() -> void:
	_rig.shake(STRENGTH, DURATION)
	_rig.shake(STRENGTH * 0.25, DURATION * 4.0)
	_rig.advance_shake(STEP)
	assert_almost_eq(_offset().length(), STRENGTH * 0.75, 0.0001, "the weaker shake did not replace it")
	_rig.shake(STRENGTH * 2.0, DURATION)
	_rig.advance_shake(STEP)
	assert_almost_eq(_offset().length(), STRENGTH * 2.0 * 0.75, 0.0001, "a stronger one does")


func test_r_007_25_weaker_shake_replaces_a_faded_one() -> void:
	_rig.shake(STRENGTH, DURATION)
	for step: int in 3:
		_rig.advance_shake(STEP)
	# A quarter of the strength is left, less than the new shake.
	_rig.shake(STRENGTH * 0.5, DURATION)
	_rig.advance_shake(STEP)
	assert_almost_eq(_offset().length(), STRENGTH * 0.5 * 0.75, 0.0001, "the new shake took over")


func test_r_007_24_invalid_shake_ignored() -> void:
	_rig.shake(0.0, DURATION)
	_rig.shake(STRENGTH, 0.0)
	_rig.shake(-STRENGTH, DURATION)
	assert_false(_rig.is_shaking(), "no strength or no duration is no shake")


func test_r_007_24_same_directions_every_run() -> void:
	var other: CameraRig = RIG_SCENE.instantiate() as CameraRig
	add_child_autofree(other)
	_rig.shake(STRENGTH, DURATION)
	other.shake(STRENGTH, DURATION)
	_rig.advance_shake(STEP)
	other.advance_shake(STEP)
	var other_offset: Vector2 = Vector2(other.camera.h_offset, other.camera.v_offset)
	assert_eq(_offset(), other_offset, "its own seeded generator, not the global one")
