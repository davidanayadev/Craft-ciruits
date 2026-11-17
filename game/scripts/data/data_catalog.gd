class_name DataCatalog
extends Resource
## Explicit list of every data resource, indexed by id (architecture §8).
## Listed by hand instead of scanning folders: exported Android builds remap
## resource files, so a res:// listing is not reliable there.

@export var items: Array[ItemData] = []
@export var enemies: Array[EnemyData] = []
@export var rulesets: Array[RulesetData] = []
## The ruleset of a World created by the game (spec 010, R-010-19); one of rulesets.
@export var new_world_ruleset: RulesetData
## Indexed by zone_id, the stable id of a zone (spec 009).
@export var zones: Array[ZoneData] = []
@export var structures: Array[StructureData] = []
@export var recipes: Array[RecipeData] = []

var _items_by_id: Dictionary[StringName, ItemData] = {}
var _enemies_by_id: Dictionary[StringName, EnemyData] = {}
var _rulesets_by_id: Dictionary[StringName, RulesetData] = {}
var _zones_by_id: Dictionary[Vector2i, ZoneData] = {}
var _base_zone: ZoneData = null
var _structures_by_id: Dictionary[StringName, StructureData] = {}
var _recipes_by_id: Dictionary[StringName, RecipeData] = {}
var _index_built: bool = false


## Builds the id indexes; returns one message per empty slot and per repeated
## or empty id. The first resource with an id keeps it. Each kind has its own
## index: an id only has to be unique within its kind. A catalog that lists
## zones must have exactly one BASE zone.
func build_index() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	_index("items", items, _items_by_id, problems)
	_index("enemies", enemies, _enemies_by_id, problems)
	_index("rulesets", rulesets, _rulesets_by_id, problems)
	_index_zones(problems)
	_index("structures", structures, _structures_by_id, problems)
	_index("recipes", recipes, _recipes_by_id, problems)
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


func has_zone(zone_id: Vector2i) -> bool:
	_ensure_index()
	return _zones_by_id.has(zone_id)


## Unknown zone_id → push_error and null.
func get_zone(zone_id: Vector2i) -> ZoneData:
	_ensure_index()
	if not _zones_by_id.has(zone_id):
		push_error("DataCatalog: unknown zone id %s." % zone_id)
		return null
	return _zones_by_id[zone_id]


## The only BASE zone, so no script writes its zone_id. None → push_error and null.
func get_base_zone() -> ZoneData:
	_ensure_index()
	if _base_zone == null:
		push_error("DataCatalog: there is no BASE zone.")
	return _base_zone


func has_structure(id: StringName) -> bool:
	_ensure_index()
	return _structures_by_id.has(id)


## Unknown id → push_error and null.
func get_structure(id: StringName) -> StructureData:
	_ensure_index()
	if not _structures_by_id.has(id):
		push_error("DataCatalog: unknown structure id '%s'." % id)
		return null
	return _structures_by_id[id]


func has_recipe(id: StringName) -> bool:
	_ensure_index()
	return _recipes_by_id.has(id)


## Unknown id → push_error and null.
func get_recipe(id: StringName) -> RecipeData:
	_ensure_index()
	if not _recipes_by_id.has(id):
		push_error("DataCatalog: unknown recipe id '%s'." % id)
		return null
	return _recipes_by_id[id]


## Every listed recipe, in catalog order; the caller can not change the catalog through it.
func get_recipes() -> Array[RecipeData]:
	_ensure_index()
	var listed: Array[RecipeData] = []
	for recipe: RecipeData in _recipes_by_id.values():
		listed.append(recipe)
	return listed


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


## Zones are indexed by zone_id (a Vector2i), not by a text id.
func _index_zones(problems: PackedStringArray) -> void:
	_zones_by_id.clear()
	_base_zone = null
	var base_count: int = 0
	for i: int in zones.size():
		var zone: ZoneData = zones[i]
		if zone == null:
			problems.append("zones[%d] is empty" % i)
			continue
		if _zones_by_id.has(zone.zone_id):
			problems.append("zones[%d] repeats the zone id %s" % [i, zone.zone_id])
			continue
		_zones_by_id[zone.zone_id] = zone
		if zone.kind == ZoneData.Kind.BASE:
			base_count += 1
			if _base_zone == null:
				_base_zone = zone
	if not zones.is_empty() and base_count != 1:
		problems.append("zones has %d BASE zones instead of 1" % base_count)


func _ensure_index() -> void:
	if _index_built:
		return
	for problem: String in build_index():
		push_error("DataCatalog: %s." % problem)
