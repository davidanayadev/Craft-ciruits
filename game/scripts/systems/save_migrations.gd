class_name SaveMigrations
extends RefCounted
## Format version of each save document and the chain that brings an older
## one up to date (spec 010, R-010-52, R-010-53). Pure: a step takes the
## document of version v and returns it in version v + 1, and the chain runs
## before any owner reads it. A new owner is a new key and needs no step
## (R-010-10); a step is added only when the shape of an existing key changes,
## with its example file under tests/fixtures/saves/ (R-010-54).

const VERSION_KEY := "schema_version"
## Format versions, not game values.
const PROFILE_VERSION := 1
const WORLD_VERSION := 1

enum Outcome { CURRENT, MIGRATED, TOO_NEW, INVALID }


class Result:
	var outcome: Outcome
	## The document at the current version; the input as it came for TOO_NEW and INVALID.
	var document: Dictionary

	func _init(p_outcome: Outcome, p_document: Dictionary) -> void:
		outcome = p_outcome
		document = p_document


## Applies steps[v - 1] for every v from the document's schema_version up to
## current. A missing, fractional or < 1 version, or a chain too short for it,
## → INVALID; a version above current → TOO_NEW. The input is never changed.
static func apply(document: Dictionary, current: int, steps: Array[Callable]) -> Result:
	var version: int = SaveFields.to_int(document.get(VERSION_KEY), 0)
	if version < 1 or current - 1 > steps.size():
		return Result.new(Outcome.INVALID, document)
	if version > current:
		return Result.new(Outcome.TOO_NEW, document)
	if version == current:
		return Result.new(Outcome.CURRENT, document)
	var migrated: Dictionary = document.duplicate(true)
	for step_version: int in range(version, current):
		var step: Callable = steps[step_version - 1]
		migrated = step.call(migrated)
		migrated[VERSION_KEY] = step_version + 1
	return Result.new(Outcome.MIGRATED, migrated)


static func migrate_world(document: Dictionary) -> Result:
	return apply(document, WORLD_VERSION, _world_steps())


static func migrate_profile(document: Dictionary) -> Result:
	return apply(document, PROFILE_VERSION, _profile_steps())


## migrate_vN_to_vN1 of the World, in order. None yet: version 1 is the first.
static func _world_steps() -> Array[Callable]:
	return []


## migrate_vN_to_vN1 of the Profile, in order. None yet.
static func _profile_steps() -> Array[Callable]:
	return []
