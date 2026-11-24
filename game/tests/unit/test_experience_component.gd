extends GutTest
## ExperienceComponent (spec 007): total XP of one player as an integer that
## starts at 0, with xp_changed (R-007-19); a kill by its owner adds the XP of
## that enemy's data, looked up in the catalog it is given (R-007-20); a
## negative amount or an unknown enemy reports an error and changes nothing
## (R-007-21). Catalogs are made by hand: the numbers are test inputs, not
## balance values. Spec 010: save and load (R-010-08, 09, 11, 24).
## Spec 014: chassis level from the total XP (R-014-05..11, 15, 17); the level
## table is the real chassis_levels.tres, so thresholds are read from it.

const OWNER_UID := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const OTHER_UID := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const ENEMY_ID := &"test_enemy"
const OTHER_ENEMY_ID := &"other_enemy"
const UNKNOWN_ID := &"nobody"
const REWARD := 4
const OTHER_REWARD := 9
const LEVELS_PATH := "res://resources/progression/chassis_levels.tres"

var _experience: ExperienceComponent
var _catalog: DataCatalog
var _levels: ChassisLevelData


func before_each() -> void:
	_experience = ExperienceComponent.new()
	_experience.name = "Experience"
	add_child_autofree(_experience)
	_levels = load(LEVELS_PATH) as ChassisLevelData
	_experience.set_level_table(_levels)
	watch_signals(_experience)
	_catalog = DataCatalog.new()
	var enemies: Array[EnemyData] = [_enemy(ENEMY_ID, REWARD), _enemy(OTHER_ENEMY_ID, OTHER_REWARD)]
	_catalog.enemies = enemies


func _enemy(id: StringName, xp_reward: int) -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	enemy.xp_reward = xp_reward
	return enemy


func test_r_007_19_starts_at_zero() -> void:
	assert_eq(_experience.get_total(), 0, "a new player has no XP")


func test_r_007_19_add_xp_accumulates() -> void:
	_experience.add_xp(3)
	_experience.add_xp(4)
	assert_eq(_experience.get_total(), 7, "the total is the sum")


func test_r_007_19_xp_changed_once_per_gain() -> void:
	_experience.add_xp(3)
	assert_signal_emit_count(_experience, "xp_changed", 1)
	assert_signal_emitted_with_parameters(_experience, "xp_changed", [3])
	_experience.add_xp(4)
	assert_signal_emit_count(_experience, "xp_changed", 2)
	assert_signal_emitted_with_parameters(_experience, "xp_changed", [7])


func test_r_007_19_zero_changes_nothing() -> void:
	_experience.add_xp(0)
	assert_eq(_experience.get_total(), 0, "no XP")
	assert_signal_not_emitted(_experience, "xp_changed", "and no signal")
	assert_push_error_count(0)


func test_r_007_20_reward_from_catalog() -> void:
	_experience.reward_kill(ENEMY_ID, OWNER_UID, OWNER_UID, _catalog)
	assert_eq(_experience.get_total(), REWARD, "the XP of that enemy's data")
	_experience.reward_kill(OTHER_ENEMY_ID, OWNER_UID, OWNER_UID, _catalog)
	assert_eq(_experience.get_total(), REWARD + OTHER_REWARD, "each enemy gives its own")
	assert_signal_emit_count(_experience, "xp_changed", 2)


func test_r_007_20_other_killer_ignored() -> void:
	_experience.reward_kill(ENEMY_ID, OTHER_UID, OWNER_UID, _catalog)
	assert_eq(_experience.get_total(), 0, "another player's kill gives nothing")
	_experience.reward_kill(UNKNOWN_ID, OTHER_UID, OWNER_UID, _catalog)
	assert_push_error_count(0)
	assert_signal_not_emitted(_experience, "xp_changed")


func test_r_007_20_kill_without_killer_ignored() -> void:
	_experience.reward_kill(ENEMY_ID, "", "", _catalog)
	assert_eq(_experience.get_total(), 0, "an empty uid is nobody, not this player")


func test_r_007_21_negative_reports_error() -> void:
	_experience.add_xp(5)
	_experience.add_xp(-2)
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 5, "nothing changed")
	assert_signal_emit_count(_experience, "xp_changed", 1, "only the valid gain was announced")


func test_r_007_21_unknown_enemy_reports_error() -> void:
	_experience.reward_kill(UNKNOWN_ID, OWNER_UID, OWNER_UID, _catalog)
	assert_push_error("nobody")
	assert_push_error_count(1)
	assert_eq(_experience.get_total(), 0, "nothing changed")
	assert_signal_not_emitted(_experience, "xp_changed")


