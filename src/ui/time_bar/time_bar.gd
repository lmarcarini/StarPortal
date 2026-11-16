class_name TimeBar
extends HBoxContainer
## Shows the in-game date and time and the clock speed (or "Paused"), with pause, slower and faster
## buttons, and the slow lamp (SlowLamp) while an event slows the clock: the speed shown is always
## the player's cruise speed, and Faster overrides a slow when it can. Reads the clock of
## SimClock.simulation and redraws on EventBus signals only; it never polls. The time actions
## (time_toggle_pause, time_faster, time_slower) are read in _input, before the GUI, so Space pauses
## instead of pressing the focused button, and once per press ([method InputActions.is_new_press]),
## so one trigger pull steps the speed once. A "call waiting" lamp (a button naming the faction)
## shows while an Earth faction's phone call waits; pressing it answers the call (m4-core-systems.md
## section 3).
## Bible: game-design.md#time-real-time-with-pause,
## technical-architecture.md#architecture-overview

const _ACTION_TOGGLE_PAUSE: StringName = &"time_toggle_pause"
const _ACTION_FASTER: StringName = &"time_faster"
const _ACTION_SLOWER: StringName = &"time_slower"

var _call_button := Button.new()
var _slow_lamp := SlowLamp.new()

@onready var _pause_button: Button = %PauseButton
@onready var _slower_button: Button = %SlowerButton
@onready var _faster_button: Button = %FasterButton
@onready var _date_label: Label = %DateLabel
@onready var _speed_label: Label = %SpeedLabel


func _ready() -> void:
	_pause_button.pressed.connect(SimClock.toggle_pause)
	_slower_button.pressed.connect(SimClock.slower)
	_faster_button.pressed.connect(faster)
	_call_button.visible = false
	_call_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_call_button.pressed.connect(_on_call_pressed)
	add_child(_call_button)
	add_child(_slow_lamp)
	move_child(_slow_lamp, _speed_label.get_index() + 1)
	refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.slow_changed.connect(_on_slow_changed)
	EventBus.paused_changed.connect(_on_paused_changed)
	EventBus.contact_pending.connect(_on_call_changed)
	EventBus.call_missed.connect(_on_call_changed)
	EventBus.conversation_started.connect(_on_conversation_changed)
	EventBus.conversation_ended.connect(_on_conversation_changed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.speed_changed.disconnect(_on_speed_changed)
	EventBus.slow_changed.disconnect(_on_slow_changed)
	EventBus.paused_changed.disconnect(_on_paused_changed)
	EventBus.contact_pending.disconnect(_on_call_changed)
	EventBus.call_missed.disconnect(_on_call_changed)
	EventBus.conversation_started.disconnect(_on_conversation_changed)
	EventBus.conversation_ended.disconnect(_on_conversation_changed)


func _input(event: InputEvent) -> void:
	if InputActions.is_new_press(event, _ACTION_TOGGLE_PAUSE):
		SimClock.toggle_pause()
	elif InputActions.is_new_press(event, _ACTION_FASTER):
		faster()
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
	_show_call(SimClock.simulation.state)


## Returns the buttons in focus order: pause, slower, faster, and the call lamp when lit.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = [_pause_button, _slower_button, _faster_button]
	if _call_button.visible:
		found.append(_call_button)
	return found


## Returns the call waiting lamp.
func get_call_button() -> Button:
	return _call_button


## Lights the lamp with the caller's name (the full line on its tooltip) while a phone call
## waits; disabled while another
## conversation runs.
func _show_call(state: GameState) -> void:
	var index: int = ContactRules.next_pending(state, &"phone")
	_call_button.visible = index >= 0
	if index < 0:
		return
	var faction_id: StringName = state.factions.pending[index].faction
	var faction: FactionDef = state.faction_defs.get(faction_id)
	var name: String = String(faction_id) if faction == null else tr(faction.name_key)
	_call_button.text = name
	_call_button.tooltip_text = tr(&"UI_CALL_WAITING").format({"name": name})
	_call_button.disabled = state.conversations.active != null


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
	var speed: String = _format_speed(SimClock.SPEEDS[index])
	_speed_label.text = tr("UI_SPEED_MULTIPLIER").format({"speed": speed})
	_slow_lamp.show_clock(clock)
	_faster_button.tooltip_text = _faster_hint(clock, speed)


func _faster_hint(clock: ClockState, speed: String) -> String:
	var key: StringName = SlowLamp.shown_key(clock)
	if key.is_empty():
		return tr(&"UI_FASTER_HINT")
	if TimeControl.can_override(clock):
		return tr(&"UI_FASTER_OVERRIDE").format({"speed": speed})
	return tr(&"UI_FASTER_NO_OVERRIDE").format({"reason": tr(SlowLamp.label_key(key))})


## Returns [param speed] without a trailing ".0": "0.5", "1", "10".
static func _format_speed(speed: float) -> String:
	if is_equal_approx(speed, roundf(speed)):
		return str(roundi(speed))
	return String.num(speed, 1)


func _on_tick_advanced(tick: int) -> void:
	_show_date(tick)


func _on_speed_changed(_speed_index: int) -> void:
	refresh()


func _on_slow_changed(_reasons: Array[StringName]) -> void:
	refresh()


## Faster: while slowed by a reason the player may override, overrides it (back to cruise
## speed) instead of raising the cruise speed.
func faster() -> void:
	var clock: ClockState = _get_clock()
	if clock != null and TimeControl.is_slowed(clock) and TimeControl.can_override(clock):
		SimClock.simulation.submit(OverrideSlowCommand.create())
		refresh()
		return
	SimClock.faster()


## The slow lamp.
func get_slow_lamp() -> SlowLamp:
	return _slow_lamp


func _on_paused_changed(_is_paused: bool) -> void:
	refresh()


func _on_call_pressed() -> void:
	if SimClock.simulation != null:
		SimClock.simulation.submit(AnswerCallCommand.new())
		refresh()


func _on_call_changed(_faction: StringName) -> void:
	refresh()


func _on_conversation_changed(_first: Variant, _second: Variant) -> void:
	refresh()
