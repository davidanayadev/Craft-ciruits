extends GutTest
## Enemy data (spec 006): EnemyData has a stable id, a translated name and a
## faction (R-006-01), the two zombies match BALANCE §3.1 (R-006-02) and the
## AI tuning lives in a resource with the values of BALANCE §3.1 "IA de
## zombies", not in script literals (R-006-03).
## Spec 007: each zombie carries the XP of BALANCE §3.1 and §6.2 (R-007-03).
## The expected values mirror BALANCE.md §3.1 and §6.2; update both together.

const ENEMIES_DIR := "res://resources/enemies"
const ZOMBIE_AI_PATH := "res://resources/ai/zombie_ai.tres"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const SNAKE_CASE_PATTERN := "^[a-z][a-z0-9]*(_[a-z0-9]+)*$"
## id → [name_key, hp_max, hit_damage, move_speed, attack_interval] (BALANCE §3.1).
const EXPECTED_ZOMBIES: Dictionary[StringName, Array] = {
	&"zombie_slow": [&"ENEMY_ZOMBIE_SLOW", 20, 5.0, 1.5, 1.5],
	&"zombie_fast": [&"ENEMY_ZOMBIE_FAST", 15, 4.0, 3.5, 1.5],
}
## id → XP per kill (BALANCE §3.1, §6.2).
const EXPECTED_XP: Dictionary[StringName, int] = {&"zombie_slow": 2, &"zombie_fast": 3}
## Scripts that run the AI: none may assign a number to an AI tuning field.
const AI_SCRIPTS: PackedStringArray = [
	"res://scripts/systems/enemy_brain.gd",
	"res://scenes/entities/zombie.gd",
]
const AI_FIELDS_PATTERN := (
	"(vision_radius|attack_range|patrol_radius|patrol_pause_min|patrol_pause_max"
	+ "|give_up_distance|attack_interval|move_speed|hit_damage|hp_max)\\s*(:\\s*\\w+\\s*)?:?=\\s*-?\\d"
)


func _load_enemy(id: StringName) -> EnemyData:
	return load("%s/%s.tres" % [ENEMIES_DIR, id]) as EnemyData


func test_r_006_01_enemy_data_fields() -> void:
	var snake_case: RegEx = RegEx.create_from_string(SNAKE_CASE_PATTERN)
	var valid_factions: Array = EnemyData.Faction.values()
	for id: StringName in EXPECTED_ZOMBIES:
		var enemy: EnemyData = _load_enemy(id)
		assert_not_null(enemy, "%s.tres exists and is an EnemyData" % id)
		if enemy == null:
			continue
		var name_key: StringName = EXPECTED_ZOMBIES[id][0]
		assert_eq(enemy.id, id, "id of %s.tres" % id)
		assert_not_null(snake_case.search(String(enemy.id)), "'%s' is snake_case" % enemy.id)
		assert_eq(enemy.name_key, name_key, "name key of %s" % id)
		assert_true(valid_factions.has(enemy.faction), "faction of %s is in the enum" % id)


func test_r_006_01_faction_enum() -> void:
	var names: Array = EnemyData.Faction.keys()
	var expected: Array = ["INFECTED", "MACHINE", "HUMAN"]
	assert_eq(names, expected, "the three factions of SPECS §28")


func test_r_006_01_enemy_names_translated_es_en() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() != 1:
			continue
		for id: StringName in EXPECTED_ZOMBIES:
			var name_key: StringName = EXPECTED_ZOMBIES[id][0]
			var text: String = translations[0].get_message(name_key)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, name_key])


func test_r_006_02_zombies_match_balance() -> void:
	for id: StringName in EXPECTED_ZOMBIES:
		var enemy: EnemyData = _load_enemy(id)
		if enemy == null:
			fail_test("%s.tres is missing" % id)
			continue
		var hp_max: int = EXPECTED_ZOMBIES[id][1]
		var hit_damage: float = EXPECTED_ZOMBIES[id][2]
		var move_speed: float = EXPECTED_ZOMBIES[id][3]
		var attack_interval: float = EXPECTED_ZOMBIES[id][4]
		assert_eq(enemy.faction, EnemyData.Faction.INFECTED, "%s is infected (SPECS §28)" % id)
		assert_eq(enemy.hp_max, hp_max, "HP of %s (BALANCE §3.1)" % id)
		assert_eq(enemy.hit_damage, hit_damage, "damage of %s (BALANCE §3.1)" % id)
		assert_eq(enemy.move_speed, move_speed, "speed of %s (BALANCE §3.1)" % id)
		assert_eq(enemy.attack_interval, attack_interval, "attack interval of %s" % id)


func test_r_006_02_only_the_two_zombies() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(ENEMIES_DIR)
	assert_eq(files.size(), EXPECTED_ZOMBIES.size(), "one file per zombie of BALANCE §3.1")


