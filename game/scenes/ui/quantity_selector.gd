class_name QuantitySelector
extends HBoxContainer
## Chooses how many units of a stack an action takes (spec 008): − / + one by
## one and a slider, from 1 to the size of the stack. It only reports the
## number; the screen decides what to do with it.

signal value_changed(value: int)

const MINIMUM := 1

var _editable: bool = true

@onready var _minus_button: Button = %MinusButton
@onready var _plus_button: Button = %PlusButton
@onready var _slider: HSlider = %Slider
@onready var _value_label: Label = %ValueLabel


func _ready() -> void:
	_slider.min_value = MINIMUM
	_minus_button.pressed.connect(_step.bind(-1))
	_plus_button.pressed.connect(_step.bind(1))
	_slider.value_changed.connect(_on_slider_value_changed)
	_refresh()


## Range 1..maximum, starting at the whole stack. Does not emit value_changed.
func set_maximum(maximum: int) -> void:
	_slider.max_value = maxi(maximum, MINIMUM)
	_slider.set_value_no_signal(_slider.max_value)
	_refresh()


## Disables −, + and the slider without hiding them (R-013-13).
func set_editable(editable: bool) -> void:
	_editable = editable
	_slider.editable = editable
	_refresh()


func is_editable() -> bool:
	return _editable


func get_value() -> int:
	return roundi(_slider.value)


## The slider keeps the value inside the range and reports only real changes.
func _step(amount: int) -> void:
	_slider.value = get_value() + amount


func _on_slider_value_changed(_value: float) -> void:
	_refresh()
	value_changed.emit(get_value())


func _refresh() -> void:
	var value: int = get_value()
	_value_label.text = str(value)
	_minus_button.disabled = not _editable or value <= MINIMUM
	_plus_button.disabled = not _editable or value >= roundi(_slider.max_value)
