extends GutTest
## Battery HUD (R-003-11): a bar and a whole number rounded up at the top left,
## driven only by battery_changed. The robot's physics is switched off so the
## battery only moves when the test says so.
## Interact button (R-004-13): shown with the prompt of the robot's interaction
## target, hidden without one, driven only by target_changed.
## Spec 005: a storage button at the bottom centre (R-005-23) that, like the
## open_storage action, emits storage_pressed (R-005-24); the interact button
## hides while a screen is open (R-005-27); the "inventory full" message shows
## on overflowed and hides when its timer ends (R-005-20); keys in ES and EN
## (R-005-30).

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
## ProgressBar snaps its value to its step.
const BAR_TOLERANCE := 0.01
const STORAGE_KEY := &"HUD_STORAGE"
const ATTACK_KEY := &"HUD_ATTACK"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const INPUT_FRAMES := 2

var _hud: Hud
var _robot: Robot
var _bar: ProgressBar
var _label: Label
var _interact_button: Button
var _storage_button: Button
var _message_label: Label
var _message_timer: Timer


func before_each() -> void:
	_robot = ROBOT_SCENE.instantiate() as Robot
	add_child_autofree(_robot)
	_robot.set_physics_process(false)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child_autofree(_hud)
	_bar = _hud.get_node("%BatteryBar") as ProgressBar
	_label = _hud.get_node("%BatteryLabel") as Label
	_interact_button = _hud.get_node("%InteractButton") as Button
	_storage_button = _hud.get_node("%StorageButton") as Button
	_message_label = _hud.get_node("%MessageLabel") as Label
	_message_timer = _hud.get_node("%MessageTimer") as Timer


func after_each() -> void:
	_send_open_storage(false)


