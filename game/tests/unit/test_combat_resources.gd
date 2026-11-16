extends GutTest
## Combat data (spec 007): the two attacks match BALANCE §4.2 (R-007-01), the
## hitbox, impact and feedback values live in resources with the values of
## BALANCE §11 "Combate" and never as script literals (R-007-04), no attack
## file can leave the robot without an attack (R-007-05) and one arm can kill
## both zombies (R-007-28).
## The expected values mirror BALANCE.md §4.2 and §11; update both together.

const COMBAT_DIR := "res://resources/combat"
const ENEMIES_DIR := "res://resources/enemies"
const ONE_ARM_PATH := "res://resources/combat/one_arm.tres"
const BASIC_ARMS_PATH := "res://resources/combat/basic_arms.tres"
const COMBAT_CONFIG_PATH := "res://resources/config/combat.tres"
const FEEDBACK_PATH := "res://resources/config/combat_feedback.tres"
const ZOMBIE_AI_PATH := "res://resources/ai/zombie_ai.tres"
## enemy id → hits of one arm to kill it: HP of BALANCE §3.1 / damage of §4.2.
const EXPECTED_ONE_ARM_HITS: Dictionary[StringName, int] = {&"zombie_slow": 4, &"zombie_fast": 3}
const GAME_CODE_DIRS: Array[String] = ["res://scripts", "res://scenes"]
## Data scripts declare the fields with their neutral default.
const DATA_DIR := "res://scripts/data"
const COMBAT_FIELDS_PATTERN := (
	"(?<![\\w.])(damage|attacks_per_second|battery_cost|xp_reward|hitbox_reach_m|hitbox_width_m"
	+ "|impact_time_s|enemy_flash_s|hit_dealt_shake_m|hit_dealt_shake_s|hit_received_shake_m"
	+ "|hit_received_shake_s|screen_edge_flash_s)\\s*(:\\s*\\w+\\s*)?:?=\\s*-?\\d"
)


func _load_attack(path: String) -> AttackStatsData:
	return load(path) as AttackStatsData


## Resource paths of a folder. Exported builds list "name.tres.remap".
func _resource_paths(dir_path: String) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(dir_path):
		paths.append(dir_path.path_join(file.trim_suffix(".remap")))
	return paths


func _collect_scripts(dir_path: String) -> PackedStringArray:
	var scripts: PackedStringArray = PackedStringArray()
	if dir_path == DATA_DIR:
		return scripts
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			scripts.append(dir_path.path_join(file))
	for dir: String in DirAccess.get_directories_at(dir_path):
		scripts.append_array(_collect_scripts(dir_path.path_join(dir)))
	return scripts


func test_r_007_01_one_arm_matches_balance() -> void:
	var attack: AttackStatsData = _load_attack(ONE_ARM_PATH)
	assert_not_null(attack, "one_arm.tres exists and is an AttackStatsData")
	if attack == null:
		return
	assert_eq(attack.damage, 5, "damage of one arm (BALANCE §4.2)")
	assert_eq(attack.attacks_per_second, 1.0, "attacks per second (BALANCE §4.2)")
	assert_eq(attack.battery_cost, 1.0, "battery per swing (BALANCE §4.2)")


func test_r_007_01_basic_arms_match_balance() -> void:
	var attack: AttackStatsData = _load_attack(BASIC_ARMS_PATH)
	assert_not_null(attack, "basic_arms.tres exists and is an AttackStatsData")
	if attack == null:
		return
	assert_eq(attack.damage, 10, "damage of the basic arms (BALANCE §4.2)")
	assert_eq(attack.attacks_per_second, 1.0, "attacks per second (BALANCE §4.2)")
	assert_eq(attack.battery_cost, 1.0, "battery per swing (BALANCE §4.2)")


func test_r_007_04_combat_config_matches_balance() -> void:
	var config: CombatConfigData = load(COMBAT_CONFIG_PATH) as CombatConfigData
	assert_not_null(config, "combat.tres exists and is a CombatConfigData")
	if config == null:
		return
	assert_eq(config.hitbox_reach_m, 2.0, "hit reach (BALANCE §11)")
	assert_eq(config.hitbox_width_m, 1.0, "hit width (BALANCE §11)")
	assert_eq(config.impact_time_s, 0.2, "impact moment (BALANCE §11)")


func test_r_007_04_feedback_matches_balance() -> void:
	var feedback: CombatFeedbackData = load(FEEDBACK_PATH) as CombatFeedbackData
	assert_not_null(feedback, "combat_feedback.tres exists and is a CombatFeedbackData")
	if feedback == null:
		return
	assert_eq(feedback.enemy_flash_s, 0.1, "white flash (BALANCE §11)")
	assert_eq(feedback.hit_dealt_shake_m, 0.05, "hit dealt shake strength (BALANCE §11)")
	assert_eq(feedback.hit_dealt_shake_s, 0.1, "hit dealt shake duration (BALANCE §11)")
	assert_eq(feedback.hit_received_shake_m, 0.15, "hit received shake strength (BALANCE §11)")
	assert_eq(feedback.hit_received_shake_s, 0.2, "hit received shake duration (BALANCE §11)")
	assert_eq(feedback.screen_edge_flash_s, 0.3, "red screen edge (BALANCE §11)")


