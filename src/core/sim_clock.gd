extends Node
## Autoload. Fixed-step clock that drives the Simulation in real time at the chosen speed.
## Real seconds feed an accumulator in tick units; whole ticks run and the remainder carries
## over. Mode (running, paused, held) and speed live in [code]simulation.state.clock[/code],
## so they are saved; mode changes go through TimeControl. Ticks run only while RUNNING.
## Bible: technical-architecture.md#simulation-clock-and-commands,
## game-design.md#time-real-time-with-pause

## Ticks per real second at each speed index.
const SPEEDS: Array[float] = [0.5, 1.0, 3.0, 10.0]
## Real seconds per tick while slow mode is on (the drone feed is live).
const SLOW_MODE_SECONDS_PER_TICK: float = 6.0
## Most ticks one advance_by_seconds() call may run; excess time is dropped.
const MAX_TICKS_PER_FRAME: int = 60
## Tolerance when converting the accumulator to whole ticks, so float error never loses one.
const TICK_EPSILON: float = 1e-9

## The simulation this clock drives; null until start().
var simulation: Simulation = null

var _accumulator: float = 0.0
var _slow_mode: bool = false
var _cap_warned: bool = false


func _process(delta: float) -> void:
	advance_by_seconds(delta)


## Binds [param new_simulation] and the EventBus to this clock. Keeps the speed and mode
## saved in its clock; any previously bound simulation is released first.
func start(new_simulation: Simulation) -> void:
	stop()
	if new_simulation == null:
		return
	simulation = new_simulation
	simulation.pause_requested.connect(_on_pause_requested)
	EventBus.bind_simulation(simulation)


## Releases the bound simulation and the EventBus binding, and clears carried time.
func stop() -> void:
	_accumulator = 0.0
	_slow_mode = false
	if simulation == null:
		return
	simulation.pause_requested.disconnect(_on_pause_requested)
	EventBus.bind_simulation(null)
	simulation = null


## Player pause through TimeControl: pauses a running clock, or while HELD makes the clock
## pause when the hold ends. Emits EventBus.paused_changed / time_mode_changed on change.
func pause() -> void:
	_apply(TimeControl.request_pause)


## Player resume through TimeControl: resumes a paused clock, or while HELD makes the clock
## run when the hold ends. Emits EventBus.paused_changed / time_mode_changed on change.
func resume() -> void:
	_apply(TimeControl.request_resume)


## Pauses a running clock or resumes a paused one; while HELD, flips the mode the clock
## returns to when the hold ends.
func toggle_pause() -> void:
	_apply(TimeControl.request_toggle)


## Adds system hold [param reason] (e.g. &"cutscene"): time stops until every hold is
## released. Adding a reason already held is a no-op.
func hold(reason: StringName) -> void:
	_apply(TimeControl.add_hold.bind(reason))


## Releases system hold [param reason]; when the last hold goes, the clock returns to the
## mode the player wanted. Releasing a reason that is not held is a no-op.
func release(reason: StringName) -> void:
	_apply(TimeControl.release_hold.bind(reason))


## Returns the current time-control mode; PAUSED when no simulation is bound.
func get_mode() -> ClockState.Mode:
	if simulation == null:
		return ClockState.Mode.PAUSED
	return simulation.state.clock.mode


## Sets the speed to SPEEDS[[param index]] and emits EventBus.speed_changed. Indices out of
## range, or equal to the current one, are ignored.
func set_speed_index(index: int) -> void:
	if simulation == null:
		return
	if index < 0 or index >= SPEEDS.size():
		return
	if index == simulation.state.clock.speed_index:
		return
	simulation.state.clock.speed_index = index
	EventBus.speed_changed.emit(index)


## Steps up to the next speed; no-op at the fastest.
func faster() -> void:
	if simulation == null:
		return
	set_speed_index(simulation.state.clock.speed_index + 1)


## Steps down to the previous speed; no-op at the slowest.
func slower() -> void:
	if simulation == null:
		return
	set_speed_index(simulation.state.clock.speed_index - 1)


## Turns slow mode on or off. While on it overrides the speed with one tick per
## SLOW_MODE_SECONDS_PER_TICK real seconds; the saved speed index is untouched, so turning
## it off restores the previous speed.
func set_slow_mode(enabled: bool) -> void:
	if simulation == null:
		return
	_slow_mode = enabled


## Returns true while a simulation is bound and the clock is RUNNING.
func is_running() -> bool:
	if simulation == null:
		return false
	return not simulation.state.clock.is_paused


## Runs [param count] ticks immediately, regardless of pause. For tools and tests.
func step_ticks(count: int) -> void:
	if simulation == null:
		return
	for _i: int in range(count):
		_run_tick()


## Advances the clock by [param real_seconds] of real time and returns the ticks run. Runs
## at most MAX_TICKS_PER_FRAME ticks; beyond that the excess time is dropped. A pause or
## hold requested mid-call stops the remaining ticks.
func advance_by_seconds(real_seconds: float) -> int:
	if simulation == null:
		return 0
	if simulation.state.clock.is_paused or real_seconds <= 0.0:
		return 0
	_accumulator += real_seconds * _ticks_per_second()
	var due: int = floori(_accumulator + TICK_EPSILON)
	if due > MAX_TICKS_PER_FRAME:
		_warn_cap_once(due)
		due = MAX_TICKS_PER_FRAME
		_accumulator = 0.0
	else:
		_accumulator = maxf(_accumulator - due, 0.0)
	return _run_due_ticks(due)


func _run_due_ticks(due: int) -> int:
	var ran: int = 0
	while ran < due and not simulation.state.clock.is_paused:
		_run_tick()
		ran += 1
	return ran


## Runs one tick and emits tick_advanced, then speed_changed when the tick itself changed
## the speed (a lock drops it to 1×), so views redraw through the usual signal.
func _run_tick() -> void:
	var speed_before: int = simulation.state.clock.speed_index
	simulation.advance_tick()
	EventBus.tick_advanced.emit(simulation.state.clock.tick)
	var speed_after: int = simulation.state.clock.speed_index
	if speed_after != speed_before:
		EventBus.speed_changed.emit(speed_after)


func _ticks_per_second() -> float:
	if _slow_mode:
		return 1.0 / SLOW_MODE_SECONDS_PER_TICK
	return SPEEDS[clampi(simulation.state.clock.speed_index, 0, SPEEDS.size() - 1)]


## Runs [param rule], a TimeControl function taking the ClockState, then emits
## EventBus.time_mode_changed and paused_changed once each if the mode or pause changed.
func _apply(rule: Callable) -> void:
	if simulation == null:
		return
	var clock: ClockState = simulation.state.clock
	var mode_before: ClockState.Mode = clock.mode
	var paused_before: bool = clock.is_paused
	rule.call(clock)
	if clock.mode != mode_before:
		EventBus.time_mode_changed.emit(clock.mode)
	if clock.is_paused != paused_before:
		EventBus.paused_changed.emit(clock.is_paused)


func _warn_cap_once(due: int) -> void:
	if _cap_warned:
		return
	_cap_warned = true
	push_warning(
		(
			"SimClock: %d ticks due in one frame; capped at %d, excess time dropped"
			% [due, MAX_TICKS_PER_FRAME]
		)
	)


## Auto-pause: while RUNNING the clock pauses; while HELD only the mode after the hold
## becomes PAUSED.
func _on_pause_requested(reason: StringName) -> void:  # gdlint: ignore=unused-argument
	pause()
