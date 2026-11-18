extends GutTest
## Repair bench (spec 009): interactable through an InteractableComponent with
## a translation key in ES and EN (R-009-63); interacting is a request the
## base relays (bench_used), never an action of its own.
## Spec 011: crafting and repairing are the player's requests at the bench, which
## emits item_crafted and piece_repaired only when they succeed (R-011-13,
## R-011-14, R-011-19, R-011-20); the base gives its bench (BaseZone.get_bench).

const BENCH_SCENE := preload("res://scenes/base/repair_bench.tscn")
const BASE_SCENE := preload("res://scenes/base/base.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]

var _bench: RepairBench
var _user: Node3D


func before_each() -> void:
	_bench = BENCH_SCENE.instantiate() as RepairBench
	add_child_autofree(_bench)
	_user = Node3D.new()
	add_child_autofree(_user)


func test_r_009_63_interactable_with_key() -> void:
	var interactable: InteractableComponent = _bench.get_node("%Interactable") as InteractableComponent
	assert_not_null(interactable, "the bench has an InteractableComponent")
	if interactable == null:
		return
	assert_eq(interactable.prompt_key, &"PROMPT_USE", "prompt key")
	for locale: String in SUPPORTED_LOCALES:
		var text: String = ""
		for translation: Translation in TranslationServer.find_translations(locale, true):
			text = translation.get_message(&"PROMPT_USE")
			if not text.is_empty():
				break
		assert_ne(text, "", "PROMPT_USE translated in %s" % locale)
	watch_signals(_bench)
	interactable.interact(_user)
	assert_signal_emit_count(_bench, "used", 1, "one request per interaction")
	assert_signal_emitted_with_parameters(_bench, "used", [_user])


func test_r_009_63_base_relays_bench_use() -> void:
	var base: BaseZone = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(base)
	watch_signals(base)
	var bench: Node = base.get_node("%RepairBench")
	(bench.get_node("Interactable") as InteractableComponent).interact(_user)
	assert_signal_emitted_with_parameters(base, "bench_used", [_user])


# --- Crafting and repairing at the bench (spec 011) ---------------------------


func _new_robot() -> Robot:
	var robot: Robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(robot)
	robot.set_physics_process(false)
	return robot


## A crafted basic arms piece at durability, already in robot's inventory.
func _give_damaged_arms(robot: Robot, durability: int) -> ItemStack:
	var piece: ItemStack = CraftingSystem.create_result(DataRegistry.get_item(&"basic_arms"))
	piece.durability = durability
	var offered: Array[ItemStack] = [piece]
	assert_true(robot.inventory.add_stacks(offered).ok, "the damaged piece is in the inventory")
	return piece


func test_r_011_13_bench_craft_emits_item_crafted() -> void:
	var robot: Robot = _new_robot()
	robot.inventory.add(&"scrap", 4)
	robot.inventory.add(&"cables", 2)
	watch_signals(EventBus)
	var result: ActionResult = _bench.craft(robot, DataRegistry.get_recipe(&"basic_arms"))
	assert_true(result.ok, "crafted")
	assert_eq(robot.inventory.count(&"basic_arms"), 1, "the piece is in the inventory")
	assert_signal_emit_count(EventBus, "item_crafted", 1, "once per craft")
	assert_signal_emitted_with_parameters(EventBus, "item_crafted", [&"basic_arms", robot.player_uid])


func test_r_011_14_failed_craft_emits_nothing() -> void:
	var robot: Robot = _new_robot()
	robot.inventory.add(&"scrap", 3)
	watch_signals(EventBus)
	var result: ActionResult = _bench.craft(robot, DataRegistry.get_recipe(&"basic_arms"))
	assert_false(result.ok, "not enough materials")
	assert_eq(result.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS, "with its reason")
	assert_signal_not_emitted(EventBus, "item_crafted", "no event for a refused craft")


func test_r_011_14_bench_rejects_bad_requests() -> void:
	var robot: Robot = _new_robot()
	robot.inventory.add(&"scrap", 20)
	watch_signals(EventBus)
	var no_player: ActionResult = _bench.craft(null, DataRegistry.get_recipe(&"basic_arms"))
	assert_eq(no_player.error_key, InventoryComponent.ERR_INVALID_REQUEST, "no player")
	var by_hand: RecipeData = DataRegistry.get_recipe(&"basic_arms").duplicate() as RecipeData
	by_hand.station = RecipeData.Station.SELF
	var wrong_station: ActionResult = _bench.craft(robot, by_hand)
	assert_eq(wrong_station.error_key, InventoryComponent.ERR_INVALID_REQUEST, "not a workbench recipe")
	assert_push_error_count(2)
	assert_eq(robot.inventory.count(&"scrap"), 20, "nothing was charged")
	assert_signal_not_emitted(EventBus, "item_crafted")


func test_r_011_19_bench_repair_emits_piece_repaired() -> void:
	var robot: Robot = _new_robot()
	var piece: ItemStack = _give_damaged_arms(robot, 50)
	robot.inventory.add(&"iron", 2)
	robot.inventory.add(&"cables", 1)
	watch_signals(EventBus)
	var result: ActionResult = _bench.repair(robot, piece.uid)
	assert_true(result.ok, "repaired with the catalog's repair costs")
	assert_eq(robot.inventory.count(&"iron"), 0, "the damaged tier was paid (BALANCE §4.3.2)")
	assert_eq(robot.inventory.count(&"cables"), 0, "the damaged tier was paid (BALANCE §4.3.2)")
	assert_signal_emit_count(EventBus, "piece_repaired", 1, "once per repair")
	assert_signal_emitted_with_parameters(EventBus, "piece_repaired", [piece.uid, robot.player_uid])


func test_r_011_20_failed_repair_emits_nothing() -> void:
	var robot: Robot = _new_robot()
	var piece: ItemStack = _give_damaged_arms(robot, 50)
	watch_signals(EventBus)
	var result: ActionResult = _bench.repair(robot, piece.uid)
	assert_eq(result.error_key, CraftingSystem.ERR_NOT_ENOUGH_MATERIALS, "nothing to pay with")
	assert_signal_not_emitted(EventBus, "piece_repaired", "no event for a refused repair")


func test_r_011_21_base_gives_its_bench() -> void:
	var base: BaseZone = BASE_SCENE.instantiate() as BaseZone
	add_child_autofree(base)
	assert_same(base.get_bench(), base.get_node("%RepairBench"), "get_bench returns the base's bench")
