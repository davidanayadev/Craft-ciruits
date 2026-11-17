extends GutTest
## Rulesets and death data (spec 008): normal.tres matches PMV §2.4 and
## BALANCE §1.1 (R-008-01), every ruleset file is valid (R-008-01), no game
## script branches on a ruleset id or name (R-008-03), and the transfer
## duration and the dropped item lifetime come from their .tres with the values
## of BALANCE §11 and §7.2, not from script literals (R-008-04).
## The expected values mirror BALANCE.md §1.1, §7.2 and §11; update both together.

const RULESETS_DIR := "res://resources/rulesets"
const NORMAL_PATH := "res://resources/rulesets/normal.tres"
const DEATH_CONFIG_PATH := "res://resources/config/death.tres"
const DROPPED_ITEMS_CONFIG_PATH := "res://resources/config/dropped_items.tres"
## BALANCE §11 "Muerte": transfer screen length in seconds.
const EXPECTED_TRANSFER_DURATION_S := 2.0
## BALANCE §7.2 "Caducidad de los items soltados": 5 minutes.
const EXPECTED_LIFETIME_S := 300
const GAME_CODE_DIRS: Array[String] = ["res://scripts", "res://scenes"]
## Comparisons with a ruleset id or name. Comments are stripped before matching.
const RULESET_BRANCH_PATTERN := (
	"&?\"normal\"|ruleset\\w*\\.(id|name)\\b\\s*[!=]=|ruleset_id\\s*[!=]=|\\.id\\s*[!=]=\\s*&\"normal\""
)
## Scripts of the death flow: none may hold a BALANCE number of spec 008.
const DEATH_SCRIPTS: PackedStringArray = [
	"res://scenes/death/death_controller.gd",
	"res://scenes/ui/transfer_screen.gd",
	"res://scenes/entities/dropped_item.gd",
	"res://scenes/entities/dropped_item_spawner.gd",
	"res://scripts/systems/dropped_item_rules.gd",
]
## 300 s (lifetime), 2.0 s (transfer), 100 / 100.0 (percent or full battery).
const DEATH_LITERAL_PATTERN := "(?<![\\w.])(300|300\\.0|2\\.0|100|100\\.0)(?![\\w.])"
const STRING_LITERAL_PATTERN := "&?\"[^\"\\n]*\""


func _new_ruleset(id: StringName, ratio: float) -> RulesetData:
	var ruleset: RulesetData = RulesetData.new()
	ruleset.id = id
	ruleset.respawn_battery_ratio = ratio
	return ruleset


func _collect_scripts(dir_path: String) -> PackedStringArray:
	var scripts: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			scripts.append(dir_path.path_join(file))
	for dir: String in DirAccess.get_directories_at(dir_path):
		scripts.append_array(_collect_scripts(dir_path.path_join(dir)))
	return scripts


## Lines matching the regex as "line N: code", with comments removed.
func _find_in_code(source: String, regex: RegEx, strip_strings: bool) -> PackedStringArray:
	var hits: PackedStringArray = PackedStringArray()
	var strings: RegEx = RegEx.create_from_string(STRING_LITERAL_PATTERN)
	var lines: PackedStringArray = source.split("\n")
	for i: int in lines.size():
		var code: String = lines[i]
		if strip_strings:
			code = strings.sub(code, "", true)
		code = code.get_slice("#", 0)
		if regex.search(code) != null:
			hits.append("line %d: %s" % [i + 1, code.strip_edges()])
	return hits


func _ruleset_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(RULESETS_DIR):
		if file.ends_with(".tres"):
			files.append(file)
	return files


# --- R-008-01 ---------------------------------------------------------------


func test_r_008_01_normal_matches_pmv() -> void:
	var ruleset: RulesetData = load(NORMAL_PATH) as RulesetData
	assert_not_null(ruleset, "normal.tres exists and is a RulesetData")
	if ruleset == null:
		return
	assert_eq(ruleset.id, &"normal", "id (stable forever)")
	assert_true(ruleset.drops_inventory, "the inventory falls where the player died (PMV §2.4)")
	assert_true(ruleset.keeps_xp, "XP is not lost (PMV §2.4)")
	assert_true(ruleset.keeps_core, "the Core is kept (PMV §2.4)")
	assert_eq(ruleset.respawn_battery_ratio, 1.0, "100% battery on respawn (BALANCE §1.1)")
	var problems: PackedStringArray = ruleset.validate()
	assert_eq(problems.size(), 0, "normal.tres is valid: %s" % problems)


func test_r_008_01_every_ruleset_file_valid() -> void:
	var files: PackedStringArray = _ruleset_files()
	assert_gt(files.size(), 0, "there is at least one ruleset file")
	for file: String in files:
		var ruleset: RulesetData = load(RULESETS_DIR.path_join(file)) as RulesetData
		assert_not_null(ruleset, "%s is a RulesetData" % file)
		if ruleset == null:
			continue
		var problems: PackedStringArray = ruleset.validate()
		assert_eq(problems.size(), 0, "%s: %s" % [file, problems])


