class_name Simulation
extends RefCounted
## Owns the game state, its systems and the command queue, and advances them one tick at
## a time in a fixed order. Plain RefCounted with no scene access, so it runs headless.
## Bible: technical-architecture.md#simulation-clock-and-commands

## Emitted at the first tick of each day, with the new day's index.
signal day_started(day_index: int)
## Emitted at the first tick of a month, reporting the month that just ended.
signal month_closed(year: int, month: int)
## Forwarded from the command queue when a command fails validation.
signal command_rejected(type: StringName, code: StringName)
## Emitted when a system asks the clock to pause, e.g. &"incoming_wormhole". Systems and
## commands ask by posting [constant PAUSE_EVENT] with [code][reason][/code].
signal pause_requested(reason: StringName)
## Emitted once per domain event drained from [code]state.events[/code], in posting order:
## at the end of each tick, and after a command that applied at once while paused.
## [constant PAUSE_EVENT] is emitted as [signal pause_requested] instead. Just before an
## event is emitted, the entries LogRules gives for it are added to the operations log at the
## clock's tick, so the log follows the posting order. Emission never
## nests: a handler may submit a command, and that command's events come out after the
## events already waiting, from the same emission.
signal event_posted(name: StringName, args: Array)

## Outbox event name emitted as [signal pause_requested] (args [code][reason][/code]),
## never as [signal event_posted].
const PAUSE_EVENT: StringName = &"pause_requested"

## The state every system and command reads and mutates.
var state: GameState
## Commands waiting for the next tick. Safe to replace: the old queue's
## command_rejected is disconnected and the new one's forwarded. Assigning the same queue
## again is a no-op; null fails an assert and the old queue is kept.
var commands: CommandQueue = CommandQueue.new():
	set(value):
		assert(value != null, "Simulation.commands cannot be null")
		if value == null or value == commands:
			return
		if commands.command_rejected.is_connected(_on_command_rejected):
			commands.command_rejected.disconnect(_on_command_rejected)
		commands = value
		commands.command_rejected.connect(_on_command_rejected)

var _systems: Array[SimSystem] = []
var _emitting: bool = false


## Creates a simulation over [param initial_state]; [param systems] tick in list order.
func _init(initial_state: GameState, systems: Array[SimSystem] = []) -> void:
	assert(initial_state != null, "Simulation needs an initial state")
	state = initial_state
	_systems.assign(systems)
	commands.command_rejected.connect(_on_command_rejected)


## Submits [param command] and returns its [CommandResult]. While the clock is paused a valid
## command applies immediately, after any commands already queued, and is re-validated
## against them; otherwise it applies at the start of the next tick. While paused, events
## posted by the commands that applied are emitted before this returns (or, when called
## from an event handler, by the emission already running); a queued command's events come
## out with its tick.
func submit(command: Command) -> CommandResult:
	var applies_now: bool = state.clock.is_paused
	var result: CommandResult = commands.submit(command, state)
	if applies_now:
		_emit_events()
	return result


## Runs one tick: flush commands, tick each system, advance the clock, run day and month
## hooks and emit their signals when the new tick starts a day or month, then emit the
## tick's events last.
func advance_tick() -> void:
	commands.flush(state)
	for system: SimSystem in _systems:
		system.tick(state)
	state.clock.tick += 1
	var new_tick: int = state.clock.tick
	if TimeMath.is_day_start(new_tick):
		_start_day(new_tick)
	if TimeMath.is_month_start(new_tick):
		_close_month(new_tick)
	_emit_events()


func _start_day(new_tick: int) -> void:
	for system: SimSystem in _systems:
		system.on_day(state)
	day_started.emit(TimeMath.day_index(new_tick))


func _close_month(new_tick: int) -> void:
	for system: SimSystem in _systems:
		system.on_month(state)
	var ended: Dictionary = TimeMath.date_of(new_tick - 1)
	month_closed.emit(ended["year"], ended["month"])


# Drains until the outbox stays empty. A nested call (a handler submitting while paused)
# returns at once; the running loop picks up its events, keeping posting order.
func _emit_events() -> void:
	if _emitting:
		return
	_emitting = true
	while state.events.size() > 0:
		for event: SimEvent in state.events.drain():
			_emit_event(event)
	_emitting = false


func _emit_event(event: SimEvent) -> void:
	for entry: LogEntry in LogRules.entries_for(event.name, event.args, state, state.clock.tick):
		state.operations_log.add(entry)
	if event.name == PAUSE_EVENT:
		_emit_pause_request(event.args)
	else:
		event_posted.emit(event.name, event.args)


func _emit_pause_request(args: Array) -> void:
	if args.size() != 1 or not (args[0] is StringName or args[0] is String):
		var message: String = "Simulation: pause_requested needs args [reason], got %s" % [args]
		assert(false, message)
		push_error(message)
		return
	var reason: String = str(args[0])
	pause_requested.emit(StringName(reason))


func _on_command_rejected(type: StringName, code: StringName) -> void:
	command_rejected.emit(type, code)
