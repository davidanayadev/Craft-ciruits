extends GutTest
## DegradationSystem (spec 015): which equipped piece a hit wears, arms, legs,
## then core (R-015-21), none when nothing is equipped (R-015-22), and the
## durability after the hit, the wear rounded to a whole number and never below 0.

const ARMS := PieceData.SlotType.ARMS
const LEGS := PieceData.SlotType.LEGS
const CORE := PieceData.SlotType.CORE


func _piece(durability: int) -> ItemStack:
	var piece: PieceData = PieceData.new()
	piece.durability_max = 100
	var stack: ItemStack = ItemStack.new(piece, 1)
	stack.durability = durability
	stack.uid = Uid.generate()
	return stack


## Indexed by SlotType; null for an empty slot.
func _slots(arms: ItemStack, legs: ItemStack, core: ItemStack) -> Array[ItemStack]:
	var slots: Array[ItemStack] = [null, null, null]
	slots[ARMS] = arms
	slots[LEGS] = legs
	slots[CORE] = core
	return slots


func test_r_015_21_order_arms_legs_core() -> void:
	assert_eq(DegradationSystem.target_slot(_slots(_piece(50), _piece(50), _piece(50))), ARMS, "arms first")
	assert_eq(DegradationSystem.target_slot(_slots(null, _piece(50), _piece(50))), LEGS, "then legs")
	assert_eq(DegradationSystem.target_slot(_slots(null, null, _piece(50))), CORE, "then the core")
	assert_eq(DegradationSystem.target_slot(_slots(_piece(1), null, _piece(50))), ARMS, "only empty slots are skipped")


func test_r_015_21_wear_order_constant() -> void:
	var expected: Array[int] = [ARMS, LEGS, CORE]
	assert_eq(DegradationSystem.WEAR_ORDER, expected, "BALANCE §4.1")


func test_r_015_21_wear_rounded_never_negative() -> void:
	assert_eq(DegradationSystem.durability_after_hit(100, 5.0), 95, "5 takes 5")
	assert_eq(DegradationSystem.durability_after_hit(100, 2.5), 97, "2.5 takes 3 (half away from 0)")
	assert_eq(DegradationSystem.durability_after_hit(100, 2.4), 98, "2.4 takes 2")
	assert_eq(DegradationSystem.durability_after_hit(100, -1.0), 100, "-1 takes 0: a hit never repairs")
	assert_eq(DegradationSystem.durability_after_hit(3, 5.0), -2, "may go to 0 or below: broken")


func test_r_015_22_nothing_equipped_no_slot() -> void:
	var none: Array[ItemStack] = _slots(null, null, null)
	assert_eq(DegradationSystem.target_slot(none), DegradationSystem.NO_SLOT, "nothing equipped")
	var empty: Array[ItemStack] = []
	assert_eq(DegradationSystem.target_slot(empty), DegradationSystem.NO_SLOT, "no slots at all")
