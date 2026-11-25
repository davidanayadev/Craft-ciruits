extends GutTest
## DroppedItemFlow (spec 015): a dropped item opened by the local player opens
## the container screen on its contents and the player's inventory (R-015-45),
## stacks move both ways, pieces keep uid and durability (R-015-46), the screen
## closes when the item expires and what was moved stays (R-015-49), and an item
## emptied by the player is released once the screen closes, never while it is
## open (R-015-50). Times come from a FakeTimeService.

const UI_MANAGER_SCENE := preload("res://scenes/ui/ui_manager.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const ITEM_SCENE := preload("res://scenes/entities/dropped_item.tscn")
const SCREENS_PATH := "res://resources/ui/screens.tres"
const CONFIG_PATH := "res://resources/config/dropped_items.tres"
const ZONE_ID := Vector2i(0, 0)
const START_TIME := 1_700_000_000
const SCRAP := &"scrap"
const IRON := &"iron"
const CABLES := &"cables"

var _manager: UIManager
var _robot: Robot
var _pool: ObjectPool
var _spawner: DroppedItemSpawner
var _flow: DroppedItemFlow
var _clock: FakeTimeService
var _config: DroppedItemConfigData
var _zone_root: Node3D


func before_each() -> void:
	_config = load(CONFIG_PATH) as DroppedItemConfigData
	_manager = UI_MANAGER_SCENE.instantiate() as UIManager
	_manager.catalog = load(SCREENS_PATH) as UIScreenCatalog
	add_child_autofree(_manager)
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_clock = FakeTimeService.new()
	_clock.now = START_TIME
	_zone_root = Node3D.new()
	add_child_autofree(_zone_root)
	_pool = ObjectPool.new()
	_pool.scene = ITEM_SCENE
	add_child_autofree(_pool)
	_spawner = DroppedItemSpawner.new()
	_spawner.pool = _pool
	_spawner.config = _config
	_spawner.time_service = _clock
	add_child_autofree(_spawner)
	_spawner.bind_zone(ZONE_ID, _zone_root)
	_flow = DroppedItemFlow.new()
	_flow.ui_manager = _manager
	_flow.dropped_items = _spawner
	add_child_autofree(_flow)
	_flow.bind(_robot)


func _stack(item_id: StringName, quantity: int) -> ItemStack:
	return ItemStack.new(DataRegistry.get_item(item_id), quantity)


func _piece(durability: int) -> ItemStack:
	var piece: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(&"basic_arms"))
	piece.durability = durability
	return piece


## An item on the ground with scrap in slot 0 and iron in slot 1.
func _drop_two() -> DroppedItem:
	var stacks: Array[ItemStack] = [_stack(SCRAP, 3), _stack(IRON, 2)]
	var item: DroppedItem = _spawner.drop_stacks(stacks, Vector3.ZERO)
	assert_not_null(item, "test setup: the item was dropped")
	return item


func _interact(item: DroppedItem, who: Node3D) -> void:
	(item.get_node("%Interactable") as InteractableComponent).interact(who)


func _container_screen() -> ContainerScreen:
	for child: Node in _manager.get_children():
		var screen: ContainerScreen = child as ContainerScreen
		if screen != null and not screen.is_queued_for_deletion():
			return screen
	return null


## The screen opened by the robot on item; fails the test when there is none.
func _open(item: DroppedItem) -> ContainerScreen:
	_interact(item, _robot)
	var screen: ContainerScreen = _container_screen()
	assert_not_null(screen, "the container screen is open")
	return screen


func _tap_container(screen: ContainerScreen, index: int) -> void:
	(screen.get_node("%ContainerGrid") as InventoryGrid).slot_pressed.emit(index)


func _tap_player(screen: ContainerScreen, index: int) -> void:
	(screen.get_node("%PlayerGrid") as InventoryGrid).slot_pressed.emit(index)


func _press(screen: ContainerScreen, button: String) -> void:
	(screen.get_node("%" + button) as Button).pressed.emit()


func _stacks_in(item: DroppedItem) -> int:
	return InventoryRules.count_used_slots(item.get_contents().get_slots())


func test_r_015_45_opens_container_screen_with_header() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	var title: Label = screen.get_node("%Title") as Label
	assert_eq(title.text, String(ContainerScreen.DROPPED_TITLE_KEY), "titled as dropped items")
	var header: Label = screen.get_node("%ContainerHeader") as Label
	var expected: String = tr(&"CONTAINER_HEADER_DROPPED") % [2, item.get_contents().get_slot_count()]
	assert_eq(header.text, expected, "used over total slots of the item")
	var grid: InventoryGrid = screen.get_node("%ContainerGrid") as InventoryGrid
	assert_eq(grid.get_child_count(), item.get_contents().get_slot_count(), "the item's slots")
	assert_true(_manager.is_modal_open(), "a modal screen")
	assert_eq(_stacks_in(item), 2, "opening takes nothing")
	assert_true(_spawner.get_items().has(item), "the item stays")


func test_r_015_45_other_opener_opens_nothing() -> void:
	var item: DroppedItem = _drop_two()
	var stranger: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(stranger)
	stranger.set_physics_process(false)
	_interact(item, stranger)
	assert_false(_manager.is_modal_open(), "another player's interaction opens nothing here")
	assert_eq(_stacks_in(item), 2, "and takes nothing")


func test_r_015_46_take_all_in_slot_order() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_press(screen, "TakeAllButton")
	assert_eq(_robot.inventory.count(SCRAP), 3, "the scrap moved")
	assert_eq(_robot.inventory.count(IRON), 2, "the iron moved")
	assert_true(item.get_contents().is_empty(), "the item is empty")


