class_name ITimeService
extends RefCounted
## Contract of the clock (spec 008, architecture §10.1). The game reads the
## time only through it, so a server clock can replace the device's later and
## tests use a fake one. GDScript has no interfaces: implementations extend
## this class.


## Seconds since the Unix epoch, UTC.
func now_unix() -> int:
	push_error("ITimeService: now_unix() is not implemented.")
	return 0
