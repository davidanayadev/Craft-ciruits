class_name DataCatalog
extends Resource
## Explicit list of every data resource, indexed by id (architecture §8).
## Listed by hand instead of scanning folders: exported Android builds remap
## resource files, so a res:// listing is not reliable there.

@export var items: Array[ItemData] = []
@export var enemies: Array[EnemyData] = []

var _items_by_id: Dictionary[StringName, ItemData] = {}
var _enemies_by_id: Dictionary[StringName, EnemyData] = {}
var _index_built: bool = false


## Builds the id indexes; returns one message per empty slot and per repeated
## or empty id. The first resource with an id keeps it. Items and enemies have
## separate indexes: an id only has to be unique within its kind.
func build_index() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	_index_items(problems)
	_index_enemies(problems)
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


func _index_items(problems: PackedStringArray) -> void:
	_items_by_id.clear()
	for i: int in items.size():
		var item: ItemData = items[i]
		if item == null:
			problems.append("items[%d] is empty" % i)
		elif item.id.is_empty():
			problems.append("items[%d] (%s) has no id" % [i, item.resource_path])
		elif _items_by_id.has(item.id):
			problems.append("items[%d] repeats the id '%s'" % [i, item.id])
		else:
			_items_by_id[item.id] = item


# Same shape as _index_items: ItemData and EnemyData share no base class, and
# the abstraction waits for the third kind (constitution P2).
func _index_enemies(problems: PackedStringArray) -> void:
	_enemies_by_id.clear()
	for i: int in enemies.size():
		var enemy: EnemyData = enemies[i]
		if enemy == null:
			problems.append("enemies[%d] is empty" % i)
		elif enemy.id.is_empty():
			problems.append("enemies[%d] (%s) has no id" % [i, enemy.resource_path])
		elif _enemies_by_id.has(enemy.id):
			problems.append("enemies[%d] repeats the id '%s'" % [i, enemy.id])
		else:
			_enemies_by_id[enemy.id] = enemy


func _ensure_index() -> void:
	if _index_built:
		return
	for problem: String in build_index():
		push_error("DataCatalog: %s." % problem)
