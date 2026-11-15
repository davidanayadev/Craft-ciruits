class_name DataCatalog
extends Resource
## Explicit list of every data resource, indexed by id (architecture §8).
## Listed by hand instead of scanning folders: exported Android builds remap
## resource files, so a res:// listing is not reliable there.

@export var items: Array[ItemData] = []

var _items_by_id: Dictionary[StringName, ItemData] = {}
var _index_built: bool = false


## Builds the id index; returns one message per empty slot and per repeated or
## empty id. The first resource with an id keeps it.
func build_index() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
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


func _ensure_index() -> void:
	if _index_built:
		return
	for problem: String in build_index():
		push_error("DataCatalog: %s." % problem)
