class_name LocomotionSystem
extends RefCounted
## Pure movement rules (spec 002): camera-relative direction, fixed speed per
## gait and smooth yaw rotation. No Node, no Input, no scene: testable alone
## (constitution P3) and reusable by a future host/server (ONLINE.md).


static func world_direction(input_dir: Vector2, camera_yaw_rad: float) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var flat: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, camera_yaw_rad)
	return flat.normalized()


static func horizontal_velocity(
	world_dir: Vector3, run_intent: bool, stats: MovementStatsData
) -> Vector3:
	if world_dir == Vector3.ZERO:
		return Vector3.ZERO
	var running: bool = run_intent and stats.can_run
	var speed: float = stats.run_speed if running else stats.walk_speed
	return world_dir.normalized() * speed


## Yaw that makes a -Z-facing model look along world_dir.
static func target_yaw(world_dir: Vector3) -> float:
	return atan2(-world_dir.x, -world_dir.z)


## Moves current_yaw toward target by at most turn_speed_rad * delta along the
## shortest arc, without overshooting (R-002-07).
static func rotate_toward_yaw(
	current_yaw: float, target: float, turn_speed_rad: float, delta: float
) -> float:
	var diff: float = wrapf(target - current_yaw, -PI, PI)
	var step: float = turn_speed_rad * delta
	if absf(diff) <= step:
		return wrapf(target, -PI, PI)
	return wrapf(current_yaw + signf(diff) * step, -PI, PI)
