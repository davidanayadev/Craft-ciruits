extends GutTest
## SaveMigrations (spec 010, R-010-05, R-010-52, R-010-53): format versions and
## the chain of pure migration steps. Pure code: no scene tree, no files.

const MARK := "marks"


func _doc(version: Variant) -> Dictionary:
	return {"schema_version": version, MARK: []}


func _step(label: String) -> Callable:
	return func(document: Dictionary) -> Dictionary:
		var copy: Dictionary = document.duplicate(true)
		var marks: Array = copy[MARK] as Array
		marks.append(label)
		return copy


func test_r_010_52_schema_versions() -> void:
	assert_eq(SaveMigrations.PROFILE_VERSION, 1)
	assert_eq(SaveMigrations.WORLD_VERSION, 1)


func test_r_010_53_chain_applied() -> void:
	var steps: Array[Callable] = [_step("v1_to_v2"), _step("v2_to_v3")]
	var result: SaveMigrations.Result = SaveMigrations.apply(_doc(1), 3, steps)
	assert_eq(result.outcome, SaveMigrations.Outcome.MIGRATED)
	var marks: Array = result.document[MARK]
	assert_eq(marks, ["v1_to_v2", "v2_to_v3"], "applied in order")
	var version: int = SaveFields.to_int(result.document["schema_version"], -1)
	assert_eq(version, 3, "document carries the current version")


func test_r_010_53_chain_starts_at_the_document_version() -> void:
	var steps: Array[Callable] = [_step("v1_to_v2"), _step("v2_to_v3")]
	var result: SaveMigrations.Result = SaveMigrations.apply(_doc(2), 3, steps)
	assert_eq(result.outcome, SaveMigrations.Outcome.MIGRATED)
	var marks: Array = result.document[MARK]
	assert_eq(marks, ["v2_to_v3"], "v1 step is skipped")
	assert_eq(SaveFields.to_int(result.document["schema_version"], -1), 3)


func test_r_010_53_float_version_from_json_is_accepted() -> void:
	var steps: Array[Callable] = [_step("v1_to_v2")]
	var result: SaveMigrations.Result = SaveMigrations.apply(_doc(1.0), 2, steps)
	assert_eq(result.outcome, SaveMigrations.Outcome.MIGRATED)
	var marks: Array = result.document[MARK]
	assert_eq(marks, ["v1_to_v2"])


func test_r_010_53_same_version_is_current_and_unchanged() -> void:
	var steps: Array[Callable] = [_step("never")]
	var document: Dictionary = _doc(1)
	var result: SaveMigrations.Result = SaveMigrations.apply(document, 1, steps)
	assert_eq(result.outcome, SaveMigrations.Outcome.CURRENT)
	assert_eq(result.document, document, "no step ran")


func test_r_010_53_float_same_version_is_current() -> void:
	var steps: Array[Callable] = []
	var result: SaveMigrations.Result = SaveMigrations.apply(_doc(1.0), 1, steps)
	assert_eq(result.outcome, SaveMigrations.Outcome.CURRENT)


func test_r_010_53_newer_version_is_too_new() -> void:
	var steps: Array[Callable] = [_step("never")]
	var result: SaveMigrations.Result = SaveMigrations.apply(_doc(5), 2, steps)
	assert_eq(result.outcome, SaveMigrations.Outcome.TOO_NEW)


func test_r_010_53_invalid_versions() -> void:
	var steps: Array[Callable] = []
	var missing: SaveMigrations.Result = SaveMigrations.apply({}, 1, steps)
	assert_eq(missing.outcome, SaveMigrations.Outcome.INVALID, "missing")
	var fraction: SaveMigrations.Result = SaveMigrations.apply(_doc(1.5), 1, steps)
	assert_eq(fraction.outcome, SaveMigrations.Outcome.INVALID, "fraction")
	var text: SaveMigrations.Result = SaveMigrations.apply(_doc("1"), 1, steps)
	assert_eq(text.outcome, SaveMigrations.Outcome.INVALID, "text")
	var zero: SaveMigrations.Result = SaveMigrations.apply(_doc(0), 1, steps)
	assert_eq(zero.outcome, SaveMigrations.Outcome.INVALID, "zero")
	var negative: SaveMigrations.Result = SaveMigrations.apply(_doc(-3), 1, steps)
	assert_eq(negative.outcome, SaveMigrations.Outcome.INVALID, "negative")
	var nothing: SaveMigrations.Result = SaveMigrations.apply(_doc(null), 1, steps)
	assert_eq(nothing.outcome, SaveMigrations.Outcome.INVALID, "null")


func test_r_010_53_migrate_world_current() -> void:
	var document: Dictionary = {"schema_version": SaveMigrations.WORLD_VERSION}
	var result: SaveMigrations.Result = SaveMigrations.migrate_world(document)
	assert_eq(result.outcome, SaveMigrations.Outcome.CURRENT)
	assert_eq(result.document, document)


func test_r_010_53_migrate_profile_current() -> void:
	var document: Dictionary = {"schema_version": SaveMigrations.PROFILE_VERSION}
	var result: SaveMigrations.Result = SaveMigrations.migrate_profile(document)
	assert_eq(result.outcome, SaveMigrations.Outcome.CURRENT)
	assert_eq(result.document, document)


func test_r_010_53_migrate_too_new_and_invalid() -> void:
	var newer: Dictionary = {"schema_version": SaveMigrations.WORLD_VERSION + 1}
	assert_eq(SaveMigrations.migrate_world(newer).outcome, SaveMigrations.Outcome.TOO_NEW)
	var newer_profile: Dictionary = {"schema_version": SaveMigrations.PROFILE_VERSION + 1}
	assert_eq(SaveMigrations.migrate_profile(newer_profile).outcome, SaveMigrations.Outcome.TOO_NEW)
	assert_eq(SaveMigrations.migrate_world({}).outcome, SaveMigrations.Outcome.INVALID)
	assert_eq(SaveMigrations.migrate_profile({}).outcome, SaveMigrations.Outcome.INVALID)
