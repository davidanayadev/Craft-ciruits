class_name SaveTestSupport
extends RefCounted
## What tests that start Main need from the save (spec 010, plan D10): a new
## in-memory store with a World of a known seed, and a clean SaveManager after.

## The seed of the known answers of the green zone (spec 004).
const KNOWN_SEED := 20261115


## A new in-memory store, a Profile and a World with KNOWN_SEED, written in it.
## Returns the store, so a test can read what was saved.
static func start_world() -> MemorySaveStore:
	var store: MemorySaveStore = reset()
	SaveManager.load_profile()
	SaveManager.create_world(KNOWN_SEED)
	return store


## A new empty in-memory store: no World, no Profile, nothing pending, and a
## quit action that does not quit.
static func reset() -> MemorySaveStore:
	var store: MemorySaveStore = MemorySaveStore.new()
	SaveManager.use_store(store)
	SaveManager.quit_action = _no_quit
	return store


static func _no_quit() -> void:
	pass
