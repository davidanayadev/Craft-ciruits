class_name WindGenerator
extends StaticBody3D
## A placed wind generator (spec 012, BALANCE §5.2): presentation only. Its
## state lives in a WindGeneratorComponent under World (plan D5); this instance
## shows it on a 3D label, "n/maximum" and the time to the next battery or
## "full" (R-012-21), repainted on generator_changed and once per second by a
## presentation Timer, never in _process (plan D17). The blades turn with a
## looping AnimationPlayer (R-012-22). Interacting only announces `used`.

## A player interacted with this generator.
signal used(user: Node3D)

const STORED_KEY := &"GENERATOR_STORED"
const NEXT_KEY := &"GENERATOR_NEXT"
const FULL_KEY := &"GENERATOR_FULL"

var _state: WindGeneratorComponent = null
var _time_service: ITimeService = null

@onready var _interactable: InteractableComponent = %Interactable
@onready var _label: Label3D = %Label
@onready var _refresh_timer: Timer = %RefreshTimer


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_refresh_timer.timeout.connect(_refresh)
	_refresh()


## Shows state, read with time_service. Without a state (the placement
## preview) the label stays empty and nothing fails.
func bind_state(state: WindGeneratorComponent, time_service: ITimeService) -> void:
	if _state != null and _state.generator_changed.is_connected(_refresh):
		_state.generator_changed.disconnect(_refresh)
	_state = state
	_time_service = time_service
	if _state != null:
		_state.generator_changed.connect(_refresh)
	_refresh()


## "h:mm:ss", digits only (no text to translate).
static func format_time_left(seconds: int) -> String:
	var left: int = maxi(seconds, 0)
	return "%d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60]


func _refresh() -> void:
	if _state == null or _state.config == null or _time_service == null:
		_label.text = ""
		return
	var now: int = _time_service.now_unix()
	var left: int = _state.get_seconds_to_next(now)
	var second_line: String = tr(FULL_KEY) if left < 0 else tr(NEXT_KEY) % format_time_left(left)
	var first_line: String = tr(STORED_KEY) % [_state.get_stored(now), _state.config.max_stored]
	_label.text = "%s\n%s" % [first_line, second_line]


func _on_interacted(interactor: Node3D) -> void:
	used.emit(interactor)
