extends Node
## Autoload "DataRegistry": loads the data catalog at start-up and returns
## data by id (architecture §5, §8). The lookup logic lives in DataCatalog so
## it can be tested with hand-made catalogs. No class_name: it would clash
## with the autoload name.

const CATALOG_PATH := "res://resources/data_catalog.tres"

var _catalog: DataCatalog


func _ready() -> void:
	_catalog = load(CATALOG_PATH) as DataCatalog
	if _catalog == null:
		push_error("DataRegistry: %s is missing or is not a DataCatalog." % CATALOG_PATH)
		return
	for problem: String in _catalog.build_index():
		push_error("DataRegistry: %s." % problem)


func get_catalog() -> DataCatalog:
	return _catalog


## Unknown id → push_error and null.
func get_item(id: StringName) -> ItemData:
	if _catalog == null:
		push_error("DataRegistry: no catalog loaded; cannot return item '%s'." % id)
		return null
	return _catalog.get_item(id)


## Unknown id → push_error and null.
func get_enemy(id: StringName) -> EnemyData:
	if _catalog == null:
		push_error("DataRegistry: no catalog loaded; cannot return enemy '%s'." % id)
		return null
	return _catalog.get_enemy(id)


## Unknown id → push_error and null.
func get_ruleset(id: StringName) -> RulesetData:
	if _catalog == null:
		push_error("DataRegistry: no catalog loaded; cannot return ruleset '%s'." % id)
		return null
	return _catalog.get_ruleset(id)
