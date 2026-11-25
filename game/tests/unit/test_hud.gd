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
## Spec 009: an "Edit base" button, hidden unless the base is loaded, that
## emits edit_base_pressed (R-009-59); the interact button also hides while a
## travel or a death blocks the robot (R-009-07).
## Spec 012: use_refused shows its notice (R-012-24); show_notice with arguments
## shows tr(key) % args (D18, R-012-18).

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ROBOT_SCENE := preload("res://scenes/entities/robot.tscn")
## ProgressBar snaps its value to its step.
const BAR_TOLERANCE := 0.01
const STORAGE_KEY := &"HUD_STORAGE"
const ATTACK_KEY := &"HUD_ATTACK"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "es"]
const INPUT_FRAMES := 2
const SAVE_NOTICE_KEYS: Array[StringName] = [
	&"MSG_GAME_SAVED",
	&"ERR_SAVE_FAILED",
	&"MSG_WORLD_DAMAGED",
	&"MSG_PROFILE_DAMAGED",
	&"MSG_SAVE_NEWER_VERSION",
]

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
	_robot.interactor.target_changed.emit(_new_target(&"PROMPT_USE"))
	assert_eq(_interact_button.text, "PROMPT_USE", "it follows a change of target")
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
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_SCREEN)
	assert_false(_interact_button.visible, "hidden while a screen is open")
	_robot.interactor.target_changed.emit(_new_target(&"PROMPT_USE"))
	assert_false(_interact_button.visible, "a new target does not bring it back while open")
	_robot.player_input.set_input_blocked(false, PlayerInput.REASON_SCREEN)
	assert_true(_interact_button.visible, "shown again when the screen closes")
	assert_eq(_interact_button.text, "PROMPT_USE", "with the current target's prompt")
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_SCREEN)
	_robot.interactor.target_changed.emit(null)
	_robot.player_input.set_input_blocked(false, PlayerInput.REASON_SCREEN)
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
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_SCREEN)
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


func test_r_009_59_edit_button_only_in_base() -> void:
	var button: Button = _hud.get_node("%EditBaseButton") as Button
	assert_false(button.visible, "hidden until the base is loaded")
	_hud.set_edit_base_available(true)
	assert_true(button.visible, "shown in the base")
	watch_signals(_hud)
	button.pressed.emit()
	assert_signal_emit_count(_hud, "edit_base_pressed", 1, "pressing it is a request")
	_hud.set_edit_base_available(false)
	assert_false(button.visible, "hidden elsewhere")


func test_r_009_59_text_is_key() -> void:
	var button: Button = _hud.get_node("%EditBaseButton") as Button
	assert_eq(button.text, "HUD_EDIT_BASE", "a translation key")
	assert_ne(button.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "translated")
	for locale: String in SUPPORTED_LOCALES:
		var text: String = ""
		for translation: Translation in TranslationServer.find_translations(locale, true):
			text = translation.get_message(&"HUD_EDIT_BASE")
			if not text.is_empty():
				break
		assert_ne(text, "", "HUD_EDIT_BASE in %s" % locale)


func test_r_009_07_interact_hidden_while_travelling() -> void:
	_hud.bind(_robot)
	_robot.interactor.target_changed.emit(_new_target(&"PROMPT_TRAVEL"))
	assert_true(_interact_button.visible, "shown with a target")
	_robot.player_input.set_input_blocked(true, PlayerInput.REASON_TRAVEL)
	assert_false(_interact_button.visible, "hidden while travelling")
	_robot.player_input.set_input_blocked(false, PlayerInput.REASON_TRAVEL)
	assert_true(_interact_button.visible, "back after the travel")


func test_r_010_45_notice_shown() -> void:
	assert_false(_message_label.visible, "no message at the start")
	_hud.show_notice(SaveManager.ERR_SAVE_FAILED)
	assert_true(_message_label.visible, "the notice shows")
	assert_eq(_message_label.text, String(SaveManager.ERR_SAVE_FAILED), "the text is the translation key")
	assert_ne(
		_message_label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "and it is translated"
	)
	assert_false(_message_timer.is_stopped(), "on the same timer as the inventory message")
	_message_timer.timeout.emit()
	assert_false(_message_label.visible, "it hides when the timer ends")


