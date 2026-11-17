class_name DataCatalog
extends Resource
## Explicit list of every data resource, indexed by id (architecture §8).
## Listed by hand instead of scanning folders: exported Android builds remap
## resource files, so a res:// listing is not reliable there.

@export var items: Array[ItemData] = []
@export var enemies: Array[EnemyData] = []
@export var rulesets: Array[RulesetData] = []

var _items_by_id: Dictionary[StringName, ItemData] = {}
var _enemies_by_id: Dictionary[StringName, EnemyData] = {}
var _rulesets_by_id: Dictionary[StringName, RulesetData] = {}
var _index_built: bool = false


## Builds the id indexes; returns one message per empty slot and per repeated
## or empty id. The first resource with an id keeps it. Each kind has its own
## index: an id only has to be unique within its kind.
func build_index() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	_index("items", items, _items_by_id, problems)
	_index("enemies", enemies, _enemies_by_id, problems)
	_index("rulesets", rulesets, _rulesets_by_id, problems)
	_index_built = true
	return problems


func has_item(id: StringName) -> bool:
	_ensure_index()
	return _items_by_id.has(id)


## Unknown id → push_error and null.
func get_item(id: StringName) -> ItemData:
	_ensure_index()
	if not _items_by_id.has(id):
		push_error("DataCatalog: unknown item id '%s'." % id)
		return null
	return _items_by_id[id]


func has_enemy(id: StringName) -> bool:
	_ensure_index()
	return _enemies_by_id.has(id)


## Unknown id → push_error and null.
func get_enemy(id: StringName) -> EnemyData:
	_ensure_index()
	if not _enemies_by_id.has(id):
		push_error("DataCatalog: unknown enemy id '%s'." % id)
		return null
	return _enemies_by_id[id]


func has_ruleset(id: StringName) -> bool:
	_ensure_index()
	return _rulesets_by_id.has(id)


## Unknown id → push_error and null.
func get_ruleset(id: StringName) -> RulesetData:
	_ensure_index()
	if not _rulesets_by_id.has(id):
		push_error("DataCatalog: unknown ruleset id '%s'." % id)
		return null
	return _rulesets_by_id[id]


## Fills by_id from resources, which all export an `id: StringName`. The data
## classes share no base class, so the id is read by name.
static func _index(
	kind: String, resources: Array, by_id: Dictionary, problems: PackedStringArray
) -> void:
	by_id.clear()
	for i: int in resources.size():
		var resource: Resource = resources[i]
		if resource == null:
			problems.append("%s[%d] is empty" % [kind, i])
			continue
		var id: StringName = resource.get(&"id")
		if id.is_empty():
			problems.append("%s[%d] (%s) has no id" % [kind, i, resource.resource_path])
		elif by_id.has(id):
			problems.append("%s[%d] repeats the id '%s'" % [kind, i, id])
		else:
			by_id[id] = resource


func _ensure_index() -> void:
	if _index_built:
		return
	for problem: String in build_index():
		push_error("DataCatalog: %s." % problem)
