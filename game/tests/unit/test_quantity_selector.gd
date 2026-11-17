extends GutTest
## QuantitySelector (spec 008, R-008-38): a range 1..maximum that starts at the
## whole stack, moved by - / + one by one and a slider, reporting only real
## changes. Headless cannot click Controls: pressed is emitted by hand.

const SELECTOR_SCENE := preload("res://scenes/ui/quantity_selector.tscn")
const MAXIMUM := 5

var _selector: QuantitySelector
var _minus: Button
var _plus: Button
var _slider: HSlider
var _label: Label


func before_each() -> void:
	_selector = SELECTOR_SCENE.instantiate() as QuantitySelector
	add_child_autofree(_selector)
	_minus = _selector.get_node("%MinusButton") as Button
	_plus = _selector.get_node("%PlusButton") as Button
	_slider = _selector.get_node("%Slider") as HSlider
	_label = _selector.get_node("%ValueLabel") as Label
	_selector.set_maximum(MAXIMUM)
	watch_signals(_selector)


func test_r_008_38_range_one_to_maximum_starts_at_maximum() -> void:
	assert_eq(_slider.min_value, 1.0, "the range starts at 1")
	assert_eq(_slider.max_value, float(MAXIMUM), "and ends at the maximum")
	assert_eq(_selector.get_value(), MAXIMUM, "it starts at the whole stack")


func test_r_008_38_minus_and_plus_move_by_one() -> void:
	_minus.pressed.emit()
	assert_eq(_selector.get_value(), MAXIMUM - 1, "minus lowers by one")
	_minus.pressed.emit()
	assert_eq(_selector.get_value(), MAXIMUM - 2, "again")
	_plus.pressed.emit()
	assert_eq(_selector.get_value(), MAXIMUM - 1, "plus raises by one")
	assert_signal_emit_count(_selector, "value_changed", 3, "each step is reported")


func test_r_008_38_never_leaves_the_range() -> void:
	_plus.pressed.emit()
	assert_eq(_selector.get_value(), MAXIMUM, "plus at the maximum changes nothing")
	for i: int in MAXIMUM + 3:
		_minus.pressed.emit()
	assert_eq(_selector.get_value(), 1, "minus stops at 1")
	assert_signal_emit_count(_selector, "value_changed", MAXIMUM - 1, "only real changes are reported")


func test_r_008_38_buttons_disabled_at_the_ends() -> void:
	assert_true(_plus.disabled, "plus disabled at the maximum")
	assert_false(_minus.disabled, "minus enabled at the maximum")
	_slider.value = 1.0
	assert_true(_minus.disabled, "minus disabled at 1")
	assert_false(_plus.disabled, "plus enabled at 1")
	_slider.value = 3.0
	assert_false(_minus.disabled, "both enabled in the middle")
	assert_false(_plus.disabled, "both enabled in the middle")


func test_r_008_38_slider_reports_int() -> void:
	_slider.value = 2.0
	assert_signal_emit_count(_selector, "value_changed", 1, "the slider is reported")
	assert_signal_emitted_with_parameters(_selector, "value_changed", [2])
	var params: Array = get_signal_parameters(_selector, "value_changed")
	if params.is_empty():
		fail_test("value_changed had no parameters")
		return
	var value_type: int = typeof(params[0])
	assert_eq(value_type, TYPE_INT, "the value is an int")


func test_r_008_38_set_maximum_does_not_emit() -> void:
	_selector.set_maximum(MAXIMUM + 4)
	assert_signal_not_emitted(_selector, "value_changed", "setting the range reports nothing")
	assert_eq(_selector.get_value(), MAXIMUM + 4, "and starts at the new maximum")


func test_r_008_38_stack_of_one() -> void:
	_selector.set_maximum(1)
	assert_eq(_selector.get_value(), 1, "the only value is 1")
	assert_true(_minus.disabled, "minus disabled")
	assert_true(_plus.disabled, "plus disabled")


func test_r_008_38_label_shows_the_value() -> void:
	assert_eq(_label.text, str(MAXIMUM), "the label starts at the maximum")
	_minus.pressed.emit()
	assert_eq(_label.text, str(MAXIMUM - 1), "it follows the value")
	_selector.set_maximum(9)
	assert_eq(_label.text, "9", "and a new range")
