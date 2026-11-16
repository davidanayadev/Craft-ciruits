extends GutTest
## ExperienceComponent (spec 007): total XP of one player as an integer that
## starts at 0, with xp_changed (R-007-19); a kill by its owner adds the XP of
## that enemy's data, looked up in the catalog it is given (R-007-20); a
## negative amount or an unknown enemy reports an error and changes nothing
## (R-007-21). Catalogs are made by hand: the numbers are test inputs, not
## balance values.

const OWNER_UID := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const OTHER_UID := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const ENEMY_ID := &"test_enemy"
const OTHER_ENEMY_ID := &"other_enemy"
const UNKNOWN_ID := &"nobody"
const REWARD := 4
const OTHER_REWARD := 9

var _experience: ExperienceComponent
var _catalog: DataCatalog


func before_each() -> void:
	_experience = ExperienceComponent.new()
	_experience.name = "Experience"
	add_child_autofree(_experience)
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
