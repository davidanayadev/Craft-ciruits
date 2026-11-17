class_name LocalTimeService
extends ITimeService
## The device clock, in whole seconds. The player can change it: nothing that
## must resist cheating may trust it (ONLINE.md).


func now_unix() -> int:
	return int(Time.get_unix_time_from_system())
