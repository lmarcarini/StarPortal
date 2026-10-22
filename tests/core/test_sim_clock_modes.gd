## Tests for SimClock's time-control modes: holds, player and auto pause during holds,
## exactly-once EventBus.time_mode_changed / paused_changed, and slow mode across holds.
## Each test uses its own clock instance, not the autoload. (Separate from test_sim_clock.gd,
## which is at the 20-public-method lint limit.)
## Bible: technical-architecture.md#simulation-clock-and-commands,
## game-design.md#time-real-time-with-pause
extends GdUnitTestSuite

const SimClockScript = preload("res://src/core/sim_clock.gd")

var _clock: SimClockScript
var _simulation: Simulation
var _pauses: Array[bool] = []
var _modes: Array[int] = []


func before_test() -> void:
	_pauses.clear()
	_modes.clear()
	_clock = SimClockScript.new()
	_clock.set_process(false)
	add_child(_clock)
	_simulation = Simulation.new(GameState.new())
	EventBus.paused_changed.connect(_on_paused_changed)
	EventBus.time_mode_changed.connect(_on_time_mode_changed)


func after_test() -> void:
	EventBus.paused_changed.disconnect(_on_paused_changed)
	EventBus.time_mode_changed.disconnect(_on_time_mode_changed)
	_clock.stop()
	_clock.free()


func _start_running(speed_index: int = 1) -> void:
	_simulation.state.clock.speed_index = speed_index
	_simulation.state.clock.is_paused = false
	_clock.start(_simulation)


func _on_paused_changed(is_paused: bool) -> void:
	_pauses.append(is_paused)


func _on_time_mode_changed(mode: int) -> void:
	_modes.append(mode)


## A hold stops ticks; releasing it resumes. Each change emits time_mode_changed and
## paused_changed exactly once.
func test_hold_and_release_stop_and_resume_ticks() -> void:
	_start_running(1)
	_clock.hold(&"cutscene")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.HELD)
	assert_bool(_clock.is_running()).is_false()
	assert_int(_clock.advance_by_seconds(5.0)).is_equal(0)
	_clock.release(&"cutscene")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.RUNNING)
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(1)
	assert_array(_modes).is_equal([ClockState.Mode.HELD, ClockState.Mode.RUNNING])
	assert_array(_pauses).is_equal([true, false])


## A player pause during a hold emits nothing until the release, which ends PAUSED:
## time_mode_changed once per mode change, no paused_changed (it never stopped pausing).
func test_pause_during_hold_is_kept_after_release() -> void:
	_start_running(1)
	_clock.hold(&"cutscene")
	_clock.hold(&"decision")
	_clock.pause()
	_clock.hold(&"cutscene")
	_clock.release(&"unknown")
	_clock.release(&"cutscene")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.HELD)
	_clock.release(&"decision")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.PAUSED)
	assert_array(_modes).is_equal([ClockState.Mode.HELD, ClockState.Mode.PAUSED])
	assert_array(_pauses).is_equal([true])


## Resume and toggle during a hold change only the mode after the hold.
func test_resume_and_toggle_during_hold() -> void:
	_clock.start(_simulation)
	_clock.hold(&"cutscene")
	_clock.resume()
	assert_int(_simulation.state.clock.mode_after_hold).is_equal(ClockState.Mode.RUNNING)
	_clock.toggle_pause()
	assert_int(_simulation.state.clock.mode_after_hold).is_equal(ClockState.Mode.PAUSED)
	_clock.toggle_pause()
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.HELD)
	_clock.release(&"cutscene")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.RUNNING)
	assert_array(_modes).is_equal([ClockState.Mode.HELD, ClockState.Mode.RUNNING])
	assert_array(_pauses).is_equal([false])


## Auto-pause while RUNNING pauses and emits the mode change once.
func test_pause_requested_while_running_emits_mode_change() -> void:
	_start_running(1)
	_simulation.pause_requested.emit(&"incoming_wormhole")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.PAUSED)
	assert_array(_modes).is_equal([ClockState.Mode.PAUSED])


## Auto-pause while HELD only makes the clock pause when the hold ends.
func test_pause_requested_while_held_sets_mode_after_hold() -> void:
	_start_running(1)
	_clock.hold(&"cutscene")
	_simulation.pause_requested.emit(&"incoming_wormhole")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.HELD)
	assert_int(_simulation.state.clock.mode_after_hold).is_equal(ClockState.Mode.PAUSED)
	assert_array(_modes).is_equal([ClockState.Mode.HELD])
	_clock.release(&"cutscene")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.PAUSED)


## A hold added mid-call stops the remaining ticks.
func test_hold_mid_advance_stops_remaining_ticks() -> void:
	_start_running(3)
	var hold_at_two := func(tick: int) -> void:
		if tick == 2:
			_clock.hold(&"cutscene")
	EventBus.tick_advanced.connect(hold_at_two)
	var ran := _clock.advance_by_seconds(1.0)
	EventBus.tick_advanced.disconnect(hold_at_two)
	assert_int(ran).is_equal(2)


## Slow mode set in any mode survives holds and applies whenever the clock runs.
func test_slow_mode_works_in_every_mode_and_across_holds() -> void:
	_simulation.state.clock.speed_index = 3
	_clock.start(_simulation)
	_clock.set_slow_mode(true)
	_clock.hold(&"cutscene")
	_clock.set_slow_mode(false)
	_clock.set_slow_mode(true)
	_clock.resume()
	assert_int(_clock.advance_by_seconds(6.0)).is_equal(0)
	_clock.release(&"cutscene")
	assert_int(_clock.advance_by_seconds(5.9)).is_equal(0)
	assert_int(_clock.advance_by_seconds(0.1)).is_equal(1)
	_clock.hold(&"decision")
	_clock.release(&"decision")
	assert_int(_clock.advance_by_seconds(6.0)).is_equal(1)
	assert_int(_simulation.state.clock.speed_index).is_equal(3)


## With no simulation, hold, release and get_mode are safe no-ops.
func test_hold_without_simulation_is_a_no_op() -> void:
	_clock.hold(&"cutscene")
	_clock.release(&"cutscene")
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.PAUSED)
	assert_array(_modes).is_empty()
	assert_array(_pauses).is_empty()
