extends Node
## Autoload. Domain events for the presentation layer: views subscribe here and redraw.
## The simulation never references this node; bind_simulation() forwards its signals,
## and re-emits each outbox event (Simulation.event_posted) as the signal of the same name
## declared here, with the same arguments.
## Bible: technical-architecture.md#architecture-overview

## Emitted after each simulation tick, by the clock.
@warning_ignore("unused_signal")
signal tick_advanced(tick: int)
## Emitted at the first tick of each day, with the new day's index.
signal day_started(day_index: int)
## Emitted at the first tick of a month, reporting the month that just ended.
signal month_closed(year: int, month: int)
## Emitted when a submitted command fails validation.
signal command_rejected(type: StringName, code: StringName)
## Emitted when the simulation asks the clock to pause.
signal pause_requested(reason: StringName)
## Emitted when the clock speed changes.
@warning_ignore("unused_signal")
signal speed_changed(speed_index: int)
## Emitted when the clock pauses or resumes.
@warning_ignore("unused_signal")
signal paused_changed(is_paused: bool)
## Emitted when the clock's time-control mode changes, with the new ClockState.Mode.
@warning_ignore("unused_signal")
signal time_mode_changed(mode: int)
## Emitted after a save completes.
@warning_ignore("unused_signal")
signal game_saved(slot: StringName)
## Emitted after a load completes.
@warning_ignore("unused_signal")
signal game_loaded(slot: StringName)
## Emitted when a new clue reaches the base (posted through the outbox).
@warning_ignore("unused_signal")
signal clue_received(clue_id: StringName)
## Emitted when the player's note on a clue changes (posted through the outbox).
@warning_ignore("unused_signal")
signal clue_note_changed(clue_id: StringName)
## Emitted when the Address Workbench draft changes (posted through the outbox).
@warning_ignore("unused_signal")
signal workbench_changed

## Bus signals owned by the clock, the save service and the Simulation's own forwards. A
## posted domain event may not use one of these names: it is rejected like an undeclared
## name, so a system can never fake a tick, a day, a pause or a save. pause_requested is
## not listed: the Simulation routes that event to its own pause_requested signal.
const RESERVED_EVENT_NAMES: Array[StringName] = [
	&"tick_advanced",
	&"day_started",
	&"month_closed",
	&"command_rejected",
	&"speed_changed",
	&"paused_changed",
	&"time_mode_changed",
	&"game_saved",
	&"game_loaded",
]

var _simulation: Simulation = null
## Declared argument count per event name, -1 when no such signal is declared here.
var _arg_counts: Dictionary[StringName, int] = {}


## Forwards [param simulation]'s signals to this bus, including its outbox events, and
## disconnects any previously bound simulation. Passing null only unbinds. A posted event
## whose name is in [constant RESERVED_EVENT_NAMES], is not a signal declared here, or whose
## argument count differs from the signal's, is a programmer error: it asserts in debug,
## otherwise reports an error, and is not emitted.
func bind_simulation(simulation: Simulation) -> void:
	_unbind_simulation()
	if simulation == null:
		return
	_simulation = simulation
	simulation.day_started.connect(_on_day_started)
	simulation.month_closed.connect(_on_month_closed)
	simulation.command_rejected.connect(_on_command_rejected)
	simulation.pause_requested.connect(_on_pause_requested)
	simulation.event_posted.connect(_on_event_posted)


func _unbind_simulation() -> void:
	if _simulation == null:
		return
	_simulation.day_started.disconnect(_on_day_started)
	_simulation.month_closed.disconnect(_on_month_closed)
	_simulation.command_rejected.disconnect(_on_command_rejected)
	_simulation.pause_requested.disconnect(_on_pause_requested)
	_simulation.event_posted.disconnect(_on_event_posted)
	_simulation = null


func _on_day_started(day_index: int) -> void:
	day_started.emit(day_index)


func _on_month_closed(year: int, month: int) -> void:
	month_closed.emit(year, month)


func _on_command_rejected(type: StringName, code: StringName) -> void:
	command_rejected.emit(type, code)


func _on_pause_requested(reason: StringName) -> void:
	pause_requested.emit(reason)


func _on_event_posted(event_name: StringName, args: Array) -> void:
	if event_name in RESERVED_EVENT_NAMES:
		_report("EventBus: posted event '%s' uses a reserved bus signal name" % event_name)
		return
	var expected: int = _declared_arg_count(event_name)
	if expected < 0:
		_report("EventBus: no signal declared for posted event '%s'" % event_name)
		return
	if args.size() != expected:
		_report(
			(
				"EventBus: event '%s' posted with %d args, its signal declares %d"
				% [event_name, args.size(), expected]
			)
		)
		return
	emit_signal.callv([event_name] + args)


## Looks up the signal's argument count once per name. Signals inherited from Node, such
## as ready, are not domain events and count as undeclared.
func _declared_arg_count(event_name: StringName) -> int:
	if _arg_counts.has(event_name):
		return _arg_counts[event_name]
	var count: int = -1
	if not ClassDB.class_has_signal(get_class(), event_name):
		for info: Dictionary in get_signal_list():
			var signal_name: String = info["name"]
			if StringName(signal_name) == event_name:
				var signal_args: Array = info["args"]
				count = signal_args.size()
				break
	_arg_counts[event_name] = count
	return count


# In debug the assert stops here; release builds strip it and report through push_error.
func _report(message: String) -> void:
	assert(false, message)
	push_error(message)