func test_r_010_45_new_notice_replaces_the_showing_one() -> void:
	_hud.show_notice(SaveManager.ERR_SAVE_FAILED)
	_hud.show_notice(SaveManager.MSG_WORLD_DAMAGED)
	assert_eq(_message_label.text, String(SaveManager.MSG_WORLD_DAMAGED), "the last one is shown")
	assert_true(_message_label.visible, "still visible")


func test_r_010_45_save_manager_notice_reaches_the_hud_through_show_notice() -> void:
	SaveManager.save_notice.connect(_hud.show_notice)
	SaveManager.save_notice.emit(SaveManager.MSG_PROFILE_DAMAGED)
	SaveManager.save_notice.disconnect(_hud.show_notice)
	assert_true(_message_label.visible, "a notice of the save shows")
	assert_eq(_message_label.text, String(SaveManager.MSG_PROFILE_DAMAGED), "with its key")


func test_r_010_62_saved_notice_only_on_recharge() -> void:
	for reason: StringName in [
		SaveManager.REASON_NEW_WORLD,
		SaveManager.REASON_ENTERED_BASE,
		SaveManager.REASON_DIED,
		SaveManager.REASON_STRUCTURE_BUILT,
		SaveManager.REASON_STRUCTURE_MOVED,
		SaveManager.REASON_CLOSE,
		SaveManager.REASON_BACKGROUND,
	]:
		EventBus.game_saved.emit(reason)
		assert_false(_message_label.visible, "'%s' is silent" % reason)
	EventBus.game_saved.emit(SaveManager.REASON_RECHARGED)
	assert_true(_message_label.visible, "the recharge is announced")
	assert_eq(_message_label.text, String(Hud.MSG_GAME_SAVED), "with the 'Game saved' key")
	_message_timer.timeout.emit()
	assert_false(_message_label.visible, "and it hides on its timer")


func test_r_010_62_save_notice_keys_translated() -> void:
	for locale: String in SUPPORTED_LOCALES:
		for key: StringName in SAVE_NOTICE_KEYS:
			var text: String = ""
			for translation: Translation in TranslationServer.find_translations(locale, true):
				text = translation.get_message(key)
				if not text.is_empty():
					break
			assert_ne(text, "", "%s in %s" % [key, locale])


func test_r_012_24_shows_use_refused() -> void:
	_hud.bind(_robot)
	assert_false(_message_label.visible, "no message at the start")
	_robot.use_refused.emit(ConsumableRules.ERR_BATTERY_FULL)
	assert_true(_message_label.visible, "the refusal shows")
	assert_true(
		_message_label.text in [String(ConsumableRules.ERR_BATTERY_FULL), tr(ConsumableRules.ERR_BATTERY_FULL)],
		"the text is the key or its translation"
	)
	assert_false(_message_timer.is_stopped(), "on the shared message timer")
	_robot.use_refused.emit(ConsumableRules.ERR_NO_PORTABLE_BATTERY)
	assert_true(
		_message_label.text
		in [
			String(ConsumableRules.ERR_NO_PORTABLE_BATTERY),
			tr(ConsumableRules.ERR_NO_PORTABLE_BATTERY),
		],
		"a new refusal replaces the showing one"
	)
	_message_timer.timeout.emit()
	assert_false(_message_label.visible, "it hides when the timer ends")


func test_r_012_24_use_refused_from_a_real_refusal() -> void:
	_hud.bind(_robot)
	_robot.request_use_consumable()
	assert_true(_message_label.visible, "no portable battery shows a notice")


