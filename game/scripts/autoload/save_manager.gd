extends Node
## Autoload "SaveManager": orchestrates saving and loading (spec 010,
## architecture §5, §10). It knows no field of any owner (R-010-03): it
## collects the parts of the nodes of the persistent group, builds the
## document with the pure SaveDocuments, writes it with its ISaveStore and, on
## load, hands each part back to its owner by save key. A part belongs to a
## player when its node hangs from a player entity (by its player_uid,
## R-010-22), else to the world. It keeps the Profile in memory (plan D2),
## never a player's state. No class_name: it would clash with the autoload name.
##
## Save requests never act during the emission that asks for them: they are
## noted and resolved once at the end of the frame, all together in one save
## with the first reason. A hold (a travel, a death) keeps them pending until
## the last hold goes (R-010-43). A close request and going to the background
## save at once when nothing holds them (the OS may stop the app right after).

## Non-blocking notices for the player: a failed save, a damaged file.
signal save_notice(message_key: StringName)

const REASON_NEW_WORLD := &"new_world"
const REASON_ENTERED_BASE := &"entered_base"
const REASON_RECHARGED := &"recharged"
const REASON_DIED := &"died"
const REASON_STRUCTURE_BUILT := &"structure_built"
const REASON_STRUCTURE_MOVED := &"structure_moved"
const REASON_CLOSE := &"close"
const REASON_BACKGROUND := &"background"
const ERR_SAVE_FAILED := ISaveStore.ERR_SAVE_FAILED
const MSG_WORLD_DAMAGED := &"MSG_WORLD_DAMAGED"
const MSG_PROFILE_DAMAGED := &"MSG_PROFILE_DAMAGED"
const MSG_SAVE_NEWER_VERSION := &"MSG_SAVE_NEWER_VERSION"

enum _Found { DOCUMENT, MISSING, DAMAGED, TOO_NEW }


## What looking for a Profile or a World gave; the document only for DOCUMENT.
class _Search:
	var found: _Found = _Found.MISSING
	var document: Dictionary = {}

	func _init(p_found: _Found, p_document: Dictionary = {}) -> void:
		found = p_found
		document = p_document

## What runs once a close request is saved; get_tree().quit by default. The
## test hook replaces it (plan D10).
var quit_action: Callable