func _send_open_storage(pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"open_storage"
	event.pressed = pressed
	Input.parse_input_event(event)


func test_r_003_11_display_value_rounds_up() -> void:
	assert_eq(Hud.display_value(100.0), 100, "a whole value stays")
	assert_eq(Hud.display_value(87.5), 88, "fractions round up")
	assert_eq(Hud.display_value(0.01), 1, "never 0 while any charge remains")
	assert_eq(Hud.display_value(0.0), 0, "0 only when empty")


func test_r_003_11_shows_current_state_when_bound() -> void:
	_robot.battery.consume(30.0)
	_hud.bind(_robot)
	assert_eq(_label.text, "70", "the number shows the battery it was bound to")
	assert_almost_eq(_bar.value, 70.0, BAR_TOLERANCE, "the bar too")
	assert_eq(_bar.max_value, 100.0, "the bar ends at the maximum battery")


func test_r_003_11_follows_battery_changed() -> void:
	_hud.bind(_robot)
	_robot.battery.consume(12.5)
	assert_eq(_label.text, "88", "87.5 is shown rounded up")
	assert_almost_eq(_bar.value, 87.5, BAR_TOLERANCE, "the bar keeps the real value")
	_robot.battery.consume(87.49)
	assert_eq(_label.text, "1", "0.01 left still shows 1")
	_robot.battery.consume(1.0)
	assert_eq(_label.text, "0", "empty shows 0")
	assert_eq(_bar.value, 0.0, "empty bar")


func test_r_003_11_does_not_poll() -> void:
	_hud.bind(_robot)
	assert_false(_hud.is_processing(), "no _process")
	assert_false(_hud.is_physics_processing(), "no _physics_process")


func test_r_003_11_anchored_top_left_without_own_percentage() -> void:
	assert_eq(_bar.anchor_left, 0.0, "bar anchored to the left edge")
	assert_eq(_bar.anchor_top, 0.0, "bar anchored to the top edge")
	assert_eq(_bar.anchor_right, 0.0, "bar does not stretch across the screen")
	assert_eq(_bar.anchor_bottom, 0.0, "bar does not stretch down the screen")
	assert_false(_bar.show_percentage, "the number comes from the label, not from the bar")


func _new_target(prompt_key: StringName) -> InteractableComponent:
	var target: InteractableComponent = InteractableComponent.new()
	target.prompt_key = prompt_key
	add_child_autofree(target)
	return target


func test_r_004_13_button_hidden_without_target() -> void:
	assert_false(_interact_button.visible, "hidden before the HUD is bound")
	_hud.bind(_robot)
	assert_false(_interact_button.visible, "hidden while the robot has no target")


func test_r_004_13_button_shows_target_prompt() -> void:
	_hud.bind(_robot)
	_robot.interactor.target_changed.emit(_new_target(&"PROMPT_OPEN"))
	assert_true(_interact_button.visible, "shown while the robot has a target")
	assert_eq(_interact_button.text, "PROMPT_OPEN", "the text is the target's translation key")
	_robot.interactor.target_changed.emit(_new_target(&"GAME_OVER_RESTART"))
	assert_eq(_interact_button.text, "GAME_OVER_RESTART", "it follows a change of target")
	_robot.interactor.target_changed.emit(null)
	assert_false(_interact_button.visible, "hidden again without target")


func test_r_004_13_button_text_is_translated() -> void:
	assert_ne(
		_interact_button.auto_translate_mode,
		Node.AUTO_TRANSLATE_MODE_DISABLED,
		"the button translates the key it is given"
	)


func test_r_004_13_button_emits_interact_pressed() -> void:
	watch_signals(_hud)
	_interact_button.pressed.emit()
	assert_signal_emit_count(_hud, "interact_pressed", 1)


func test_r_004_13_button_bottom_right_without_focus() -> void:
	assert_eq(_interact_button.anchor_left, 1.0, "anchored to the right edge")
	assert_eq(_interact_button.anchor_right, 1.0, "anchored to the right edge")
	assert_eq(_interact_button.anchor_top, 1.0, "anchored to the bottom edge")
	assert_eq(_interact_button.anchor_bottom, 1.0, "anchored to the bottom edge")
	assert_lt(_interact_button.offset_right, 0.0, "inside the screen")
	assert_lt(_interact_button.offset_bottom, 0.0, "inside the screen")
	# Without focus, Space (attack) or Enter never press it by accident.
	assert_eq(_interact_button.focus_mode, Control.FOCUS_NONE, "never takes keyboard focus")


func test_r_005_23_storage_button_bottom_centre_without_focus() -> void:
	assert_true(_storage_button.visible, "always shown")
	assert_eq(_storage_button.anchor_left, 0.5, "anchored to the centre")
	assert_eq(_storage_button.anchor_right, 0.5, "anchored to the centre")
	assert_eq(_storage_button.anchor_top, 1.0, "anchored to the bottom edge")
	assert_eq(_storage_button.anchor_bottom, 1.0, "anchored to the bottom edge")
	assert_eq(_storage_button.offset_left, -_storage_button.offset_right, "centred on the screen")
	assert_lt(_storage_button.offset_bottom, 0.0, "inside the screen")
	# Without focus, Tab keeps reaching open_storage and Enter presses nothing.
	assert_eq(_storage_button.focus_mode, Control.FOCUS_NONE, "never takes keyboard focus")


func test_r_005_24_button_emits() -> void:
	watch_signals(_hud)
	_storage_button.pressed.emit()
	assert_signal_emit_count(_hud, "storage_pressed", 1)


func test_r_005_24_open_storage_action_emits() -> void:
	watch_signals(_hud)
	_send_open_storage(true)
	await wait_process_frames(INPUT_FRAMES)
	assert_signal_emit_count(_hud, "storage_pressed", 1, "the action is one press")


func test_r_005_20_inventory_full_message() -> void:
	_hud.bind(_robot)
	assert_false(_message_label.visible, "no message at the start")
	var scrap: ItemData = DataRegistry.get_item(&"scrap")
	var capacity: int = scrap.stack_max * _robot.inventory.get_slot_count()
	assert_false(_robot.inventory.add(&"scrap", capacity + 1).ok, "one more than fits")
	assert_true(_message_label.visible, "the message shows when something does not fit")
	assert_eq(
		_message_label.text,
		String(InventoryComponent.MSG_INVENTORY_FULL),
		"the text is the translation key"
	)
	assert_ne(
		_message_label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated"
	)
	assert_false(_message_timer.is_stopped(), "the message is on a timer")
	assert_true(_message_timer.one_shot, "that runs once")
	# No real time in tests: the timer's own signal hides the message.
	_message_timer.timeout.emit()
	assert_false(_message_label.visible, "the message hides when the timer ends")


func test_r_005_20_no_message_when_everything_fits() -> void:
	_hud.bind(_robot)
	assert_true(_robot.inventory.add(&"scrap", 1).ok, "it fits")
	assert_false(_message_label.visible, "no message")


func test_r_005_27_interact_button_hidden_while_modal() -> void:
	_hud.bind(_robot)
	_robot.interactor.target_changed.emit(_new_target(&"PROMPT_OPEN"))
	assert_true(_interact_button.visible, "shown with a target and no screen open")
	_hud.set_modal_open(true)
	assert_false(_interact_button.visible, "hidden while a screen is open")
	_robot.interactor.target_changed.emit(_new_target(&"GAME_OVER_RESTART"))
	assert_false(_interact_button.visible, "a new target does not bring it back while open")
	_hud.set_modal_open(false)
	assert_true(_interact_button.visible, "shown again when the screen closes")
	assert_eq(_interact_button.text, "GAME_OVER_RESTART", "with the current target's prompt")
	_hud.set_modal_open(true)
	_robot.interactor.target_changed.emit(null)
	_hud.set_modal_open(false)
	assert_false(_interact_button.visible, "no target, no button")


func test_r_005_30_storage_button_key_translated() -> void:
	assert_eq(_storage_button.text, String(STORAGE_KEY), "the button text is a translation key")
	assert_ne(
		_storage_button.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated"
	)
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(STORAGE_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, STORAGE_KEY])


