class_name JoystickLogic
extends RefCounted
## Pure interpretation of a virtual joystick offset (spec 002). Stateless:
## the caller keeps `was_running` between frames, so the run hysteresis
## (R-002-16) stays testable without any scene or touch event.


## Immutable reading of the stick for one frame.
class Sample:
	extends RefCounted

	var direction: Vector2 = Vector2.ZERO
	var active: bool = false
	var run_intent: bool = false


static func clamp_to_radius(offset: Vector2, radius: float) -> Vector2:
	return offset.limit_length(radius)


static func interpret(
	offset: Vector2, radius: float, was_running: bool, config: ControlConfigData
) -> Sample:
	var sample: Sample = Sample.new()
	if radius <= 0.0:
		push_error("JoystickLogic.interpret: radius must be > 0, got %f" % radius)
		return sample
	var strength: float = minf(offset.length() / radius, 1.0)
	if strength < config.joystick_dead_zone_ratio:
		return sample
	sample.active = true
	sample.direction = offset.normalized()
	if was_running:
		sample.run_intent = strength >= config.joystick_walk_back_ratio
	else:
		sample.run_intent = strength > config.joystick_run_ratio
	return sample
