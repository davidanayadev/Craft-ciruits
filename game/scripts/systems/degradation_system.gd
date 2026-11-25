class_name DegradationSystem
extends RefCounted
## Pure wear rules (spec 015, BALANCE §4.1): which equipped piece a hit
## received wears and its durability after it. The caller owns the pieces and
## writes the result (EquipmentComponent).

const NO_SLOT := -1
## Arms → legs → core (BALANCE §4.1), as PieceData.SlotType values.
const WEAR_ORDER: Array[int] = [
	PieceData.SlotType.ARMS, PieceData.SlotType.LEGS, PieceData.SlotType.CORE,
]


## First occupied slot of pieces (indexed by SlotType) in WEAR_ORDER; NO_SLOT
## when none is (R-015-21, R-015-22).
static func target_slot(pieces: Array[ItemStack]) -> int:
	for slot: int in WEAR_ORDER:
		if slot < pieces.size() and pieces[slot] != null:
			return slot
	return NO_SLOT


## durability minus the wear rounded to a whole number, never below 0
## (R-015-21, spec 015 question 18). The result may be 0 or less: the piece
## breaks (R-015-23).
static func durability_after_hit(durability: int, wear: float) -> int:
	return durability - maxi(0, roundi(wear))