func _attack_button() -> AttackButton:
	return _hud.get_node("%AttackButton") as AttackButton


func _damage_flash() -> DamageFlash:
	return _hud.get_node("%DamageFlash") as DamageFlash


func _area(control: Control) -> float:
	return control.size.x * control.size.y


func test_r_007_16_attack_button_bottom_right_without_focus() -> void:
	var button: AttackButton = _attack_button()
	assert_not_null(button, "%AttackButton is an AttackButton")
	if button == null:
		return
	assert_true(button.visible, "always shown, on every platform")
	assert_eq(button.anchor_left, 1.0, "anchored to the right edge")
	assert_eq(button.anchor_right, 1.0, "anchored to the right edge")
	assert_eq(button.anchor_top, 1.0, "anchored to the bottom edge")
	assert_eq(button.anchor_bottom, 1.0, "anchored to the bottom edge")
	assert_lt(button.offset_right, 0.0, "inside the screen")
	assert_lt(button.offset_bottom, 0.0, "inside the screen")
	# Without focus, Space (attack) or Enter never press it by accident.
	assert_eq(button.focus_mode, Control.FOCUS_NONE, "never takes keyboard focus")
	assert_gt(_area(button), _area(_interact_button), "larger than the interact button")
	assert_gt(_area(button), _area(_storage_button), "and than the storage button")
	assert_lte(_interact_button.offset_bottom, button.offset_top, "the interact button sits above it")
	assert_eq(_interact_button.anchor_left, 1.0, "which stays anchored to the right")


func test_r_007_16_attack_key_translated() -> void:
	var button: AttackButton = _attack_button()
	assert_eq(button.text, String(ATTACK_KEY), "the button text is a translation key")
	assert_ne(button.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated")
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		assert_eq(translations.size(), 1, "translation file loaded for '%s'" % locale)
		if translations.size() == 1:
			var text: String = translations[0].get_message(ATTACK_KEY)
			assert_ne(text, "", "'%s' has a text for %s" % [locale, ATTACK_KEY])


func test_r_007_16_emits_attack_held_changed() -> void:
	watch_signals(_hud)
	_attack_button().button_down.emit()
	assert_signal_emitted_with_parameters(_hud, "attack_held_changed", [true])
	_attack_button().button_up.emit()
	assert_signal_emitted_with_parameters(_hud, "attack_held_changed", [false])
	assert_signal_emit_count(_hud, "attack_held_changed", 2)


func test_r_007_16_visible_while_modal() -> void:
	_hud.bind(_robot)
	_hud.set_modal_open(true)
	assert_true(_attack_button().visible, "the attack button stays; PlayerInput blocks the attack")


func test_r_007_16_released_when_hidden() -> void:
	watch_signals(_hud)
	_attack_button().button_down.emit()
	_hud.visible = false
	assert_signal_emitted_with_parameters(_hud, "attack_held_changed", [false])
	assert_signal_emit_count(_hud, "attack_held_changed", 2, "hiding a held button releases it")
	_hud.visible = true
	assert_signal_emit_count(_hud, "attack_held_changed", 2, "showing it again changes nothing")


func test_r_007_25_damage_flash_shows_and_fades() -> void:
	var flash: DamageFlash = _damage_flash()
	assert_not_null(flash, "%DamageFlash is a DamageFlash")
	if flash == null:
		return
	assert_false(flash.visible, "hidden until the player is hit")
	assert_eq(flash.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it never takes a click")
	assert_not_null(flash.texture, "it has its red edge")
	_hud.flash_damage(0.5)
	assert_true(flash.visible, "shown when the HUD is asked to flash")
	assert_eq(flash.modulate.a, 1.0, "at full strength")
	flash.advance(0.25)
	assert_eq(flash.modulate.a, 0.5, "fading with time")
	flash.advance(0.25)
	assert_false(flash.visible, "gone when its time is over")
	assert_false(flash.is_processing(), "and it stops processing")
	assert_false(_hud.is_processing(), "the HUD itself never polls (R-003-11)")


func test_r_007_25_damage_flash_restarts() -> void:
	var flash: DamageFlash = _damage_flash()
	_hud.flash_damage(0.5)
	flash.advance(0.25)
	_hud.flash_damage(0.5)
	assert_eq(flash.modulate.a, 1.0, "a new hit starts the flash again")
	_hud.flash_damage(0.0)
	assert_true(flash.is_flashing(), "a flash without duration is ignored")
