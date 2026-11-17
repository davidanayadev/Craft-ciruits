class_name SaveFields
extends RefCounted
## Typed reads of values that come from JSON (spec 010, plan D4, D18). JSON
## gives every number as a float, also 7, so whole numbers, pairs and vectors
## are read through here before anyone uses them. The one place that knows how
## a Vector2i or a Vector3 is written in a save.


## An int, or a finite float with no fraction.
static func is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var number: float = value
	return is_finite(number) and number == floorf(number)


## value as an int when it is a whole number; fallback otherwise.
static func to_int(value: Variant, fallback: int) -> int:
	if not is_whole_number(value):
		return fallback
	if value is int:
		var whole: int = value
		return whole
	var number: float = value
	return int(number)


## [x, y] of whole numbers → Vector2i; anything else → null.
static func to_vector2i(value: Variant) -> Variant:
	if not value is Array:
		return null
	var pair: Array = value
	if pair.size() != 2 or not is_whole_number(pair[0]) or not is_whole_number(pair[1]):
		return null
	return Vector2i(to_int(pair[0], 0), to_int(pair[1], 0))


## [x, y, z] of finite numbers → Vector3; anything else → null.
static func to_vector3(value: Variant) -> Variant:
	if not value is Array:
		return null
	var triple: Array = value
	if triple.size() != 3:
		return null
	var axes: Array[float] = []
	for axis: Variant in triple:
		if not (axis is int or axis is float):
			return null
		var number: float = axis
		if not is_finite(number):
			return null
		axes.append(number)
	return Vector3(axes[0], axes[1], axes[2])


static func vector2i_to_array(value: Vector2i) -> Array:
	return [value.x, value.y]


static func vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
