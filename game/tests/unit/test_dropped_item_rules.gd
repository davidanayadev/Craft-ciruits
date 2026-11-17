extends GutTest
## DroppedItemRules (spec 008): an item on the ground expires when its age reaches
## the configured lifetime, counted in wall-clock seconds (R-008-21). The rule
## depends only on the three numbers it receives (R-008-24).
## Covers R-008-21 and R-008-24.

const CONFIG_PATH := "res://resources/config/dropped_items.tres"

const DROPPED_AT := 1_700_000_000


func _lifetime() -> int:
	var config: DroppedItemConfigData = load(CONFIG_PATH) as DroppedItemConfigData
	assert_not_null(config, "dropped_items.tres exists and is a DroppedItemConfigData")
	if config == null:
		return 0
	return config.lifetime_s


func test_r_008_21_expired_at_exact_lifetime() -> void:
	var lifetime: int = _lifetime()
	assert_gt(lifetime, 0, "the lifetime is configured")
	assert_true(
		DroppedItemRules.is_expired(DROPPED_AT, DROPPED_AT + lifetime, lifetime),
		"age == lifetime is expired"
	)
	assert_true(
		DroppedItemRules.is_expired(DROPPED_AT, DROPPED_AT + lifetime + 1, lifetime),
		"age > lifetime is expired"
	)


func test_r_008_21_not_expired_one_second_before() -> void:
	var lifetime: int = _lifetime()
	assert_false(
		DroppedItemRules.is_expired(DROPPED_AT, DROPPED_AT + lifetime - 1, lifetime),
		"one second before the lifetime it is still there"
	)
	assert_false(
		DroppedItemRules.is_expired(DROPPED_AT, DROPPED_AT, lifetime),
		"just dropped is not expired"
	)


func test_r_008_21_negative_elapsed_counts_as_zero() -> void:
	var lifetime: int = _lifetime()
	var elapsed: int = DroppedItemRules.elapsed_s(DROPPED_AT, DROPPED_AT - 500)
	assert_eq(elapsed, 0, "a clock set back gives zero elapsed seconds")
	assert_false(
		DroppedItemRules.is_expired(DROPPED_AT, DROPPED_AT - 500, lifetime),
		"a clock set back never expires an item"
	)
	assert_eq(DroppedItemRules.elapsed_s(DROPPED_AT, DROPPED_AT + 42), 42, "forward time counts")


func test_r_008_24_depends_only_on_times() -> void:
	var lifetime: int = _lifetime()
	var first: bool = DroppedItemRules.is_expired(DROPPED_AT, DROPPED_AT + lifetime, lifetime)
	var second: bool = DroppedItemRules.is_expired(DROPPED_AT, DROPPED_AT + lifetime, lifetime)
	assert_eq(first, second, "same inputs, same answer")
	# The same age at another absolute time gives the same answer: no hidden clock.
	var shifted: int = DROPPED_AT + 86_400
	assert_eq(
		DroppedItemRules.is_expired(shifted, shifted + lifetime, lifetime),
		first,
		"only the difference matters"
	)
	assert_eq(
		DroppedItemRules.elapsed_s(shifted, shifted + 7),
		DroppedItemRules.elapsed_s(DROPPED_AT, DROPPED_AT + 7),
		"elapsed depends only on the difference"
	)
