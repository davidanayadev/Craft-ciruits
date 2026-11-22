extends GutTest
## InventorySlotView (spec 013): a short highlight on the slots that received
## a move (R-013-19), faded by advance_highlight() so no test waits on the real
## clock, and an outline on possible destinations while placing (R-013-16).

const SLOT_SCENE := preload("res://scenes/ui/inventory_slot.tscn")
const DURATION_S := 0.4

var _slot: InventorySlotView


func before_each() -> void:
	_slot = SLOT_SCENE.instantiate() as InventorySlotView
	add_child_autofree(_slot)


func test_r_013_19_highlight_fades() -> void:
	var highlight: Control = _slot.get_node("%Highlight") as Control
	assert_false(_slot.is_highlighted(), "no highlight at first")
	assert_false(highlight.visible, "the frame is hidden")
	_slot.flash_highlight(DURATION_S)
	assert_true(_slot.is_highlighted(), "highlighted after a move")
	assert_true(highlight.visible, "the frame shows")
	_slot.advance_highlight(DURATION_S / 2.0)
	assert_true(_slot.is_highlighted(), "still highlighted halfway")
	assert_lt(highlight.modulate.a, 1.0, "and fading")
	_slot.advance_highlight(DURATION_S)
	assert_false(_slot.is_highlighted(), "the highlight ends by itself")
	assert_false(highlight.visible, "the frame hides again")
	assert_false(_slot.is_processing(), "it stops processing once faded")


func test_r_013_19_no_highlight_without_duration() -> void:
	_slot.flash_highlight(0.0)
	assert_false(_slot.is_highlighted(), "a zero duration highlights nothing")


func test_r_013_16_target_marked() -> void:
	var outline: Control = _slot.get_node("%TargetOutline") as Control
	assert_false(_slot.is_target_marked(), "not a destination at first")
	_slot.set_target_marked(true)
	assert_true(_slot.is_target_marked(), "marked as a destination")
	assert_true(outline.visible, "the outline shows")
	_slot.set_target_marked(false)
	assert_false(outline.visible, "and hides again")
	for control: Control in [outline, _slot.get_node("%Highlight") as Control]:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets taps through" % control.name)
