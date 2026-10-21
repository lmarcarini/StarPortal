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
## Emitted when a system asks the clock to pause, e.g. &"incoming_wormhole".
@warning_ignore("unused_signal")
signal pause_requested(reason: StringName)

## The state every system and command reads and mutates.
var state: GameState
## Commands waiting for the next tick.
var commands: CommandQueue = CommandQueue.new()

var _systems: Array[SimSystem] = []


## Creates a simulation over [param initial_state]; [param systems] tick in list order.
func _init(initial_state: GameState, systems: Array[SimSystem] = []) -> void:
	assert(initial_state != null, "Simulation needs an initial state")
	state = initial_state
	_systems.assign(systems)
	commands.command_rejected.connect(_on_command_rejected)


## Submits [param command] to the queue; it applies at the start of the next tick.
func submit(command: Command) -> CommandResult:
	return commands.submit(command, state)


## Runs one tick: flush commands, tick each system, advance the clock, then run day and
## month hooks and emit their signals when the new tick starts a day or month.
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


func _start_day(new_tick: int) -> void:
	for system: SimSystem in _systems:
		system.on_day(state)
	day_started.emit(TimeMath.day_index(new_tick))


func _close_month(new_tick: int) -> void:
	for system: SimSystem in _systems:
		system.on_month(state)
	var ended: Dictionary = TimeMath.date_of(new_tick - 1)
	month_closed.emit(ended["year"], ended["month"])


func _on_command_rejected(type: StringName, code: StringName) -> void:
	command_rejected.emit(type, code)