func test_r_007_21_missing_catalog_reports_error() -> void:
	_experience.reward_kill(ENEMY_ID, OWNER_UID, OWNER_UID, null)
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 0, "nothing changed")


# --- Spec 008: reset (ruleset that does not keep XP) ---------------------------


func test_r_008_28_reset_sets_total_to_zero() -> void:
	_experience.add_xp(7)
	_experience.reset()
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 0, "the total is back to 0")
	assert_signal_emit_count(_experience, "xp_changed", 2, "one for the gain, one for the reset")
	assert_signal_emitted_with_parameters(_experience, "xp_changed", [0])
	_experience.add_xp(2)
	assert_eq(_experience.get_total(), 2, "it counts again from 0")


func test_r_008_28_reset_at_zero_emits_nothing() -> void:
	_experience.reset()
	assert_eq(_experience.get_total(), 0)
	assert_signal_not_emitted(_experience, "xp_changed", "nothing changed, nothing announced")
	assert_push_error_count(0)


# --- Spec 010: save and load (R-010-08, R-010-09, R-010-11, D15) ---------------


func test_r_010_08_save_key() -> void:
	assert_eq(ExperienceComponent.SAVE_KEY, &"experience", "const")
	assert_eq(_experience.get_save_key(), &"experience", "getter")


func test_r_010_08_save_data_is_the_total() -> void:
	_experience.add_xp(7)
	var data: Dictionary = _experience.to_save_data()
	assert_eq(data, {"total": 7}, "only the total")
	assert_eq(typeof(data["total"]), TYPE_INT, "a whole number")


func test_r_010_09_load_sets_total_and_emits_once() -> void:
	_experience.from_save_data({"total": 25})
	assert_eq(_experience.get_total(), 25, "loaded")
	assert_signal_emit_count(_experience, "xp_changed", 1)
	assert_signal_emitted_with_parameters(_experience, "xp_changed", [25])


func test_r_010_09_load_accepts_a_whole_float() -> void:
	_experience.from_save_data({"total": 25.0})
	assert_eq(_experience.get_total(), 25, "JSON gives floats")


func test_r_014_17_load_same_total_emits_state_again() -> void:
	_experience.add_xp(5)
	clear_signal_watcher()
	watch_signals(_experience)
	_experience.from_save_data({"total": 5})
	assert_signal_emit_count(_experience, "xp_changed", 1, "state is announced even if unchanged")
	assert_signal_emit_count(_experience, "level_changed", 1)
	assert_signal_not_emitted(_experience, "level_up")


func test_r_010_09_round_trip_experience() -> void:
	_experience.add_xp(12)
	var saved: Dictionary = _experience.to_save_data()
	var other: ExperienceComponent = ExperienceComponent.new()
	add_child_autofree(other)
	other.set_level_table(_levels)
	other.from_save_data(saved)
	assert_eq(other.get_total(), 12, "same total")
	assert_eq(other.to_save_data(), saved, "same data")


func test_r_010_11_load_negative_is_rejected() -> void:
	_experience.add_xp(3)
	clear_signal_watcher()
	watch_signals(_experience)
	_experience.from_save_data({"total": -1})
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 3, "unchanged")
	assert_signal_not_emitted(_experience, "xp_changed")


func test_r_010_11_load_fractional_is_rejected() -> void:
	_experience.from_save_data({"total": 2.5})
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 0, "unchanged")
	assert_signal_not_emitted(_experience, "xp_changed")


func test_r_010_11_load_missing_total_is_rejected() -> void:
	_experience.from_save_data({})
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 0, "unchanged")
	assert_signal_not_emitted(_experience, "xp_changed")


func test_r_010_11_load_non_number_is_rejected() -> void:
	_experience.from_save_data({"total": "9"})
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 0, "unchanged")
	assert_signal_not_emitted(_experience, "xp_changed")


# --- Spec 014: chassis level ---------------------------------------------------


func _record_order(component: ExperienceComponent, order: Array[String]) -> void:
	component.xp_changed.connect(func(_total: int) -> void: order.append("xp_changed"))
	component.level_changed.connect(func(_level: int) -> void: order.append("level_changed"))
	component.level_up.connect(func(_level: int) -> void: order.append("level_up"))


func test_r_014_05_no_table_stays_level_one() -> void:
	var bare: ExperienceComponent = ExperienceComponent.new()
	add_child_autofree(bare)
	bare.add_xp(_levels.get_xp_required(_levels.get_level_count()))
	assert_push_error("ChassisLevel")
	assert_eq(bare.get_total(), _levels.get_xp_required(_levels.get_level_count()), "XP still accumulates")
	assert_eq(bare.get_level(), ChassisLevelData.FIRST_LEVEL, "no table, no level")


