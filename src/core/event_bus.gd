extends Node
## Autoload. Domain events for the presentation layer: views subscribe here and redraw.
## The simulation never references this node; bind_simulation() forwards its signals.
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

var _simulation: Simulation = null


## Forwards [param simulation]'s signals to this bus and disconnects any previously bound
## simulation. Passing null only unbinds.
func bind_simulation(simulation: Simulation) -> void:
	_unbind_simulation()
	if simulation == null:
		return
	_simulation = simulation
	simulation.day_started.connect(_on_day_started)
	simulation.month_closed.connect(_on_month_closed)
	simulation.command_rejected.connect(_on_command_rejected)
	simulation.pause_requested.connect(_on_pause_requested)


func _unbind_simulation() -> void:
	if _simulation == null:
		return
	_simulation.day_started.disconnect(_on_day_started)
	_simulation.month_closed.disconnect(_on_month_closed)
	_simulation.command_rejected.disconnect(_on_command_rejected)
	_simulation.pause_requested.disconnect(_on_pause_requested)
	_simulation = null


func _on_day_started(day_index: int) -> void:
	day_started.emit(day_index)


func _on_month_closed(year: int, month: int) -> void:
	month_closed.emit(year, month)


func _on_command_rejected(type: StringName, code: StringName) -> void:
	command_rejected.emit(type, code)


func _on_pause_requested(reason: StringName) -> void:
	pause_requested.emit(reason)
