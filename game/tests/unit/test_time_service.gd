extends GutTest
## ITimeService / LocalTimeService (spec 008, R-008-19): the clock is a service
## behind a base class; only the local implementation reads the device clock, so
## tests (and later a server) can swap it.

const GAME_CODE_DIRS: Array[String] = ["res://scripts", "res://scenes"]
const CLOCK_READER := "res://scripts/services/local_time_service.gd"
const CLOCK_CALL := "Time.get_unix_time"


func _collect_scripts(dir_path: String) -> PackedStringArray:
	var scripts: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			scripts.append(dir_path.path_join(file))
	for dir: String in DirAccess.get_directories_at(dir_path):
		scripts.append_array(_collect_scripts(dir_path.path_join(dir)))
	return scripts


func test_r_008_19_base_reports_error() -> void:
	var service: ITimeService = ITimeService.new()
	var now: int = service.now_unix()
	assert_push_error("now_unix")
	assert_eq(now, 0, "the base class returns 0")


func test_r_008_19_local_reads_device_clock() -> void:
	var service: ITimeService = LocalTimeService.new()
	var before: int = int(Time.get_unix_time_from_system())
	var now: int = service.now_unix()
	var after: int = int(Time.get_unix_time_from_system())
	assert_true(service is ITimeService, "LocalTimeService is an ITimeService")
	assert_between(now, before, after, "now_unix lies between two device clock reads")


func test_r_008_19_no_other_script_reads_the_clock() -> void:
	var checked: int = 0
	var readers: PackedStringArray = PackedStringArray()
	for dir_path: String in GAME_CODE_DIRS:
		for script_path: String in _collect_scripts(dir_path):
			checked += 1
			var source: String = FileAccess.get_file_as_string(script_path)
			if source.contains(CLOCK_CALL):
				readers.append(script_path)
	assert_gt(checked, 0, "game scripts were found and checked")
	assert_eq(readers, PackedStringArray([CLOCK_READER]), "only the local service reads the clock")


func test_r_008_19_fake_clock_returns_what_it_was_set_to() -> void:
	var fake: FakeTimeService = FakeTimeService.new()
	var service: ITimeService = fake
	assert_eq(service.now_unix(), 0, "starts at 0")
	fake.now = 1_700_000_123
	assert_eq(service.now_unix(), 1_700_000_123, "returns the set time")
	fake.now = 5
	assert_eq(service.now_unix(), 5, "follows changes")