var _store: ISaveStore = null
var _profile: ProfileData = null
var _has_world: bool = false
## A file of a newer version was found: nothing is loaded or written (R-010-55).
var _blocked: bool = false
var _holds: Dictionary[StringName, bool] = {}
## Reasons noted since the last save; the first one names it.
var _pending: Array[StringName] = []
var _flush_queued: bool = false
var _quit_pending: bool = false
## The World format and its migration chain; tests may inject a chain (R-010-53).
var _world_version: int = SaveMigrations.WORLD_VERSION
var _world_steps: Array[Callable] = []


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	quit_action = get_tree().quit
	var plain_requested: bool = ProjectSettings.get_setting(LocalSaveStore.PLAIN_IN_DEBUG_SETTING, false)
	use_store(LocalSaveStore.new(
		LocalSaveStore.DEFAULT_ROOT,
		LocalSaveStore.should_encrypt(OS.is_debug_build(), plain_requested)
	))
	EventBus.zone_changed.connect(_on_zone_changed)
	EventBus.player_recharged.connect(_on_save_fact.bind(REASON_RECHARGED).unbind(1))
	EventBus.player_died.connect(_on_save_fact.bind(REASON_DIED).unbind(1))
	EventBus.structure_built.connect(_on_save_fact.bind(REASON_STRUCTURE_BUILT).unbind(1))
	EventBus.structure_moved.connect(_on_save_fact.bind(REASON_STRUCTURE_MOVED).unbind(1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close_requested()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_on_background()


## The store every save goes to; a LocalSaveStore at start-up. Only this file
## and tests call it (R-010-02). Resets every other state: World, Profile,
## holds, pending requests, block, pending quit and migration chain.
func use_store(store: ISaveStore) -> void:
	_store = store
	_profile = null
	_has_world = false
	_blocked = false
	_quit_pending = false
	_world_version = SaveMigrations.WORLD_VERSION
	_world_steps = []
	_reset_requests()


## Tests only: the World format version and its chain (R-010-53).
func use_world_migrations(current_version: int, steps: Array[Callable]) -> void:
	_world_version = current_version
	_world_steps = steps


## MAIN, else BACKUP, else a new Profile written at once (R-010-13). Both
## damaged → set aside, a new one and MSG_PROFILE_DAMAGED (R-010-49). A newer
## schema → failure MSG_SAVE_NEWER_VERSION and nothing written (plan D16).
func load_profile() -> ActionResult:
	var search: _Search = _find_profile()
	match search.found:
		_Found.DOCUMENT:
			_profile = SaveDocuments.read_profile(search.document)
			return ActionResult.success()
		_Found.TOO_NEW:
			return _block("the Profile")
		_Found.DAMAGED:
			if not _store.set_aside_profile().ok:
				# Never written over: the damaged files must stay (R-010-49).
				_profile = ProfileData.create_new()
				save_notice.emit(ERR_SAVE_FAILED)
				return ActionResult.failure(ERR_SAVE_FAILED)
			save_notice.emit(MSG_PROFILE_DAMAGED)
	_profile = ProfileData.create_new()
	return save_profile()


func save_profile() -> ActionResult:
	if _profile == null or _blocked:
		push_error("SaveManager: no Profile to save, or saves are blocked by a newer file.")
		return ActionResult.failure(ERR_SAVE_FAILED)
	var written: ActionResult = _store.write_profile(SaveCodec.encode(SaveDocuments.build_profile(_profile)))
	if not written.ok:
		push_error("SaveManager: the Profile could not be written.")
	return written


## "" before a Profile is loaded.
func get_player_uuid() -> String:
	return _profile.player_uuid if _profile != null else ""


## A copy; null before a Profile is loaded.
func get_profile() -> ProfileData:
	return _profile.copy() if _profile != null else null


## The only World (R-010-18), its BACKUP if MAIN is damaged (R-010-48), or a
## new one. Both damaged → set aside, a new World and MSG_WORLD_DAMAGED
## (R-010-49). A newer schema → failure MSG_SAVE_NEWER_VERSION. Resets holds.
func load_game() -> ActionResult:
	_reset_requests()
	if _blocked:
		return ActionResult.failure(MSG_SAVE_NEWER_VERSION)
	var ids: PackedStringArray = _store.list_world_ids()
	if ids.is_empty():
		return create_world(_new_world_seed())
	if ids.size() > 1:
		push_error("SaveManager: %d worlds found; the MVP plays the first, %s." % [ids.size(), ids[0]])
	var search: _Search = _find_world(ids[0])
	match search.found:
		_Found.DOCUMENT:
			_apply_world(search.document)
			return ActionResult.success()
		_Found.TOO_NEW:
			return _block("the World %s" % ids[0])
		_Found.DAMAGED:
			if not _store.set_aside_world(ids[0]).ok:
				return _begin_unsaved_world()
			save_notice.emit(MSG_WORLD_DAMAGED)
	return create_world(_new_world_seed())


## The damaged World could not be set aside: never written over (R-010-49),
## so this session plays a new World in memory and saves nothing.
func _begin_unsaved_world() -> ActionResult:
	var catalog: DataCatalog = DataRegistry.get_catalog()
	var ruleset: RulesetData = catalog.new_world_ruleset if catalog != null else null
	GameManager.begin_world(Uid.generate(), "", _new_world_seed(), ruleset)
	save_notice.emit(ERR_SAVE_FAILED)
	return ActionResult.failure(ERR_SAVE_FAILED)


## A new World with the catalog's new_world_ruleset (NORMAL), written at once
## (R-010-19). Resets holds.
func create_world(world_seed: int) -> ActionResult:
	_reset_requests()
	if _blocked:
		return ActionResult.failure(MSG_SAVE_NEWER_VERSION)
	var catalog: DataCatalog = DataRegistry.get_catalog()
	var ruleset: RulesetData = catalog.new_world_ruleset if catalog != null else null
	if ruleset == null:
		push_error("SaveManager: the data catalog has no new_world_ruleset; no World created.")
		return ActionResult.failure(ERR_SAVE_FAILED)
	GameManager.begin_world(Uid.generate(), "", world_seed, ruleset)
	_has_world = true
	return save_game(REASON_NEW_WORLD)


func has_world() -> bool:
	return _has_world


## Writes now and emits EventBus.game_saved(reason) once (R-010-44). No World
## or a block → push_error and failure (R-010-04); a failed write leaves the
## files as they were, emits no game_saved and shows ERR_SAVE_FAILED (R-010-45).
func save_game(reason: StringName) -> ActionResult:
	if not _has_world or _blocked:
		push_error("SaveManager: cannot save (%s): no World loaded, or blocked by a newer file." % reason)
		return ActionResult.failure(ERR_SAVE_FAILED)
	var bytes: PackedByteArray = SaveCodec.encode(_build_world_document())
	var written: ActionResult = _store.write_world(GameManager.get_world_id(), bytes)
	if not written.ok:
		push_error("SaveManager: the World could not be saved (%s); the previous files stay." % reason)
		save_notice.emit(ERR_SAVE_FAILED)
		return written
	EventBus.game_saved.emit(reason)
	return written


## Noted, never acted on during the call: resolved once at the end of the
## frame, or when the last hold goes. No World → ignored, no error.
func request_save(reason: StringName) -> void:
	if not _has_world or _blocked:
		return
	_pending.append(reason)
	_queue_flush()


func hold_saves(reason: StringName) -> void:
	_holds[reason] = true


func release_saves(reason: StringName) -> void:
	_holds.erase(reason)
	_queue_flush()


## The World and its backup; the Profile stays (R-010-15, R-010-51).
func delete_save() -> ActionResult:
	var world_id: String = GameManager.get_world_id() if _has_world else ""
	var ids: PackedStringArray = [world_id] if _has_world else _store.list_world_ids()
	for id: String in ids:
		var deleted: ActionResult = _store.delete_world(id)
		if not deleted.ok:
			push_error("SaveManager: the World %s could not be deleted." % id)
			return deleted
	_has_world = false
	_reset_requests()
	return ActionResult.success()


func _reset_requests() -> void:
	_holds.clear()
	_pending.clear()


func _queue_flush() -> void:
	if _flush_queued:
		return
	_flush_queued = true
	_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	if _pending.is_empty() or not _holds.is_empty():
		return
	var reason: StringName = _pending[0]
	_pending.clear()
	if _has_world and not _blocked:
		save_game(reason)
	if _quit_pending:
		_quit_pending = false
		quit_action.call()


func _on_save_fact(reason: StringName) -> void:
	request_save(reason)


## Entering the base saves; it never recharges (R-010-38).
func _on_zone_changed(zone_id: Vector2i) -> void:
	var base: ZoneData = DataRegistry.get_base_zone()
	if base != null and zone_id == base.zone_id:
		request_save(REASON_ENTERED_BASE)


func _on_close_requested() -> void:
	if not _has_world or _blocked:
		quit_action.call()
		return
	if not _holds.is_empty():
		_quit_pending = true
		request_save(REASON_CLOSE)
		return
	save_game(REASON_CLOSE)
	quit_action.call()


func _on_background() -> void:
	if not _has_world or _blocked:
		return
	if not _holds.is_empty():
		request_save(REASON_BACKGROUND)
		return
	save_game(REASON_BACKGROUND)


func _block(what: String) -> ActionResult:
	_blocked = true
	_has_world = false
	push_error("SaveManager: %s comes from a newer version of the game; it is not loaded nor written." % what)
	return ActionResult.failure(MSG_SAVE_NEWER_VERSION)


func _find_profile() -> _Search:
	return _find(_store.read_profile, "the Profile", SaveMigrations.migrate_profile, _validate_profile)


## A copy whose header names another World is not valid: saving it would
## start a second file (R-010-18).
func _find_world(world_id: String) -> _Search:
	var read: Callable = func(copy: ISaveStore.Copy) -> SaveReadResult:
		return _store.read_world(world_id, copy)
	var validate: Callable = func(document: Dictionary) -> PackedStringArray:
		var problems: PackedStringArray = _validate_world(document)
		if problems.is_empty() and str(document[SaveDocuments.KEY_WORLD_ID]) != world_id:
			problems.append("its header names the World '%s'" % document[SaveDocuments.KEY_WORLD_ID])
		return problems
	return _find(read, "the World %s" % world_id, _migrate_world, validate)


## MAIN, else BACKUP (R-010-48). Each copy is decoded, migrated before anyone
## reads it (R-010-53) and validated. A newer copy stops the search: an older
## backup must not replace it (R-010-55). Damage is reported once, with what
## was wrong with each copy.
func _find(read: Callable, what: String, migrate: Callable, validate: Callable) -> _Search:
	var damage: PackedStringArray = PackedStringArray()
	for copy: ISaveStore.Copy in [ISaveStore.Copy.MAIN, ISaveStore.Copy.BACKUP]:
		var result: SaveReadResult = read.call(copy)
		if result.status == SaveReadResult.Status.MISSING:
			continue
		var decoded: Variant = SaveCodec.decode(result.bytes) if result.status == SaveReadResult.Status.FOUND else null
		if decoded == null:
			damage.append("the %s copy cannot be read" % _copy_name(copy))
			continue
		var migrated: SaveMigrations.Result = migrate.call(decoded)
		if migrated.outcome == SaveMigrations.Outcome.TOO_NEW:
			return _Search.new(_Found.TOO_NEW)
		var problems: PackedStringArray = validate.call(migrated.document)
		if migrated.outcome == SaveMigrations.Outcome.INVALID or not problems.is_empty():
			damage.append("the %s copy is not valid (%s)" % [_copy_name(copy), ", ".join(problems)])
			continue
		if not damage.is_empty():
			push_error("SaveManager: %s was damaged (%s); its backup was loaded." % [what, "; ".join(damage)])
		return _Search.new(_Found.DOCUMENT, migrated.document)
	if damage.is_empty():
		return _Search.new(_Found.MISSING)
	push_error("SaveManager: %s is damaged (%s); it is set aside." % [what, "; ".join(damage)])
	return _Search.new(_Found.DAMAGED)


func _migrate_world(document: Dictionary) -> SaveMigrations.Result:
	return SaveMigrations.apply(document, _world_version, _world_steps)


func _validate_world(document: Dictionary) -> PackedStringArray:
	return SaveDocuments.validate_world(document, DataRegistry.get_catalog())


func _validate_profile(document: Dictionary) -> PackedStringArray:
	return SaveDocuments.validate_profile(document)


static func _copy_name(copy: ISaveStore.Copy) -> String:
	return "main" if copy == ISaveStore.Copy.MAIN else "backup"


## Header to GameManager, then every part to its owner; a missing key leaves
## that owner in its new-game state (R-010-10).
func _apply_world(document: Dictionary) -> void:
	var header: SaveDocuments.WorldHeader = SaveDocuments.read_header(document)
	GameManager.begin_world(
		header.world_id, header.world_name, header.world_seed,
		DataRegistry.get_ruleset(header.ruleset_id)
	)
	_has_world = true
	var players: Dictionary[String, Dictionary] = SaveDocuments.read_players(document)
	var world: Dictionary[String, Dictionary] = SaveDocuments.read_world_parts(document)
	for owner: Node in get_tree().get_nodes_in_group(SaveDocuments.PERSISTENT_GROUP):
		var player_uid: String = _player_uid_of(owner)
		var parts: Dictionary = world if player_uid.is_empty() else players.get(player_uid, {})
		var save_key: StringName = owner.call(&"get_save_key")
		var key: String = String(save_key)
		if parts.has(key):
			var part: Dictionary = parts[key]
			owner.call(&"from_save_data", part)


func _build_world_document() -> Dictionary:
	var header: SaveDocuments.WorldHeader = SaveDocuments.WorldHeader.new()
	header.world_id = GameManager.get_world_id()
	header.world_name = GameManager.get_world_name()
	header.world_seed = GameManager.get_world_seed()
	header.ruleset_id = GameManager.get_ruleset().id if GameManager.get_ruleset() != null else &""
	header.saved_at_unix = GameManager.get_time_service().now_unix()
	var players: Dictionary[String, Dictionary] = {}
	var world: Dictionary[String, Dictionary] = {}
	for owner: Node in get_tree().get_nodes_in_group(SaveDocuments.PERSISTENT_GROUP):
		var player_uid: String = _player_uid_of(owner)
		if not player_uid.is_empty() and not players.has(player_uid):
			players[player_uid] = {}
		var parts: Dictionary = world if player_uid.is_empty() else players[player_uid]
		_add_part(parts, owner)
	return SaveDocuments.build_world(header, players, world)


## Two owners with one key in a scope would overwrite each other (R-010-07).
func _add_part(parts: Dictionary, owner: Node) -> void:
	var save_key: StringName = owner.call(&"get_save_key")
	var key: String = String(save_key)
	if parts.has(key):
		push_error("SaveManager: two owners share the save key '%s'; '%s' is not saved." % [key, owner.name])
		return
	var part: Dictionary = owner.call(&"to_save_data")
	parts[key] = part


## The player_uid of the player entity owner hangs from; "" for world state.
static func _player_uid_of(owner: Node) -> String:
	var node: Node = owner
	while node != null:
		if node.is_in_group(Robot.PLAYER_GROUP):
			var player_uid: String = node.get(&"player_uid")
			return player_uid
		node = node.get_parent()
	return ""


## Creation, not generation (spec question 9): never the global RNG.
static func _new_world_seed() -> int:
	return Crypto.new().generate_random_bytes(8).decode_s64(0)
