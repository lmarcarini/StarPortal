## Tests for TimeControl's debug transition log: a plain print behind
## OS.is_debug_build(), never a warning, and no change to the transitions themselves.
## Kept apart from test_time_control.gd, which is at the public-method limit.
## Bible: technical-architecture.md#code-standards (State machines)
extends GdUnitTestSuite


## Transition logging is plain print output behind OS.is_debug_build(): the source never
## pushes a warning or error, and its single log call sits directly under that check.
func test_transition_log_is_debug_only_print() -> void:
	var source := FileAccess.get_file_as_string("res://src/core/time_control.gd")
	for word: String in ["push_warning", "push_error", "printerr"]:
		assert_bool(source.contains(word)).override_failure_message(word).is_false()
	var lines := source.split("\n")
	var calls: Array[int] = []
	for index: int in lines.size():
		if lines[index].strip_edges().begins_with("_log_transition("):
			calls.append(index)
	assert_int(calls.size()).is_equal(1)
	if calls.size() == 1:
		assert_str(lines[calls[0] - 1].strip_edges()).is_equal("if OS.is_debug_build():")


## Logged transitions still behave as before: a hold and its release round-trip the mode.
func test_logged_transitions_keep_behaviour() -> void:
	var clock := ClockState.new()
	assert_bool(TimeControl.request_resume(clock)).is_true()
	assert_bool(TimeControl.add_hold(clock, &"incoming_wormhole")).is_true()
	assert_int(clock.mode).is_equal(ClockState.Mode.HELD)
	assert_bool(TimeControl.release_hold(clock, &"incoming_wormhole")).is_true()
	assert_int(clock.mode).is_equal(ClockState.Mode.RUNNING)
	assert_bool(TimeControl.request_pause(clock)).is_true()
	assert_int(clock.mode).is_equal(ClockState.Mode.PAUSED)
