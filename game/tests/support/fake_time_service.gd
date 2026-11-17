class_name FakeTimeService
extends ITimeService
## Clock the tests set by hand, so none of them waits for real time.

var now: int = 0


func now_unix() -> int:
	return now
