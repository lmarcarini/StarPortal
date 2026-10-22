class_name TimeBar
extends HBoxContainer
## Shows the in-game date and time and the clock speed (or "Paused"), with pause, slower and
## faster buttons. Reads the clock of SimClock.simulation and redraws on EventBus signals
## only; it never polls. The time actions (time_toggle_pause, time_faster, time_slower) are
## read in _input, before the GUI, so Space pauses instead of pressing the focused button,
## and once per press ([method InputActions.is_new_press]), so one trigger pull steps the
## speed once.
## Bible: game-design.md#time-real-time-with-pause,
## technical-architecture.md#architecture-overview

const _ACTION_TOGGLE_PAUSE: StringName = &"time_toggle_pause"
const _ACTION_FASTER: StringName = &"time_faster"
const _ACTION_SLOWER: StringName = &"time_slower"

@onready var _pause_button: Button = %PauseButton
@onready var _slower_button: Button = %SlowerButton
@onready var _faster_button: Button = %FasterButton
@onready var _date_label: Label = %DateLabel
@onready var _speed_label: Label = %SpeedLabel


func _ready() -> void:
	_pause_button.pressed.connect(SimClock.toggle_pause)
	_slower_button.pressed.connect(SimClock.slower)
	_faster_button.pressed.connect(SimClock.faster)
	refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.paused_changed.connect(_on_paused_changed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.speed_changed.disconnect(_on_speed_changed)
	EventBus.paused_changed.disconnect(_on_paused_changed)


func _input(event: InputEvent) -> void:
	if InputActions.is_new_press(event, _ACTION_TOGGLE_PAUSE):
		SimClock.toggle_pause()
	elif InputActions.is_new_press(event, _ACTION_FASTER):
		SimClock.faster()
	elif InputActions.is_new_press(event, _ACTION_SLOWER):
		SimClock.slower()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Redraws the date, the speed and the pause button from the bound clock. Call it after
## SimClock.start() binds a new simulation, which emits no signal.
func refresh() -> void:
	var clock: ClockState = _get_clock()
	if clock == null:
		_date_label.text = ""
		_speed_label.text = ""
		_pause_button.text = tr("UI_TIME_PAUSE")
		return
	_show_date(clock.tick)
	_show_speed(clock)


## Returns the buttons in focus order: pause, slower, faster.
func get_buttons() -> Array[Button]:
	return [_pause_button, _slower_button, _faster_button]


func _get_clock() -> ClockState:
	if SimClock.simulation == null:
		return null
	return SimClock.simulation.state.clock


func _show_date(tick: int) -> void:
	var date: Dictionary = TimeMath.date_of(tick)
	_date_label.text = (
		"%04d-%02d-%02d %02d:%02d"
		% [date["year"], date["month"], date["day"], date["hour"], date["minute"]]
	)


func _show_speed(clock: ClockState) -> void:
	_pause_button.text = tr("UI_TIME_RESUME") if clock.is_paused else tr("UI_TIME_PAUSE")
	if clock.is_paused:
		_speed_label.text = tr("UI_SPEED_PAUSED")
		return
	var index: int = clampi(clock.speed_index, 0, SimClock.SPEEDS.size() - 1)
	_speed_label.text = tr("UI_SPEED_MULTIPLIER").format(
		{"speed": _format_speed(SimClock.SPEEDS[index])}
	)


## Returns [param speed] without a trailing ".0": "0.5", "1", "10".
static func _format_speed(speed: float) -> String:
	if is_equal_approx(speed, roundf(speed)):
		return str(roundi(speed))
	return String.num(speed, 1)


func _on_tick_advanced(tick: int) -> void:
	_show_date(tick)


func _on_speed_changed(_speed_index: int) -> void:
	refresh()


func _on_paused_changed(_is_paused: bool) -> void:
	refresh()