func test_r_014_10_set_level_table_recomputes_without_level_up() -> void:
	var late: ExperienceComponent = ExperienceComponent.new()
	add_child_autofree(late)
	late.from_save_data({"total": _levels.get_xp_required(3)})
	assert_push_error("ChassisLevel")
	watch_signals(late)
	late.set_level_table(_levels)
	assert_eq(late.get_level(), 3, "level follows the current total")
	assert_signal_emit_count(late, "level_changed", 1)
	assert_signal_emitted_with_parameters(late, "level_changed", [3])
	assert_signal_not_emitted(late, "level_up")


func test_r_014_06_each_component_has_its_own_level() -> void:
	var other: ExperienceComponent = ExperienceComponent.new()
	add_child_autofree(other)
	other.set_level_table(_levels)
	_experience.add_xp(_levels.get_xp_required(2))
	assert_eq(_experience.get_level(), 2, "the one that gained XP levels up")
	assert_eq(other.get_level(), ChassisLevelData.FIRST_LEVEL, "the other does not")


func test_r_014_07_level_up_at_threshold() -> void:
	assert_eq(_experience.get_level(), ChassisLevelData.FIRST_LEVEL, "starts at the first level")
	_experience.add_xp(_levels.get_xp_required(2))
	assert_eq(_experience.get_level(), 2, "exactly the threshold is enough")
	assert_signal_emit_count(_experience, "level_up", 1)
	assert_signal_emitted_with_parameters(_experience, "level_up", [2])


func test_r_014_07_several_levels_one_signal_final_level() -> void:
	_experience.add_xp(_levels.get_xp_required(4))
	assert_eq(_experience.get_level(), 4)
	assert_signal_emit_count(_experience, "level_up", 1, "one signal per gain")
	assert_signal_emitted_with_parameters(_experience, "level_up", [4])
	assert_signal_emit_count(_experience, "level_changed", 1)


func test_r_014_07_level_changed_before_level_up() -> void:
	var order: Array[String] = []
	_record_order(_experience, order)
	_experience.add_xp(_levels.get_xp_required(2))
	assert_eq(order, ["xp_changed", "level_changed", "level_up"] as Array[String])


func test_r_014_09_below_threshold_no_level_up() -> void:
	_experience.add_xp(_levels.get_xp_required(2) - 1)
	assert_eq(_experience.get_level(), ChassisLevelData.FIRST_LEVEL)
	assert_signal_not_emitted(_experience, "level_up")
	assert_signal_not_emitted(_experience, "level_changed")
	assert_signal_emit_count(_experience, "xp_changed", 1, "the XP still counts")


func test_r_014_10_level_changed_on_level_up() -> void:
	_experience.add_xp(_levels.get_xp_required(2))
	assert_signal_emit_count(_experience, "level_changed", 1)
	assert_signal_emitted_with_parameters(_experience, "level_changed", [2])


func test_r_014_10_level_changed_on_load() -> void:
	_experience.from_save_data({"total": _levels.get_xp_required(3)})
	assert_eq(_experience.get_level(), 3)
	assert_signal_emit_count(_experience, "level_changed", 1)
	assert_signal_emitted_with_parameters(_experience, "level_changed", [3])


func test_r_014_11_reset_keeps_level_and_reports() -> void:
	_experience.add_xp(_levels.get_xp_required(2))
	_experience.reset()
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 0, "the total goes down")
	assert_eq(_experience.get_level(), 2, "the level is kept")


func test_r_014_11_lower_load_keeps_level_and_reports() -> void:
	_experience.add_xp(_levels.get_xp_required(3))
	_experience.from_save_data({"total": 1})
	assert_push_error("Experience")
	assert_eq(_experience.get_total(), 1, "the total goes down")
	assert_eq(_experience.get_level(), 3, "the level is kept")


func test_r_014_15_save_data_has_only_total() -> void:
	_experience.add_xp(_levels.get_xp_required(2))
	assert_eq(_experience.to_save_data(), {"total": _levels.get_xp_required(2)}, "the level is derived")


func test_r_014_17_load_emits_state_never_level_up() -> void:
	_experience.from_save_data({"total": _levels.get_xp_required(3)})
	assert_signal_emit_count(_experience, "xp_changed", 1)
	assert_signal_emit_count(_experience, "level_changed", 1)
	assert_signal_not_emitted(_experience, "level_up")
