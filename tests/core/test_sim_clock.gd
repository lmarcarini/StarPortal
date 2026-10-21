## Tests for SimClock: fixed-step accumulator, per-frame cap, pause, speed, slow mode and
## EventBus signals. Each test uses its own clock instance, not the autoload.
## Bible: technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const SimClockScript = preload("res://src/core/sim_clock.gd")

var _clock: SimClockScript
var _simulation: Simulation
var _ticks: Array[int] = []
var _pauses: Array[bool] = []
var _speeds: Array[int] = []


func before_test() -> void:
	_ticks.clear()
	_pauses.clear()
	_speeds.clear()
	_clock = SimClockScript.new()
	_clock.set_process(false)
	add_child(_clock)
	_simulation = Simulation.new(GameState.new())
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.paused_changed.connect(_on_paused_changed)
	EventBus.speed_changed.connect(_on_speed_changed)


func after_test() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.paused_changed.disconnect(_on_paused_changed)
	EventBus.speed_changed.disconnect(_on_speed_changed)
	_clock.stop()
	_clock.free()


func _start_running(speed_index: int = 1) -> void:
	_simulation.state.clock.speed_index = speed_index
	_simulation.state.clock.is_paused = false
	_clock.start(_simulation)


func _on_tick_advanced(tick: int) -> void:
	_ticks.append(tick)


func _on_paused_changed(is_paused: bool) -> void:
	_pauses.append(is_paused)


func _on_speed_changed(speed_index: int) -> void:
	_speeds.append(speed_index)


func test_one_second_at_1x_runs_one_tick() -> void:
	_start_running(1)
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(1)
	assert_int(_simulation.state.clock.tick).is_equal(1)


func test_one_second_at_10x_runs_ten_ticks() -> void:
	_start_running(3)
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(10)
	assert_int(_simulation.state.clock.tick).is_equal(10)


func test_half_speed_needs_two_seconds_per_tick() -> void:
	_start_running(0)
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(0)
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(1)


func test_remainder_carries_over_between_calls() -> void:
	_start_running(1)
	assert_int(_clock.advance_by_seconds(0.4)).is_equal(0)
	assert_int(_clock.advance_by_seconds(0.7)).is_equal(1)
	assert_float(_clock._accumulator).is_equal_approx(0.1, 1e-9)
	# With 0.1 s carried, 0.9 s more completes the next tick.
	assert_int(_clock.advance_by_seconds(0.9)).is_equal(1)


func test_long_run_has_no_float_drift() -> void:
	_start_running(1)
	var total: int = 0
	for _i: int in range(10000):
		total += _clock.advance_by_seconds(1.0 / 60.0)
	assert_int(total).is_equal(166)
	assert_int(_simulation.state.clock.tick).is_equal(166)
	# 40 more frames bring the total to exactly 10,040 / 60 = 167 + 20/60 s.
	for _i: int in range(40):
		total += _clock.advance_by_seconds(1.0 / 60.0)
	assert_int(total).is_equal(167)


func test_each_tick_emits_tick_advanced() -> void:
	_start_running(2)
	_clock.advance_by_seconds(1.0)
	assert_array(_ticks).is_equal([1, 2, 3])


func test_ticks_per_call_are_capped_and_excess_dropped() -> void:
	_start_running(3)
	assert_int(_clock.advance_by_seconds(7.0)).is_equal(SimClockScript.MAX_TICKS_PER_FRAME)
	assert_int(_simulation.state.clock.tick).is_equal(SimClockScript.MAX_TICKS_PER_FRAME)
	# The 10 excess ticks were dropped, not carried: 0.05 s at 10x is half a tick.
	assert_int(_clock.advance_by_seconds(0.05)).is_equal(0)
	assert_int(_clock.advance_by_seconds(0.05)).is_equal(1)
	# The warning is logged once; a second capped frame still runs and stays capped.
	assert_bool(_clock._cap_warned).is_true()
	assert_int(_clock.advance_by_seconds(7.0)).is_equal(SimClockScript.MAX_TICKS_PER_FRAME)


