class_name Hud
extends Control
## In-game HUD (spec 003): battery bar and number at the top left.
## It only listens to the signals of the local player it is bound to and never
## reads state in _process (architecture §9.5).

@onready var _battery_bar: ProgressBar = %BatteryBar
@onready var _battery_label: Label = %BatteryLabel


## Hooks the HUD to the local player. The battery was already full before the
## HUD existed, so the current state is painted once through the same handler.
func bind(player: Robot) -> void:
	var battery: BatteryComponent = player.battery
	battery.battery_changed.connect(_on_battery_changed)
	_on_battery_changed(battery.get_current(), battery.get_maximum())


## Whole number shown to the player: rounded up, so it never reads 0 while any
## charge remains.
static func display_value(current: float) -> int:
	return ceili(current)


func _on_battery_changed(current: float, maximum: float) -> void:
	_battery_bar.max_value = maximum
	_battery_bar.value = current
	_battery_label.text = str(display_value(current))
