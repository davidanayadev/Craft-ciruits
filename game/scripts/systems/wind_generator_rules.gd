class_name WindGeneratorRules
extends RefCounted
## The wind generator's clock (spec 012, plan D7, BALANCE §5.2). Pure: the time
## comes by parameter, so it depends neither on the device clock nor on the
## frame rate, and loading a saved world reuses it. The state is the batteries
## held and since_unix, the start of the period in progress; settling it is
## deterministic, so the state is saved without settling.


## A generator's state at a given time.
class Settled:
	var stored: int
	var since_unix: int

	func _init(p_stored: int, p_since_unix: int) -> void:
		stored = p_stored
		since_unix = p_since_unix


## Seconds since since_unix; a clock set back counts as 0 (R-012-19).
static func elapsed_s(since_unix: int, now_unix: int) -> int:
	return maxi(now_unix - since_unix, 0)


## One battery per full period while below max_stored, never above it; full →
## unchanged, so a full generator does not accumulate time (R-012-16, R-012-17).
## Bad data (period or maximum below 1) → push_error and no batteries.
static func settle(stored: int, since_unix: int, now_unix: int, config: WindGeneratorData) -> Settled:
	if not _is_valid(config):
		return Settled.new(0, since_unix)
	if stored >= config.max_stored:
		return Settled.new(stored, since_unix)
	var gained: int = elapsed_s(since_unix, now_unix) / config.seconds_per_battery
	return Settled.new(
		mini(stored + gained, config.max_stored), since_unix + gained * config.seconds_per_battery
	)


## Seconds until the next battery; -1 when full or with bad data.
static func seconds_to_next(stored: int, since_unix: int, now_unix: int, config: WindGeneratorData) -> int:
	if not _is_valid(config):
		return -1
	var settled: Settled = settle(stored, since_unix, now_unix, config)
	if settled.stored >= config.max_stored:
		return -1
	return config.seconds_per_battery - elapsed_s(settled.since_unix, now_unix)


## The state after taking taken from settled: a generator that was full starts
## its next period at now (R-012-17); otherwise the period in progress goes on.
## taken outside 0..settled.stored → push_error, settled unchanged.
static func after_taking(settled: Settled, taken: int, now_unix: int, config: WindGeneratorData) -> Settled:
	if taken < 0 or taken > settled.stored or not _is_valid(config):
		push_error("WindGeneratorRules: cannot take %d of %d batteries." % [taken, settled.stored])
		return Settled.new(settled.stored, settled.since_unix)
	var was_full: bool = settled.stored >= config.max_stored
	return Settled.new(settled.stored - taken, now_unix if was_full else settled.since_unix)


static func _is_valid(config: WindGeneratorData) -> bool:
	if config != null and config.seconds_per_battery >= 1 and config.max_stored >= 1:
		return true
	push_error("WindGeneratorRules: the generator data needs a period and a maximum of at least 1.")
	return false