func test_r_006_03_ai_matches_balance() -> void:
	var ai: EnemyAiData = load(ZOMBIE_AI_PATH) as EnemyAiData
	assert_not_null(ai, "zombie_ai.tres exists and is an EnemyAiData")
	if ai == null:
		return
	assert_eq(ai.vision_radius, 8.0, "vision radius (BALANCE §3.1)")
	assert_eq(ai.attack_range, 1.5, "attack range (BALANCE §3.1)")
	assert_eq(ai.patrol_radius, 5.0, "patrol radius (BALANCE §3.1)")
	assert_eq(ai.patrol_pause_min, 2.0, "shortest patrol pause (BALANCE §3.1)")
	assert_eq(ai.patrol_pause_max, 4.0, "longest patrol pause (BALANCE §3.1)")
	assert_eq(ai.give_up_distance, 12.0, "give-up distance (BALANCE §3.1)")


func test_r_006_03_zombies_share_the_ai_resource() -> void:
	var ai: EnemyAiData = load(ZOMBIE_AI_PATH) as EnemyAiData
	for id: StringName in EXPECTED_ZOMBIES:
		var enemy: EnemyData = _load_enemy(id)
		if enemy == null:
			fail_test("%s.tres is missing" % id)
			continue
		assert_same(enemy.ai, ai, "%s uses zombie_ai.tres" % id)


func test_r_006_03_detector_flags_ai_literals() -> void:
	var regex: RegEx = RegEx.create_from_string(AI_FIELDS_PATTERN)
	var forbidden: Array[String] = [
		"var vision_radius: float = 8.0",
		"const give_up_distance := 12",
		"_attack_interval = 1.5",
		"move_speed=3",
	]
	for line: String in forbidden:
		assert_not_null(regex.search(line), "must be flagged: %s" % line)
	var allowed: Array[String] = [
		"if target_distance <= _ai.vision_radius:",
		"_attack_interval = attack_interval",
		"@export var vision_radius: float",
	]
	for line: String in allowed:
		assert_null(regex.search(line), "must be allowed: %s" % line)


func test_r_006_03_no_ai_literals_in_scripts() -> void:
	var regex: RegEx = RegEx.create_from_string(AI_FIELDS_PATTERN)
	for script_path: String in AI_SCRIPTS:
		var source: String = FileAccess.get_file_as_string(script_path)
		assert_false(source.is_empty(), "%s could be read" % script_path)
		var hits: PackedStringArray = PackedStringArray()
		var lines: PackedStringArray = source.split("\n")
		for i: int in lines.size():
			var code: String = lines[i].get_slice("#", 0)
			if regex.search(code) != null:
				hits.append("line %d: %s" % [i + 1, code.strip_edges()])
		assert_eq(hits.size(), 0, "%s sets an AI value in code: %s" % [script_path, hits])


func test_r_007_03_zombies_xp_match_balance() -> void:
	for id: StringName in EXPECTED_XP:
		var enemy: EnemyData = _load_enemy(id)
		if enemy == null:
			fail_test("%s.tres is missing" % id)
			continue
		assert_eq(enemy.xp_reward, EXPECTED_XP[id], "XP of %s (BALANCE §6.2)" % id)


func test_r_007_03_xp_reward_defaults_to_zero() -> void:
	assert_eq(EnemyData.new().xp_reward, 0, "an enemy without the field gives no XP")


# --- Zombie drops (spec 008, R-008-05) --------------------------------------

const ZOMBIE_DROP_PATH := "res://resources/loot/zombie_drop.tres"
const SCRAP_PATH := "res://resources/items/scrap.tres"


func test_r_008_05_zombies_drop_table_matches_balance() -> void:
	var table: LootTableData = load(ZOMBIE_DROP_PATH) as LootTableData
	assert_not_null(table, "zombie_drop.tres exists and is a LootTableData")
	if table == null:
		return
	var scrap: ItemData = load(SCRAP_PATH) as ItemData
	assert_eq(table.entries.size(), 1, "a single entry: scrap (BALANCE §3.1)")
	if table.entries.size() == 1:
		var entry: LootEntryData = table.entries[0]
		assert_not_null(entry, "the entry exists")
		if entry != null:
			assert_same(entry.item, scrap, "the entry gives scrap")
			assert_eq(entry.min_quantity, 0, "minimum (BALANCE §3.1, §2.1)")
			assert_eq(entry.max_quantity, 1, "maximum (BALANCE §3.1, §2.1)")
	var problems: PackedStringArray = LootSystem.validate(table)
	assert_eq(problems.size(), 0, "the table is valid: %s" % problems)
	for id: StringName in EXPECTED_ZOMBIES:
		var enemy: EnemyData = _load_enemy(id)
		if enemy == null:
			fail_test("%s.tres is missing" % id)
			continue
		assert_not_null(enemy.drop_table, "%s has a drop table" % id)
		assert_same(enemy.drop_table, table, "%s uses zombie_drop.tres" % id)


func test_r_008_05_drop_table_defaults_to_none() -> void:
	assert_null(EnemyData.new().drop_table, "an enemy without the field drops nothing")
