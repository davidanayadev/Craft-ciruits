class_name ZonePopulation
extends RefCounted
## What a zone is filled with when it is generated (spec 004). Pure rules: the
## RNG comes by parameter, so the same seed always gives the same zone.


## Number of boxes in [min_count, max_count], then that many distinct marker
## indices, sorted ascending. Fewer markers than max_count → push_error and at
## most one box per marker. Invalid range → push_error and no boxes.
static func pick_box_markers(
	marker_count: int, min_count: int, max_count: int, rng: RandomNumberGenerator
) -> Array[int]:
	var picked: Array[int] = []
	if min_count < 0 or min_count > max_count:
		push_error("ZonePopulation: invalid box count range %d-%d." % [min_count, max_count])
		return picked
	if marker_count < max_count:
		push_error(
			"ZonePopulation: %d box markers for up to %d boxes." % [marker_count, max_count]
		)
	var count: int = mini(rng.randi_range(min_count, max_count), marker_count)
	var indices: Array[int] = []
	for i: int in marker_count:
		indices.append(i)
	# Partial Fisher-Yates with the given RNG: Array.shuffle() uses the global one.
	for i: int in count:
		var other: int = rng.randi_range(i, marker_count - 1)
		var swapped: int = indices[i]
		indices[i] = indices[other]
		indices[other] = swapped
	picked = indices.slice(0, count)
	picked.sort()
	return picked
