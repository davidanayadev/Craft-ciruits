class_name Hud
extends Control
## In-game HUD: battery bar and number at the top left (spec 003) and one
## "Interact" button at the bottom right, shown only while the local player
## has an interaction target (spec 004, architecture §9.1).
## It only listens to the signals of the local player it is bound to and never
## reads state in _process (architecture §9.5).

## The player asked to interact through the HUD button (touch or mouse).
signal interact_pressed

@onready var _battery_bar: ProgressBar = %BatteryBar
@onready var _battery_label: Label = %BatteryLabel
@onready var _interact_button: Button = %InteractButton


func _ready() -> void:
	_interact_button.pressed.connect(_on_interact_button_pressed)


## Hooks the HUD to the local player. The battery was already full before the
## HUD existed, so the current state is painted once through the same handlers.
func bind(player: Robot) -> void:
	var battery: BatteryComponent = player.battery
	battery.battery_changed.connect(_on_battery_changed)
	_on_battery_changed(battery.get_current(), battery.get_maximum())
	player.interactor.target_changed.connect(_on_target_changed)
	_on_target_changed(player.interactor.get_target())


## Whole number shown to the player: rounded up, so it never reads 0 while any
## charge remains.
static func display_value(current: float) -> int:
	return ceili(current)


func _on_battery_changed(current: float, maximum: float) -> void:
	_battery_bar.max_value = maximum
	_battery_bar.value = current
	_battery_label.text = str(display_value(current))


func _on_target_changed(target: InteractableComponent) -> void:
	_interact_button.visible = target != null
	if target != null:
		# A translation key: the button translates its own text.
		_interact_button.text = String(target.prompt_key)


func _on_interact_button_pressed() -> void:
	interact_pressed.emit()