func test_r_012_24_use_refused_keys_translated() -> void:
	for locale: String in SUPPORTED_LOCALES:
		for key: StringName in [
			ConsumableRules.ERR_BATTERY_FULL,
			ConsumableRules.ERR_NO_PORTABLE_BATTERY,
		]:
			var text: String = ""
			for translation: Translation in TranslationServer.find_translations(locale, true):
				text = translation.get_message(key)
				if not text.is_empty():
					break
			assert_ne(text, "", "%s in %s" % [key, locale])


func test_r_012_20_notice_with_arguments_formats_the_translation() -> void:
	var args: Array = [3, 5]
	_hud.show_notice(&"GENERATOR_STORED", args)
	assert_true(_message_label.visible, "the notice shows")
	assert_eq(_message_label.text, tr(&"GENERATOR_STORED") % args, "tr(key) % args")
	assert_false(_message_timer.is_stopped(), "on the shared timer")
	_hud.show_notice(&"GENERATOR_STORED", [1, 5])
	assert_eq(_message_label.text, tr(&"GENERATOR_STORED") % [1, 5], "a new notice replaces it")


func test_r_012_20_notice_without_arguments_unchanged() -> void:
	_hud.show_notice(SaveManager.ERR_SAVE_FAILED)
	assert_eq(_message_label.text, String(SaveManager.ERR_SAVE_FAILED), "no args: the key, as before")


# --- Spec 015: broken piece notice and low battery colour ----------------------


func _fill_is_low() -> bool:
	return _bar.has_theme_stylebox_override(&"fill") and _bar.get_theme_stylebox(&"fill") == _hud.low_battery_fill


func test_r_015_24_piece_broken_notice_names_piece() -> void:
	_hud.bind(_robot)
	var legs: PieceData = _robot.equipment.get_piece(PieceData.SlotType.LEGS).item as PieceData
	for i: int in ceili(float(legs.durability_max) / _robot.stats.get_stat(StatIds.DURABILITY_PER_HIT)):
		_robot.receive_hit(0.0, null)
	assert_null(_robot.equipment.get_piece(PieceData.SlotType.LEGS), "the legs broke")
	assert_true(_message_label.visible, "the short message shows")
	assert_eq(_message_label.text, tr(Hud.MSG_PIECE_BROKEN) % tr(legs.name_key), "naming the piece")


func test_r_015_24_piece_broken_key_translated() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var translations: Array[Translation] = TranslationServer.find_translations(locale, true)
		if translations.size() != 1:
			fail_test("no translation file for %s" % locale)
			continue
		assert_ne(translations[0].get_message(Hud.MSG_PIECE_BROKEN), "", "%s has a text" % locale)


func test_r_015_43_bar_orange_below_threshold() -> void:
	_hud.bind(_robot)
	assert_not_null(_hud.low_battery_fill, "the HUD has a low battery fill")
	assert_false(_fill_is_low(), "a full battery has its normal colour")
	var threshold: float = _robot.battery.get_maximum() * _robot.battery.config.low_threshold_ratio
	_robot.battery.consume(_robot.battery.get_current() - threshold)
	assert_false(_fill_is_low(), "at the threshold it is not low yet")
	_robot.battery.consume(0.5)
	assert_true(_fill_is_low(), "below the threshold: orange")
	_robot.battery.recharge_full()
	assert_false(_fill_is_low(), "a recharge brings the normal colour back")


func test_r_015_43_follows_load_and_bonus() -> void:
	_hud.bind(_robot)
	var threshold: float = _robot.battery.get_maximum() * _robot.battery.config.low_threshold_ratio
	_robot.battery.from_save_data({"current": threshold - 1.0})
	assert_true(_fill_is_low(), "a load below the threshold paints it, without battery_low")
	_robot.battery.from_save_data({"current": threshold + 2.0})
	assert_false(_fill_is_low(), "a load above it clears it")
	_robot.battery.set_maximum_bonus(20.0)
	assert_true(_fill_is_low(), "a larger maximum raises the threshold above the charge")
	_robot.battery.add(20.0)
	assert_false(_fill_is_low(), "a portable battery takes it back above")
