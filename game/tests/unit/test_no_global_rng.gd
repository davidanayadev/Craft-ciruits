extends GutTest
## No global RNG in game code (spec 004, R-004-10; constitution P9): world
## generation must be reproducible from the world seed, so randomness comes
## only from SeededRng. The check covers every game script, which is stricter
## than "generation code" and needs no list of generation files to maintain.
## Addons and tests are not game code and are left out.

const GAME_CODE_DIRS: Array[String] = ["res://scripts", "res://scenes"]
## Global functions (not preceded by "." or an identifier, so rng.randi_range()
## is allowed) and the Array methods that use the global RNG.
const GLOBAL_RNG_PATTERN := (
	"(?<![\\w.])(randf|randi|randi_range|randf_range|randfn|randomize)\\s*\\("
	+ "|\\.(shuffle|pick_random)\\s*\\("
)

var _regex: RegEx


func before_all() -> void:
	_regex = RegEx.create_from_string(GLOBAL_RNG_PATTERN)


## Lines of the source that use the global RNG, as "line N: code". Comments are
## ignored so documentation can name the forbidden functions.
func _find_global_rng(source: String) -> PackedStringArray:
	var hits: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = source.split("\n")
	for i: int in lines.size():
		var code: String = lines[i].get_slice("#", 0)
		if _regex.search(code) != null:
			hits.append("line %d: %s" % [i + 1, code.strip_edges()])
	return hits


func _collect_scripts(dir_path: String) -> PackedStringArray:
	var scripts: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			scripts.append(dir_path.path_join(file))
	for dir: String in DirAccess.get_directories_at(dir_path):
		scripts.append_array(_collect_scripts(dir_path.path_join(dir)))
	return scripts


func test_r_004_10_detector_flags_global_rng() -> void:
	var forbidden: Array[String] = [
		"var x: float = randf()",
		"var i: int = randi() % 4",
		"var i: int = randi_range(1, 6)",
		"var x: float = randf_range(0.0, 1.0)",
		"var x: float = randfn(0.0, 1.0)",
		"\trandomize()",
		"items.shuffle()",
		"var pick: int = items.pick_random()",
		"var x: float = 1.0 - randf ()",
	]
	for line: String in forbidden:
		assert_eq(_find_global_rng(line).size(), 1, "must be flagged: %s" % line)


func test_r_004_10_detector_allows_seeded_rng() -> void:
	var allowed: Array[String] = [
		"var i: int = rng.randi_range(1, 6)",
		"var x: float = _rng.randf()",
		"rng.randomize()",
		"var i: int = my_randi()",
		"# never call randf() or arr.shuffle() here",
		"var rng: RandomNumberGenerator = SeededRng.create(world_seed, zone_id, stream)",
	]
	for line: String in allowed:
		assert_eq(_find_global_rng(line).size(), 0, "must be allowed: %s" % line)


func test_r_004_10_no_global_rng_in_game_code() -> void:
	var checked: int = 0
	for dir_path: String in GAME_CODE_DIRS:
		for script_path: String in _collect_scripts(dir_path):
			checked += 1
			var source: String = FileAccess.get_file_as_string(script_path)
			assert_false(source.is_empty(), "%s could not be read" % script_path)
			var hits: PackedStringArray = _find_global_rng(source)
			assert_eq(hits.size(), 0, "%s uses the global RNG: %s" % [script_path, hits])
	assert_gt(checked, 0, "game scripts were found and checked")