func test_r_015_46_take_one_chosen_stack() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_tap_container(screen, 1)
	_press(screen, "MoveButton")
	assert_eq(_robot.inventory.count(IRON), 2, "the chosen stack is in the inventory")
	assert_eq(_robot.inventory.count(SCRAP), 0, "the other stays")
	assert_eq(item.get_contents().count(SCRAP), 3, "on the ground")
	assert_null(item.get_contents().get_slots()[1], "the emptied slot is free")


func test_r_015_46_leave_a_robot_stack_in_the_item() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_tap_container(screen, 0)
	_press(screen, "MoveButton")
	assert_true(_robot.inventory.add(CABLES, 4).ok, "test setup: the robot carries cables")
	var cables_slot: int = -1
	var slots: Array[ItemStack] = _robot.inventory.get_slots()
	for index: int in slots.size():
		if slots[index] != null and slots[index].item.id == CABLES:
			cables_slot = index
	_tap_player(screen, cables_slot)
	_press(screen, "MoveButton")
	assert_eq(item.get_contents().count(CABLES), 4, "the robot's stack was left in the item")
	assert_eq(_robot.inventory.count(CABLES), 0, "and left the robot")
	assert_eq(item.get_contents().get_slot_count(), 2, "the item did not grow")


func test_r_015_46_piece_keeps_uid_and_durability_both_ways() -> void:
	var piece: ItemStack = _piece(40)
	var stacks: Array[ItemStack] = [piece, _stack(SCRAP, 1)]
	var item: DroppedItem = _spawner.drop_stacks(stacks, Vector3.ZERO)
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_tap_container(screen, 0)
	_press(screen, "MoveButton")
	var robot_slot: int = InventoryRules.index_of_uid(_robot.inventory.get_slots(), piece.uid)
	assert_ne(robot_slot, -1, "the piece is in the inventory")
	if robot_slot == -1:
		return
	var taken: ItemStack = _robot.inventory.get_slots()[robot_slot]
	assert_eq(taken.durability, 40, "durability kept when taken")
	_tap_player(screen, robot_slot)
	_press(screen, "MoveButton")
	var item_slot: int = InventoryRules.index_of_uid(item.get_contents().get_slots(), piece.uid)
	assert_ne(item_slot, -1, "the piece is back in the item")
	if item_slot != -1:
		assert_eq(item.get_contents().get_slots()[item_slot].durability, 40, "durability kept when left")
	assert_eq(InventoryRules.index_of_uid(_robot.inventory.get_slots(), piece.uid), -1, "and not duplicated")


func test_r_015_49_expiry_closes_screen_keeps_taken() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_tap_container(screen, 0)
	_press(screen, "MoveButton")
	_clock.now = START_TIME + _config.lifetime_s
	_spawner.discard_expired_now()
	assert_false(_manager.is_modal_open(), "the screen closed with the item")
	assert_false(_spawner.get_items().has(item), "the item is gone")
	assert_eq(_robot.inventory.count(SCRAP), 3, "what was moved stays in the inventory")
	assert_eq(_robot.inventory.count(IRON), 0, "what was not moved is lost")
	await wait_process_frames(2)
	assert_eq(_pool.get_free_count(), 1, "released once, not twice")


func test_r_015_49_unloading_the_zone_closes_the_screen() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_spawner.unbind_zone()
	assert_false(_manager.is_modal_open(), "the screen closed with the item")
	await wait_process_frames(2)
	assert_eq(_spawner.get_items().size(), 0, "no item left")


func test_r_015_50_empty_released_on_close() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_press(screen, "TakeAllButton")
	var free_before: int = _pool.get_free_count()
	_manager.close_top()
	await wait_process_frames(2)
	assert_false(_spawner.get_items().has(item), "the emptied item was released")
	assert_eq(_pool.get_free_count(), free_before + 1, "back in the pool")


func test_r_015_50_stays_open_while_empty() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_press(screen, "TakeAllButton")
	await wait_process_frames(2)
	assert_true(item.get_contents().is_empty(), "test setup: emptied while open")
	assert_true(_spawner.get_items().has(item), "it stays listed while its screen is open")
	assert_true(_manager.is_modal_open(), "the screen stays open")
	assert_eq(item.get_contents().get_slot_count(), 2, "with its free slots")


func test_r_015_50_not_empty_stays_after_close() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_tap_container(screen, 0)
	_press(screen, "MoveButton")
	_manager.close_top()
	await wait_process_frames(2)
	assert_true(_spawner.get_items().has(item), "an item with a stack stays")
	assert_eq(item.get_contents().count(IRON), 2, "with what is left")
	_interact(item, _robot)
	assert_not_null(_container_screen(), "and can be opened again")


func test_r_015_50_left_stack_keeps_item_alive_after_close() -> void:
	var item: DroppedItem = _drop_two()
	var screen: ContainerScreen = _open(item)
	if screen == null:
		return
	_press(screen, "TakeAllButton")
	assert_true(_robot.inventory.add(CABLES, 1).ok, "test setup")
	var slots: Array[ItemStack] = _robot.inventory.get_slots()
	for index: int in slots.size():
		if slots[index] != null and slots[index].item.id == CABLES:
			_tap_player(screen, index)
	_press(screen, "MoveButton")
	_manager.close_top()
	await wait_process_frames(2)
	assert_true(_spawner.get_items().has(item), "an item the player left a stack in stays")
	assert_eq(item.get_contents().count(CABLES), 1, "with the left stack")
