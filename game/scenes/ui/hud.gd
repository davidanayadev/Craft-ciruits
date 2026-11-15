class_name Hud
extends Control
## In-game HUD: battery bar and number at the top left (spec 003), one
## "Interact" button at the bottom right, shown only while the local player
## has an interaction target and no screen is open (spec 004, R-005-27), a
## storage button at the bottom centre and a short "inventory full" message
## (spec 005).
## It only listens to the signals of the local player it is bound to and never
## reads state in _process (architecture §9.5).

## The player asked to interact through the HUD button (touch or mouse).
signal interact_pressed
## The player asked for the storage: the HUD button or the open_storage action.
signal storage_pressed

var _has_target: bool = false
var _modal_open: bool = false

@onready var _battery_bar: ProgressBar = %BatteryBar
@onready var _battery_label: Label = %BatteryLabel
@onready var _interact_button: Button = %InteractButton
@onready var _storage_button: Button = %StorageButton
@onready var _message_label: Label = %MessageLabel
@onready var _message_timer: Timer = %MessageTimer


func _ready() -> void:
	_interact_button.pressed.connect(_on_interact_button_pressed)
	_storage_button.pressed.connect(_on_storage_button_pressed)
	_message_timer.timeout.connect(_on_message_timer_timeout)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_storage"):
		storage_pressed.emit()
		get_viewport().set_input_as_handled()


## Hooks the HUD to the local player. The battery was already full before the
## HUD existed, so the current state is painted once through the same handlers.
func bind(player: Robot) -> void:
	var battery: BatteryComponent = player.battery
	battery.battery_changed.connect(_on_battery_changed)
	_on_battery_changed(battery.get_current(), battery.get_maximum())
	player.interactor.target_changed.connect(_on_target_changed)
	_on_target_changed(player.interactor.get_target())
	player.inventory.overflowed.connect(_on_inventory_overflowed)


## With a screen open the robot cannot interact, so the button is not offered.
func set_modal_open(is_open: bool) -> void:
	_modal_open = is_open
	_update_interact_button()


## Whole number shown to the player: rounded up, so it never reads 0 while any
## charge remains.
static func display_value(current: float) -> int:
	return ceili(current)


func _on_battery_changed(current: float, maximum: float) -> void:
	_battery_bar.max_value = maximum
	_battery_bar.value = current
	_battery_label.text = str(display_value(current))


func _on_target_changed(target: InteractableComponent) -> void:
	_has_target = target != null
	if target != null:
		# A translation key: the button translates its own text.
		_interact_button.text = String(target.prompt_key)
	_update_interact_button()


func _update_interact_button() -> void:
	_interact_button.visible = _has_target and not _modal_open


func _on_interact_button_pressed() -> void:
	interact_pressed.emit()


func _on_storage_button_pressed() -> void:
	storage_pressed.emit()


func _on_inventory_overflowed(_leftovers: Array[ItemStack]) -> void:
	# A translation key: the label translates its own text.
	_message_label.text = String(InventoryComponent.MSG_INVENTORY_FULL)
	_message_label.visible = true
	_message_timer.start()


func _on_message_timer_timeout() -> void:
	_message_label.visible = false