func test_paused_clock_runs_no_ticks() -> void:
	_start_running(1)
	_clock.pause()
	assert_int(_clock.advance_by_seconds(5.0)).is_equal(0)
	assert_int(_simulation.state.clock.tick).is_equal(0)
	assert_bool(_clock.is_running()).is_false()
	_clock.resume()
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(1)


func test_pause_state_lives_in_clock_state_and_emits() -> void:
	_clock.start(_simulation)
	assert_bool(_simulation.state.clock.is_paused).is_true()
	_clock.resume()
	assert_bool(_simulation.state.clock.is_paused).is_false()
	assert_bool(_clock.is_running()).is_true()
	_clock.resume()
	_clock.toggle_pause()
	_clock.toggle_pause()
	assert_array(_pauses).is_equal([false, true, false])


func test_start_keeps_saved_speed_and_pause() -> void:
	_simulation.state.clock.speed_index = 2
	_simulation.state.clock.is_paused = false
	_clock.start(_simulation)
	assert_int(_simulation.state.clock.speed_index).is_equal(2)
	assert_bool(_clock.is_running()).is_true()
	assert_array(_pauses).is_empty()
	assert_array(_speeds).is_empty()


func test_speed_changes_live_in_clock_state_and_emit() -> void:
	_start_running(1)
	_clock.faster()
	_clock.faster()
	_clock.faster()
	assert_int(_simulation.state.clock.speed_index).is_equal(3)
	_clock.set_speed_index(0)
	_clock.slower()
	assert_int(_simulation.state.clock.speed_index).is_equal(0)
	assert_array(_speeds).is_equal([2, 3, 0])


func test_speed_index_out_of_range_is_rejected() -> void:
	_start_running(1)
	_clock.set_speed_index(-1)
	_clock.set_speed_index(SimClockScript.SPEEDS.size())
	_clock.set_speed_index(99)
	assert_int(_simulation.state.clock.speed_index).is_equal(1)
	assert_array(_speeds).is_empty()


func test_pause_requested_pauses_the_clock() -> void:
	_start_running(1)
	_simulation.pause_requested.emit(&"incoming_wormhole")
	assert_bool(_simulation.state.clock.is_paused).is_true()
	assert_array(_pauses).is_equal([true])
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(0)


func test_slow_mode_runs_one_tick_per_six_seconds() -> void:
	_start_running(3)
	_clock.set_slow_mode(true)
	assert_int(_clock.advance_by_seconds(5.9)).is_equal(0)
	assert_int(_clock.advance_by_seconds(0.1)).is_equal(1)
	assert_int(_clock.advance_by_seconds(6.0)).is_equal(1)


func test_slow_mode_off_restores_previous_speed() -> void:
	_start_running(3)
	_clock.set_slow_mode(true)
	_clock.advance_by_seconds(6.0)
	_clock.set_slow_mode(false)
	assert_int(_simulation.state.clock.speed_index).is_equal(3)
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(10)


func test_null_simulation_is_a_no_op() -> void:
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(0)
	_clock.step_ticks(5)
	_clock.pause()
	_clock.resume()
	_clock.toggle_pause()
	_clock.set_speed_index(2)
	_clock.faster()
	_clock.slower()
	_clock.set_slow_mode(true)
	assert_bool(_clock.is_running()).is_false()
	assert_object(_clock.simulation).is_null()
	assert_array(_ticks).is_empty()
	assert_array(_pauses).is_empty()
	assert_array(_speeds).is_empty()


func test_step_ticks_advances_immediately_until_stopped() -> void:
	_clock.start(_simulation)
	_clock.step_ticks(5)
	assert_int(_simulation.state.clock.tick).is_equal(5)
	assert_array(_ticks).is_equal([1, 2, 3, 4, 5])
	_clock.resume()
	_clock.stop()
	assert_object(_clock.simulation).is_null()
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(0)
	_clock.step_ticks(5)
	assert_int(_simulation.state.clock.tick).is_equal(5)


func test_process_only_delegates_to_advance_by_seconds() -> void:
	_start_running(1)
	_clock._process(1.0)
	assert_int(_simulation.state.clock.tick).is_equal(1)
	var source: String = (SimClockScript as Script).source_code
	var body: String = source.split("func _process(delta: float) -> void:")[1].split("\n\n")[0]
	assert_str(body.strip_edges()).is_equal("advance_by_seconds(delta)")
