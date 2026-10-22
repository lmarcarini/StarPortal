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
## [constant PAUSE_EVENT] is emitted as [signal pause_requested] instead.
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


## Creates a simulation over [param initial_state]; [param systems] tick in list order.
func _init(initial_state: GameState, systems: Array[SimSystem] = []) -> void:
	assert(initial_state != null, "Simulation needs an initial state")
	state = initial_state
	_systems.assign(systems)
	commands.command_rejected.connect(_on_command_rejected)


## Submits [param command] and returns its [CommandResult]. While the clock is paused a valid
## command applies immediately, after any commands already queued, and is re-validated
## against them; otherwise it applies at the start of the next tick. Events posted by a
## command that applied at once are emitted before this returns; a queued command's events
## come out with its tick.
func submit(command: Command) -> CommandResult:
	var result: CommandResult = commands.submit(command, state)
	# Only a command applied at once can have posted: tick events are drained in the tick.
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


func _emit_events() -> void:
	if state.events.size() == 0:
		return
	for event: SimEvent in state.events.drain():
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
