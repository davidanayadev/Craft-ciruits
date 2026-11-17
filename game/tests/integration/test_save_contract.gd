extends GutTest
## The serialization contract of spec 010 in the real main scene (R-010-06,
## R-010-07, R-010-08): every owner of persisted state is in the "persistent"
## group, has the three methods, has a key of its own within its scope and
## gives only JSON types. The scene is filled first (inventory with a stack
## that has durability and uid, a placed structure, a visit counter, a dropped
## item and an opened box), so the walk of R-010-08 sees real data.
## Player scope = under a node of the "players" group; every other owner is
## world scope (plan 010 §1).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const GREEN_ZONE_ID := Vector2i(0, 0)
const STATION_CELL := Vector2i(9, 2)
const TRAVEL_TIMEOUT_S := 10.0
const STACK_DURABILITY := 40
const SCRAP_QUANTITY := 12
const CABLES_QUANTITY := 2
const METHODS: Array[StringName] = [&"get_save_key", &"to_save_data", &"from_save_data"]
const PLAYER_KEYS: Array[StringName] = [&"battery", &"inventory", &"experience", &"location"]
const WORLD_KEYS: Array[StringName] = [
	&"zone_visits", &"farm_visits", &"dropped_items", &"structures"
]
const FORBIDDEN_PREFIXES: Array[String] = ["res://", "user://"]

var _main: Node
var _robot: Robot


func before_each() -> void:
	SaveTestSupport.start_world()
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)
	_robot = _main.get_node("%Robot") as Robot
	await _await_travel()
	await _fill_state()


func after_each() -> void:
	SaveTestSupport.reset()


func _loader() -> ZoneLoader:
	return _main.get_node("%ZoneLoader") as ZoneLoader


func _await_travel() -> void:
	if _loader().is_travelling():
		await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)


## Inventory, structure, visit counter and dropped item in the base, then the
## green zone with one opened box.
func _fill_state() -> void:
	var scrap: ItemStack = ItemStack.new(DataRegistry.get_item(&"scrap"), SCRAP_QUANTITY)
	scrap.durability = STACK_DURABILITY
	scrap.uid = Uid.generate()
	var carried: Array[ItemStack] = [scrap]
	_robot.inventory.add_stacks(carried)
	var structures: BaseStructures = _main.get_node("%BaseStructures") as BaseStructures
	var placed: ActionResult = structures.place(
		_robot, DataRegistry.get_recipe(&"charging_station"), STATION_CELL
	)
	assert_true(placed.ok, "the station is placed")
	GameManager.increment_visit_count(GREEN_ZONE_ID)
	await _travel_to_green_zone()
	var left: Array[ItemStack] = [ItemStack.new(DataRegistry.get_item(&"cables"), CABLES_QUANTITY)]
	var dropped: DroppedItem = (_main.get_node("%DroppedItems") as DroppedItemSpawner).drop_stacks(
		left, _robot.global_position
	)
	assert_not_null(dropped, "an item is on the ground")
	var farm: FarmZone = _loader().get_current_zone() as FarmZone
	var box: LootBox = farm.get_boxes()[0]
	(box.get_node("%Interactable") as InteractableComponent).interact(_robot)
	(_main.get_node("%UIManager") as UIManager).close_all()


func _travel_to_green_zone() -> void:
	await _await_travel()
	_loader().travel_to(GREEN_ZONE_ID)
	await wait_for_signal(_loader().travel_finished, TRAVEL_TIMEOUT_S)


## Every owner of the running game: the persistent nodes of Main and the
## GameManager autoload.
func _owners() -> Array[Node]:
	var owners: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(SaveDocuments.PERSISTENT_GROUP):
		if node == GameManager or _main.is_ancestor_of(node):
			owners.append(node)
	return owners


func _is_player_scoped(node: Node) -> bool:
	var ancestor: Node = node.get_parent()
	while ancestor != null:
		if ancestor.is_in_group(Robot.PLAYER_GROUP):
			return true
		ancestor = ancestor.get_parent()
	return false


func _key_of(owner_node: Node) -> StringName:
	var key: StringName = owner_node.call(&"get_save_key")
	return key


## Only JSON types, dictionaries keyed by String, no resource or file path.
func _check_json_value(value: Variant, path: String) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			pass
		TYPE_STRING:
			var text: String = value
			for prefix: String in FORBIDDEN_PREFIXES:
				assert_false(text.begins_with(prefix), "%s is a path: '%s'" % [path, text])
		TYPE_ARRAY:
			var list: Array = value
			for index: int in list.size():
				_check_json_value(list[index], "%s[%d]" % [path, index])
		TYPE_DICTIONARY:
			var fields: Dictionary = value
			for key: Variant in fields:
				assert_eq(typeof(key), TYPE_STRING, "%s has a key that is not a String: %s" % [path, key])
				_check_json_value(fields[key], "%s.%s" % [path, key])
		_:
			fail_test("%s has the type %s, which JSON cannot hold" % [path, type_string(typeof(value))])


func test_r_010_06_player_components_in_group() -> void:
	var group: StringName = SaveDocuments.PERSISTENT_GROUP
	assert_true(_robot.battery.is_in_group(group), "BatteryComponent")
	assert_true(_robot.inventory.is_in_group(group), "InventoryComponent")
	assert_true(_robot.experience.is_in_group(group), "ExperienceComponent")
	assert_true(_robot.location.is_in_group(group), "LocationComponent")


func test_r_010_07_every_owner_has_the_methods() -> void:
	var owners: Array[Node] = _owners()
	assert_gte(owners.size(), PLAYER_KEYS.size() + WORLD_KEYS.size(), "every owner of the game is found")
	var keys: Array[StringName] = []
	for owner_node: Node in owners:
		for method: StringName in METHODS:
			assert_true(owner_node.has_method(method), "%s lacks %s()" % [owner_node.get_path(), method])
		if owner_node.has_method(&"get_save_key"):
			keys.append(_key_of(owner_node))
	for key: StringName in PLAYER_KEYS + WORLD_KEYS:
		assert_true(keys.has(key), "an owner of '%s' is in the group" % key)
	assert_true(owners.has(GameManager), "GameManager is an owner too")


func test_r_010_07_keys_unique_per_scope() -> void:
	var player_keys: Array[StringName] = []
	var world_keys: Array[StringName] = []
	for owner_node: Node in _owners():
		if not owner_node.has_method(&"get_save_key"):
			continue
		if _is_player_scoped(owner_node):
			player_keys.append(_key_of(owner_node))
		else:
			world_keys.append(_key_of(owner_node))
	assert_eq(SaveDocuments.find_repeated_keys(player_keys), PackedStringArray(), "player keys")
	assert_eq(SaveDocuments.find_repeated_keys(world_keys), PackedStringArray(), "world keys")
	for key: StringName in PLAYER_KEYS:
		assert_true(player_keys.has(key), "'%s' is a player key" % key)
	for key: StringName in WORLD_KEYS:
		assert_true(world_keys.has(key), "'%s' is a world key" % key)


func test_r_010_08_only_json_types() -> void:
	var inventory_part: Dictionary = _robot.inventory.to_save_data()
	assert_false(inventory_part.is_empty(), "the inventory has data to walk")
	for owner_node: Node in _owners():
		if not owner_node.has_method(&"to_save_data"):
			continue
		var data: Dictionary = owner_node.call(&"to_save_data")
		_check_json_value(data, "%s" % _key_of(owner_node))
