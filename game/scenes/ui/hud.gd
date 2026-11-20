class_name Hud
extends Control
## In-game HUD: battery bar and number at the top left (spec 003), one
## "Interact" button at the bottom right, shown only while the local player
## has an interaction target and its input is not blocked (spec 004, R-005-27), a
## storage button at the bottom centre and a short "inventory full" message
## (spec 005). A large attack button sits at the bottom right, under the
## interact button, and the screen edges flash red when the player is hit
## (spec 007). An "Edit base" button under the battery shows only while the
## base is loaded (spec 009, R-009-59). The short message also shows the
## save notices and "Game saved" after a recharge at a station (spec 010).
## It only listens to the signals of the local player it is bound to and never
## reads state in _process (architecture §9.5).

## The player asked to interact through the HUD button (touch or mouse).
signal interact_pressed
## The player asked for the storage: the HUD button or the open_storage action.
signal storage_pressed
## The HUD attack button went down or up (touch or mouse).
signal attack_held_changed(held: bool)
## The player pressed "Edit base" (spec 009).
signal edit_base_pressed

const MSG_GAME_SAVED := &"MSG_GAME_SAVED"

var _has_target: bool = false
var _input_blocked: bool = false

@onready var _battery_bar: ProgressBar = %BatteryBar
@onready var _battery_label: Label = %BatteryLabel
@onready var _interact_button: Button = %InteractButton
@onready var _storage_button: Button = %StorageButton
@onready var _message_label: Label = %MessageLabel
@onready var _message_timer: Timer = %MessageTimer
@onready var _attack_button: AttackButton = %AttackButton
@onready var _damage_flash: DamageFlash = %DamageFlash
@onready var _edit_base_button: Button = %EditBaseButton


func _ready() -> void:
	_interact_button.pressed.connect(_on_interact_button_pressed)
	_storage_button.pressed.connect(_on_storage_button_pressed)
	_attack_button.held_changed.connect(_on_attack_button_held_changed)
	_message_timer.timeout.connect(_on_message_timer_timeout)
	_edit_base_button.pressed.connect(_on_edit_base_button_pressed)
	EventBus.game_saved.connect(_on_game_saved)


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
	player.use_refused.connect(_on_use_refused)
	player.player_input.blocked_changed.connect(_on_input_blocked_changed)
	_on_input_blocked_changed(player.player_input.is_input_blocked())


## Shows a translation key in the short message for its usual time (spec 005);
## a new one replaces the one showing. With args it shows tr(key) % args
## (spec 012, plan D18), translated now.
func show_notice(message_key: StringName, args: Array = []) -> void:
	# Without args, a translation key: the label translates its own text.
	_message_label.text = String(message_key) if args.is_empty() else tr(message_key) % args
	_message_label.visible = true
	_message_timer.start()


## The button exists only while the base is the loaded zone (R-009-59).
func set_edit_base_available(available: bool) -> void:
	_edit_base_button.visible = available


## Flashes the screen edges red for duration_s seconds (R-007-25).
func flash_damage(duration_s: float) -> void:
	_damage_flash.flash(duration_s)


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
	_interact_button.visible = _has_target and not _input_blocked


## A blocked robot cannot interact (a screen, a death, a travel), so the
## button is not offered.
func _on_input_blocked_changed(blocked: bool) -> void:
	_input_blocked = blocked
	_update_interact_button()


func _on_interact_button_pressed() -> void:
	interact_pressed.emit()


func _on_storage_button_pressed() -> void:
	storage_pressed.emit()


func _on_attack_button_held_changed(held: bool) -> void:
	attack_held_changed.emit(held)


func _on_edit_base_button_pressed() -> void:
	edit_base_pressed.emit()


func _on_inventory_overflowed(_leftovers: Array[ItemStack]) -> void:
	show_notice(InventoryComponent.MSG_INVENTORY_FULL)


## The HUD is drawn over the screens, so a refusal from the inventory's "Use"
## button shows here too (spec 012, plan D19).
func _on_use_refused(error_key: StringName) -> void:
	show_notice(error_key)


## Only the save of a recharge is announced; the others are silent (R-010-62).
func _on_game_saved(reason: StringName) -> void:
	if reason == SaveManager.REASON_RECHARGED:
		show_notice(MSG_GAME_SAVED)


func _on_message_timer_timeout() -> void:
	_message_label.visible = false
