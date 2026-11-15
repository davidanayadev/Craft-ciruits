extends SceneTree
## Exits with 1 if any project script fails to load (R-001-09).
##
## GUT only warns about a test script that does not compile and still exits
## with 0, and a production script without tests is never loaded by it.
## Run through tools/run_tests.sh.

const PROJECT_ROOT: String = "res://"
## addons/ is third-party code, excluded from the project's GDScript warnings.
const SKIPPED_DIRS: PackedStringArray = ["res://addons", "res://.godot"]
const SCRIPT_EXTENSION: String = "gd"
const EXIT_OK: int = 0
const EXIT_BROKEN_SCRIPTS: int = 1


# Not in _init(): autoloads are registered after it, and a script that names
# one (GameManager, DataRegistry) would fail to compile before that.
func _initialize() -> void:
	var scripts: PackedStringArray = _find_scripts(PROJECT_ROOT)
	var broken: PackedStringArray = []
	for path: String in scripts:
		if not _loads(path):
			broken.append(path)
	for path: String in broken:
		printerr("check_scripts: failed to load %s" % path)
	print("check_scripts: %d scripts checked, %d failed to load." % [scripts.size(), broken.size()])
	quit(EXIT_OK if broken.is_empty() else EXIT_BROKEN_SCRIPTS)


func _find_scripts(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == SCRIPT_EXTENSION:
			found.append(dir.path_join(file))
	for subdir: String in DirAccess.get_directories_at(dir):
		var path: String = dir.path_join(subdir)
		if not SKIPPED_DIRS.has(path):
			found.append_array(_find_scripts(path))
	return found


func _loads(path: String) -> bool:
	var script: GDScript = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	# A script with parse errors still loads as an object; it just cannot be instantiated.
	return script != null and script.can_instantiate()
