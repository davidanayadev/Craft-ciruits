extends GutTest
## Spec 010 R-010-61: the MVP has no billing plugin and no network code. Only
## the GUT addon is installed and no script uses a network or Android bridge API.

const ADDONS_PATH := "res://addons"
const SCAN_ROOTS: Array[String] = ["res://scenes", "res://scripts"]
const FORBIDDEN: Array[String] = [
	"HTTPRequest",
	"HTTPClient",
	"StreamPeerTCP",
	"WebSocketPeer",
	"JavaClassWrapper",
	"Engine.get_singleton",
]


func _collect_offenders(directory: String, offenders: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(directory):
		_collect_offenders(directory.path_join(sub), offenders)
	for file: String in DirAccess.get_files_at(directory):
		if not file.ends_with(".gd"):
			continue
		var path: String = directory.path_join(file)
		var source: String = FileAccess.get_file_as_string(path)
		for word: String in FORBIDDEN:
			if source.contains(word):
				offenders.append("%s uses %s" % [path, word])


func test_r_010_61_no_billing_or_network() -> void:
	var addons: PackedStringArray = DirAccess.get_directories_at(ADDONS_PATH)
	assert_eq(addons, PackedStringArray(["gut"]), "only the gut addon is installed")
	var offenders: PackedStringArray = PackedStringArray()
	for root: String in SCAN_ROOTS:
		_collect_offenders(root, offenders)
	assert_eq(offenders, PackedStringArray(), "no network or billing API in scripts")