func test_r_007_04_reach_beyond_zombie_attack_range() -> void:
	var config: CombatConfigData = load(COMBAT_CONFIG_PATH) as CombatConfigData
	var ai: EnemyAiData = load(ZOMBIE_AI_PATH) as EnemyAiData
	if config == null or ai == null:
		fail_test("combat.tres or zombie_ai.tres is missing")
		return
	assert_gt(config.hitbox_reach_m, ai.attack_range, "the hit reaches a zombie that stopped to attack")


func test_r_007_04_impact_before_next_swing() -> void:
	var config: CombatConfigData = load(COMBAT_CONFIG_PATH) as CombatConfigData
	if config == null:
		fail_test("combat.tres is missing")
		return
	assert_gt(config.impact_time_s, 0.0, "the impact comes after the swing starts")
	for path: String in _resource_paths(COMBAT_DIR):
		var attack: AttackStatsData = _load_attack(path)
		if attack == null:
			fail_test("%s is not an AttackStatsData" % path)
			continue
		assert_lt(
			config.impact_time_s, CombatSystem.swing_interval(attack), "%s: impact inside its swing" % path
		)


func test_r_007_04_detector_flags_combat_literals() -> void:
	var regex: RegEx = RegEx.create_from_string(COMBAT_FIELDS_PATTERN)
	var forbidden: Array[String] = [
		"var damage: int = 5",
		"const impact_time_s := 0.2",
		"battery_cost = 1.0",
		"\thitbox_reach_m=2",
	]
	for line: String in forbidden:
		assert_not_null(regex.search(line), "must be flagged: %s" % line)
	var allowed: Array[String] = [
		"var damage: int = CombatSystem.damage_per_hit(attack)",
		"swing_started.emit(attack.battery_cost)",
		"box.size.z = config.hitbox_reach_m",
		"@export var impact_time_s: float",
		"if attack.damage <= 0:",
	]
	for line: String in allowed:
		assert_null(regex.search(line), "must be allowed: %s" % line)


func test_r_007_04_no_combat_literals_in_scripts() -> void:
	var regex: RegEx = RegEx.create_from_string(COMBAT_FIELDS_PATTERN)
	var checked: int = 0
	for dir_path: String in GAME_CODE_DIRS:
		for script_path: String in _collect_scripts(dir_path):
			checked += 1
			var source: String = FileAccess.get_file_as_string(script_path)
			assert_false(source.is_empty(), "%s could be read" % script_path)
			var hits: PackedStringArray = PackedStringArray()
			var lines: PackedStringArray = source.split("\n")
			for i: int in lines.size():
				var code: String = lines[i].get_slice("#", 0)
				if regex.search(code) != null:
					hits.append("line %d: %s" % [i + 1, code.strip_edges()])
			assert_eq(hits.size(), 0, "%s sets a combat value in code: %s" % [script_path, hits])
	assert_gt(checked, 0, "game scripts were found and checked")


func test_r_007_05_every_attack_file_is_valid() -> void:
	var paths: PackedStringArray = _resource_paths(COMBAT_DIR)
	assert_gte(paths.size(), 2, "one arm and the basic arms")
	for path: String in paths:
		var attack: AttackStatsData = _load_attack(path)
		assert_not_null(attack, "%s is an AttackStatsData" % path)
		if attack == null:
			continue
		assert_true(CombatSystem.is_valid_attack(attack), "%s leaves the robot with an attack" % path)


func test_r_007_28_one_arm_kills_both_zombies() -> void:
	var attack: AttackStatsData = _load_attack(ONE_ARM_PATH)
	if attack == null:
		fail_test("one_arm.tres is missing")
		return
	var damage: int = CombatSystem.damage_per_hit(attack)
	assert_gt(damage, 0, "one arm deals damage")
	if damage <= 0:
		return
	var paths: PackedStringArray = _resource_paths(ENEMIES_DIR)
	assert_gt(paths.size(), 0, "enemy files were found")
	for path: String in paths:
		var enemy: EnemyData = load(path) as EnemyData
		if enemy == null:
			fail_test("%s is not an EnemyData" % path)
			continue
		assert_gt(enemy.hp_max, 0, "%s has HP to lose" % enemy.id)
		var hits_to_kill: int = ceili(float(enemy.hp_max) / float(damage))
		assert_gt(hits_to_kill, 0, "%s dies after a finite number of hits" % enemy.id)
		assert_true(EXPECTED_ONE_ARM_HITS.has(enemy.id), "%s has an expected number of hits" % enemy.id)
		if EXPECTED_ONE_ARM_HITS.has(enemy.id):
			assert_eq(hits_to_kill, EXPECTED_ONE_ARM_HITS[enemy.id], "hits for %s (spec 007 §5)" % enemy.id)