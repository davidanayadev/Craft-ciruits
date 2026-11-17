class_name DroppedItemRules
extends RefCounted
## When a dropped item expires (spec 008, BALANCE.md §7.2). Pure rules: the
## times come by parameter, so they depend neither on the clock nor on the
## frame rate, and loading a saved world reuses them (spec 010).


## Seconds since the drop. A clock set back gives a negative time, which
## counts as 0: the item never gains life from it, it only waits again.
static func elapsed_s(dropped_at_unix: int, now_unix: int) -> int:
	return maxi(now_unix - dropped_at_unix, 0)


static func is_expired(dropped_at_unix: int, now_unix: int, lifetime_s: int) -> bool:
	return elapsed_s(dropped_at_unix, now_unix) >= lifetime_s
