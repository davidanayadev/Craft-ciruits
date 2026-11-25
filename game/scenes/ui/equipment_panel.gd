class_name EquipmentPanel
extends PanelContainer
## The equipment part of the inventory screen (spec 015, plan D17): one cell
## per slot (Brazos, Piernas, Core) with the equipped piece's icon and name or
## the no-piece state (R-015-31), a durability bar coloured by
## DurabilityDisplayData (R-015-32), and the robot's resulting stats
## (R-015-33). It follows equipment_changed, durability_changed and
## stats_changed while open, never _process (R-015-53). It only reports which
## slot was pressed: the inventory screen owns the selection and the actions.

## A slot cell was tapped.
signal slot_pressed(slot: PieceData.SlotType)

const NO_SELECTION := -1
## Indexed by PieceData.SlotType.
const _SLOT_TITLE_KEYS: Array[StringName] = [
	&"EQUIPMENT_SLOT_ARMS", &"EQUIPMENT_SLOT_LEGS", &"EQUIPMENT_SLOT_CORE"
]
const _NO_PIECE_KEYS: Array[StringName] = [
	&"EQUIPMENT_NO_ARMS", &"EQUIPMENT_NO_LEGS", &"EQUIPMENT_NO_CORE"
]
const _CANNOT_RUN_KEY := &"STAT_CANNOT_RUN"
const _CANNOT_RUN_NODE := &"StatCannotRun"

@export var display: DurabilityDisplayData
## Fill colour of each DurabilityDisplayData.Band, indexed by its value.
@export var band_colors: Array[Color] = []
## Font size of the stat lines; presentation.
@export var stat_font_size: int = 26

var _equipment: EquipmentComponent = null
var _stats: StatsComponent = null
var _selected_slot: int = NO_SELECTION

@onready var _slot_buttons: Array[Button] = [%ArmsButton, %LegsButton, %CoreButton]
@onready var _slot_titles: Array[Label] = [%ArmsTitle, %LegsTitle, %CoreTitle]
@onready var _bars: Array[ProgressBar] = [%ArmsBar, %LegsBar, %CoreBar]
@onready var _stats_list: VBoxContainer = %StatsList


func _ready() -> void:
	for slot: int in _slot_buttons.size():
		_slot_titles[slot].text = String(_SLOT_TITLE_KEYS[slot])
		_slot_buttons[slot].pressed.connect(_on_slot_button_pressed.bind(slot))


func bind(equipment: EquipmentComponent, stats: StatsComponent) -> void:
	if equipment == null or stats == null:
		push_error("EquipmentPanel: bind() needs an EquipmentComponent and a StatsComponent.")
		return
	_equipment = equipment
	_stats = stats
	equipment.equipment_changed.connect(_refresh_slots)
	equipment.durability_changed.connect(_on_durability_changed)
	stats.stats_changed.connect(_refresh_stats)
	_refresh_slots()
	_refresh_stats()


## Stops following the bound components (the screen closes).
func unbind() -> void:
	if _equipment == null:
		return
	_equipment.equipment_changed.disconnect(_refresh_slots)
	_equipment.durability_changed.disconnect(_on_durability_changed)
	_stats.stats_changed.disconnect(_refresh_stats)
	_equipment = null
	_stats = null


## Highlights slot; NO_SELECTION clears it.
func set_selected_slot(slot: int) -> void:
	_selected_slot = slot
	for index: int in _slot_buttons.size():
		_slot_buttons[index].set_pressed_no_signal(index == slot)


func _refresh_slots() -> void:
	var pieces: Array[ItemStack] = _equipment.get_pieces()
	for slot: int in pieces.size():
		_show_slot(slot, pieces[slot])


func _show_slot(slot: int, piece: ItemStack) -> void:
	var button: Button = _slot_buttons[slot]
	var bar: ProgressBar = _bars[slot]
	if piece == null:
		button.icon = null
		button.text = String(_NO_PIECE_KEYS[slot])
		bar.visible = false
		return
	var data: PieceData = piece.item as PieceData
	button.icon = data.icon
	button.text = String(data.name_key)
	bar.max_value = data.durability_max
	bar.visible = true
	_show_durability(slot, piece.durability)


func _show_durability(slot: int, durability: int) -> void:
	var bar: ProgressBar = _bars[slot]
	bar.value = durability
	var band: DurabilityDisplayData.Band = display.band_of(durability, roundi(bar.max_value))
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = band_colors[band] if band < band_colors.size() else Color.WHITE
	bar.add_theme_stylebox_override(&"fill", fill)


## Which band the bar of slot shows; for tests and the docs of R-015-32.
func get_band(slot: PieceData.SlotType) -> DurabilityDisplayData.Band:
	return display.band_of(roundi(_bars[slot].value), roundi(_bars[slot].max_value))


func _on_durability_changed(slot: PieceData.SlotType, durability: int) -> void:
	_show_durability(slot, durability)


## The lines are created once and their text updated, so nothing is freed on
## every stats_changed; without legs the running speed gives way to "cannot run".
func _refresh_stats() -> void:
	_set_stat(&"STAT_ATTACK_DAMAGE", roundi(_stats.get_stat(StatIds.ATTACK_DAMAGE)))
	_set_stat(&"STAT_ATTACKS_PER_SECOND", _stats.get_stat(StatIds.ATTACKS_PER_SECOND))
	_set_stat(&"STAT_BATTERY_PER_SWING", _stats.get_stat(StatIds.BATTERY_PER_SWING))
	_set_stat(&"STAT_WALK_SPEED", _stats.get_stat(StatIds.WALK_SPEED))
	var movement: MovementStatsData = _stats.get_movement()
	_set_stat(&"STAT_RUN_SPEED", movement.run_speed).visible = movement.can_run
	_line(_CANNOT_RUN_NODE).text = tr(_CANNOT_RUN_KEY)
	_line(_CANNOT_RUN_NODE).visible = not movement.can_run
	_set_stat(&"STAT_WALK_DRAIN", _stats.get_stat(StatIds.WALK_DRAIN))
	_set_stat(&"STAT_PASSIVE_DRAIN", _stats.get_stat(StatIds.PASSIVE_DRAIN))
	_set_stat(&"STAT_MAX_BATTERY", roundi(_stats.get_stat(StatIds.MAX_BATTERY)))


## The line named after key, its translated text formatting value.
func _set_stat(key: StringName, value: Variant) -> Label:
	var label: Label = _line(key)
	label.text = tr(key) % value
	return label


## The line node_name of the list, created the first time in call order.
func _line(node_name: StringName) -> Label:
	var label: Label = _stats_list.get_node_or_null(String(node_name)) as Label
	if label != null:
		return label
	label = Label.new()
	label.name = node_name
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override(&"font_size", stat_font_size)
	_stats_list.add_child(label)
	return label


func _on_slot_button_pressed(slot: int) -> void:
	# The button only reports: the screen decides what is selected.
	_slot_buttons[slot].set_pressed_no_signal(slot == _selected_slot)
	slot_pressed.emit(slot)