func test_r_008_01_validate_reports_empty_id() -> void:
	var problems: PackedStringArray = _new_ruleset(&"", 1.0).validate()
	assert_gt(problems.size(), 0, "an empty id is reported")


func test_r_008_01_validate_reports_ratio_out_of_range() -> void:
	for ratio: float in [0.0, -0.5, 1.5]:
		var problems: PackedStringArray = _new_ruleset(&"custom", ratio).validate()
		assert_gt(problems.size(), 0, "ratio %s is out of (0, 1]" % ratio)


func test_r_008_01_validate_accepts_ratio_in_range() -> void:
	for ratio: float in [0.5, 1.0, 0.01]:
		var problems: PackedStringArray = _new_ruleset(&"custom", ratio).validate()
		assert_eq(problems.size(), 0, "ratio %s is valid: %s" % [ratio, problems])


# --- R-008-03 ---------------------------------------------------------------


func test_r_008_03_detector_flags_ruleset_branches() -> void:
	var regex: RegEx = RegEx.create_from_string(RULESET_BRANCH_PATTERN)
	var forbidden: Array[String] = [
		"if ruleset.id == &\"normal\":",
		"if _ruleset.id != other:",
		"if ruleset_id == target:",
		"if ruleset.name == \"x\":",
		"match kind:\n\t&\"normal\":",
		"var is_normal: bool = mode == \"normal\"",
	]
	for line: String in forbidden:
		assert_gt(_find_in_code(line, regex, false).size(), 0, "must be flagged: %s" % line)
	var allowed: Array[String] = [
		"if ruleset.drops_inventory:",
		"var id: StringName = ruleset.id",
		"_ruleset = DataRegistry.get_ruleset(config.ruleset_id)",
		"# the normal ruleset is \"normal\"",
	]
	for line: String in allowed:
		assert_eq(_find_in_code(line, regex, false).size(), 0, "must be allowed: %s" % line)


func test_r_008_03_no_script_branches_on_ruleset_id() -> void:
	var regex: RegEx = RegEx.create_from_string(RULESET_BRANCH_PATTERN)
	var checked: int = 0
	for dir_path: String in GAME_CODE_DIRS:
		for script_path: String in _collect_scripts(dir_path):
			checked += 1
			var source: String = FileAccess.get_file_as_string(script_path)
			assert_false(source.is_empty(), "%s could not be read" % script_path)
			var hits: PackedStringArray = _find_in_code(source, regex, false)
			assert_eq(hits.size(), 0, "%s compares a ruleset id or name: %s" % [script_path, hits])
	assert_gt(checked, 0, "game scripts were found and checked")


# --- R-008-04 ---------------------------------------------------------------


func test_r_008_04_death_config_matches_balance() -> void:
	var config: DeathConfigData = load(DEATH_CONFIG_PATH) as DeathConfigData
	assert_not_null(config, "death.tres exists and is a DeathConfigData")
	if config == null:
		return
	assert_eq(config.transfer_duration_s, EXPECTED_TRANSFER_DURATION_S, "transfer duration (BALANCE §11)")


func test_r_008_04_dropped_item_lifetime_matches_balance() -> void:
	var config: DroppedItemConfigData = load(DROPPED_ITEMS_CONFIG_PATH) as DroppedItemConfigData
	assert_not_null(config, "dropped_items.tres exists and is a DroppedItemConfigData")
	if config == null:
		return
	assert_eq(config.lifetime_s, EXPECTED_LIFETIME_S, "dropped item lifetime (BALANCE §7.2)")


func test_r_008_04_detector_flags_death_literals() -> void:
	var regex: RegEx = RegEx.create_from_string(DEATH_LITERAL_PATTERN)
	var forbidden: Array[String] = [
		"var lifetime: int = 300",
		"_remaining = 2.0",
		"battery.add(100.0)",
		"if elapsed >= 300.0:",
		"x = max(a, 100)",
	]
	for line: String in forbidden:
		assert_gt(_find_in_code(line, regex, true).size(), 0, "must be flagged: %s" % line)
	var allowed: Array[String] = [
		"var lifetime: int = config.lifetime_s",
		"# the lifetime is 300 seconds",
		"push_error(\"needs 300 items\")",
		"var x: float = 12.0",
		"var y: int = 1300",
		"slots.size() - 1",
		"var z: float = 0.0",
	]
	for line: String in allowed:
		assert_eq(_find_in_code(line, regex, true).size(), 0, "must be allowed: %s" % line)


func test_r_008_04_no_death_literals_in_scripts() -> void:
	var regex: RegEx = RegEx.create_from_string(DEATH_LITERAL_PATTERN)
	for script_path: String in DEATH_SCRIPTS:
		assert_true(FileAccess.file_exists(script_path), "%s exists" % script_path)
		var source: String = FileAccess.get_file_as_string(script_path)
		assert_false(source.is_empty(), "%s could be read" % script_path)
		var hits: PackedStringArray = _find_in_code(source, regex, true)
		assert_eq(hits.size(), 0, "%s holds a BALANCE number as a literal: %s" % [script_path, hits])
