## Tests for TimeControl: one test per cell of the transition table, the assert on illegal
## internal transitions, player requests during holds, stacked holds and a seeded random
## walk that checks a hold never undoes the player's pause.
## Bible: technical-architecture.md#code-standards (State machines),
## game-design.md#time-real-time-with-pause
extends GdUnitTestSuite

const RUNNING := ClockState.Mode.RUNNING
const PAUSED := ClockState.Mode.PAUSED
const HELD := ClockState.Mode.HELD


## A fresh clock in [param mode]; HELD is reached from PAUSED with one &"cutscene" hold.
func _clock_in(mode: ClockState.Mode) -> ClockState:
	var clock := ClockState.new()
	if mode == RUNNING:
		TimeControl.request_resume(clock)
	elif mode == HELD:
		TimeControl.add_hold(clock, &"cutscene")
	assert_int(clock.mode).is_equal(mode)
	return clock


## A fresh clock in [param before], then held by &"cutscene".
func _held_from(before: ClockState.Mode) -> ClockState:
	var clock := _clock_in(before)
	assert_bool(TimeControl.add_hold(clock, &"cutscene")).is_true()
	return clock


## ALLOWED is exactly the design table: every off-diagonal cell, no diagonal cell.
func test_allowed_table_matches_design() -> void:
	assert_dict(TimeControl.ALLOWED).is_equal(
		{RUNNING: [PAUSED, HELD], PAUSED: [RUNNING, HELD], HELD: [RUNNING, PAUSED]}
	)
	for from: ClockState.Mode in [RUNNING, PAUSED, HELD]:
		for to: ClockState.Mode in [RUNNING, PAUSED, HELD]:
			var label := "%d -> %d" % [from, to]
			var allowed := TimeControl.can_transition(from, to)
			assert_bool(allowed).override_failure_message(label).is_equal(from != to)


## RUNNING -> RUNNING is refused: resuming a running clock changes nothing.
func test_cell_running_to_running_is_refused() -> void:
	assert_bool(TimeControl.can_transition(RUNNING, RUNNING)).is_false()
	var clock := _clock_in(RUNNING)
	assert_bool(TimeControl.request_resume(clock)).is_false()
	assert_int(clock.mode).is_equal(RUNNING)


## RUNNING -> PAUSED by a player or auto pause.
func test_cell_running_to_paused_by_pause() -> void:
	assert_bool(TimeControl.can_transition(RUNNING, PAUSED)).is_true()
	var clock := _clock_in(RUNNING)
	assert_bool(TimeControl.request_pause(clock)).is_true()
	assert_int(clock.mode).is_equal(PAUSED)


## RUNNING -> HELD when the first hold is added; the clock remembers it was running.
func test_cell_running_to_held_by_first_hold() -> void:
	assert_bool(TimeControl.can_transition(RUNNING, HELD)).is_true()
	var clock := _held_from(RUNNING)
	assert_int(clock.mode).is_equal(HELD)
	assert_int(clock.mode_after_hold).is_equal(RUNNING)
	assert_array(clock.holds).is_equal([&"cutscene"])


## PAUSED -> RUNNING by a player resume.
func test_cell_paused_to_running_by_resume() -> void:
	assert_bool(TimeControl.can_transition(PAUSED, RUNNING)).is_true()
	var clock := _clock_in(PAUSED)
	assert_bool(TimeControl.request_resume(clock)).is_true()
	assert_int(clock.mode).is_equal(RUNNING)


## PAUSED -> PAUSED is refused: pausing a paused clock changes nothing.
func test_cell_paused_to_paused_is_refused() -> void:
	assert_bool(TimeControl.can_transition(PAUSED, PAUSED)).is_false()
	var clock := _clock_in(PAUSED)
	assert_bool(TimeControl.request_pause(clock)).is_false()
	assert_int(clock.mode).is_equal(PAUSED)


## PAUSED -> HELD when the first hold is added; the clock remembers it was paused.
func test_cell_paused_to_held_by_first_hold() -> void:
	assert_bool(TimeControl.can_transition(PAUSED, HELD)).is_true()
	var clock := _held_from(PAUSED)
	assert_int(clock.mode).is_equal(HELD)
	assert_int(clock.mode_after_hold).is_equal(PAUSED)


## HELD -> RUNNING when the last hold is released and the player wanted running.
func test_cell_held_to_running_on_last_release() -> void:
	assert_bool(TimeControl.can_transition(HELD, RUNNING)).is_true()
	var clock := _held_from(RUNNING)
	assert_bool(TimeControl.release_hold(clock, &"cutscene")).is_true()
	assert_int(clock.mode).is_equal(RUNNING)
	assert_array(clock.holds).is_empty()


## HELD -> PAUSED when the last hold is released and the player wanted paused.
func test_cell_held_to_paused_on_last_release() -> void:
	assert_bool(TimeControl.can_transition(HELD, PAUSED)).is_true()
	var clock := _held_from(PAUSED)
	assert_bool(TimeControl.release_hold(clock, &"cutscene")).is_true()
	assert_int(clock.mode).is_equal(PAUSED)


## HELD -> HELD is refused: a second hold adds a reason but makes no transition and keeps
## the mode to return to.
func test_cell_held_to_held_is_refused() -> void:
	assert_bool(TimeControl.can_transition(HELD, HELD)).is_false()
	var clock := _held_from(RUNNING)
	assert_bool(TimeControl.add_hold(clock, &"decision")).is_true()
	assert_int(clock.mode).is_equal(HELD)
	assert_int(clock.mode_after_hold).is_equal(RUNNING)


## An illegal internal transition fails an assert.
func test_illegal_internal_transition_asserts() -> void:
	var clock := _clock_in(RUNNING)
	await (
		assert_error(func() -> void: TimeControl._transition(clock, RUNNING))
		. is_runtime_error("Assertion failed: TimeControl: illegal transition RUNNING -> RUNNING")
	)


## A corrupt clock that would return to HELD after a hold fails the same assert.
func test_release_into_held_asserts() -> void:
	var clock := _held_from(PAUSED)
	clock.mode_after_hold = HELD
	await (
		assert_error(func() -> void: TimeControl.release_hold(clock, &"cutscene"))
		. is_runtime_error("Assertion failed: TimeControl: illegal transition HELD -> HELD")
	)


## Start RUNNING, add a hold, request pause, release: the player's pause is kept.
func test_player_pause_during_hold_survives_release() -> void:
	var clock := _held_from(RUNNING)
	assert_bool(TimeControl.request_pause(clock)).is_true()
	assert_int(clock.mode).is_equal(HELD)
	assert_int(clock.mode_after_hold).is_equal(PAUSED)
	TimeControl.release_hold(clock, &"cutscene")
	assert_int(clock.mode).is_equal(PAUSED)


## Start PAUSED, add a hold, request resume, release: the clock runs.
func test_player_resume_during_hold_applies_on_release() -> void:
	var clock := _held_from(PAUSED)
	assert_bool(TimeControl.request_resume(clock)).is_true()
	assert_int(clock.mode).is_equal(HELD)
	TimeControl.release_hold(clock, &"cutscene")
	assert_int(clock.mode).is_equal(RUNNING)


## With no request during a hold, release returns to the mode before the hold.
func test_no_request_during_hold_returns_to_previous_mode() -> void:
	for before: ClockState.Mode in [RUNNING, PAUSED]:
		var clock := _held_from(before)
		TimeControl.release_hold(clock, &"cutscene")
		assert_int(clock.mode).is_equal(before)


## A request during a hold that matches the mode after the hold changes nothing.
func test_repeated_request_during_hold_returns_false() -> void:
	var clock := _held_from(PAUSED)
	assert_bool(TimeControl.request_pause(clock)).is_false()
	assert_bool(TimeControl.request_resume(clock)).is_true()
	assert_bool(TimeControl.request_resume(clock)).is_false()
	assert_int(clock.mode).is_equal(HELD)


## Toggle pauses a running clock, resumes a paused one, and while HELD flips the mode
## after the hold without leaving HELD.
func test_toggle_in_every_mode() -> void:
	var clock := _clock_in(RUNNING)
	assert_bool(TimeControl.request_toggle(clock)).is_true()
	assert_int(clock.mode).is_equal(PAUSED)
	assert_bool(TimeControl.request_toggle(clock)).is_true()
	assert_int(clock.mode).is_equal(RUNNING)
	TimeControl.add_hold(clock, &"cutscene")
	assert_bool(TimeControl.request_toggle(clock)).is_true()
	assert_int(clock.mode).is_equal(HELD)
	assert_int(clock.mode_after_hold).is_equal(PAUSED)
	assert_bool(TimeControl.request_toggle(clock)).is_true()
	assert_int(clock.mode_after_hold).is_equal(RUNNING)


## Two holds: releasing one keeps HELD; releasing the last restores mode_after_hold.
func test_two_holds_release_in_any_order() -> void:
	var clock := _held_from(RUNNING)
	TimeControl.add_hold(clock, &"decision")
	assert_bool(TimeControl.release_hold(clock, &"cutscene")).is_true()
	assert_int(clock.mode).is_equal(HELD)
	assert_array(clock.holds).is_equal([&"decision"])
	assert_bool(TimeControl.release_hold(clock, &"decision")).is_true()
	assert_int(clock.mode).is_equal(RUNNING)


## Adding a held reason again, releasing an unknown reason or adding an empty reason
## changes nothing and returns false.
func test_duplicate_add_and_unknown_release_are_no_ops() -> void:
	var clock := _held_from(RUNNING)
	var before := clock.to_dict()
	assert_bool(TimeControl.add_hold(clock, &"cutscene")).is_false()
	assert_bool(TimeControl.release_hold(clock, &"decision")).is_false()
	assert_bool(TimeControl.add_hold(clock, &"")).is_false()
	assert_dict(clock.to_dict()).is_equal(before)
	var unheld := _clock_in(PAUSED)
	assert_bool(TimeControl.release_hold(unheld, &"cutscene")).is_false()
	assert_int(unheld.mode).is_equal(PAUSED)


## Seeded random walk of requests and holds against a model of what the player wants:
## HELD exactly while holds exist; otherwise the mode is the player's choice, and while
## HELD mode_after_hold is. A hold never undoes the player's pause.
func test_random_walk_keeps_player_choice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var reasons: Array[StringName] = [&"a", &"b", &"c"]
	var clock := ClockState.new()
	var wanted: ClockState.Mode = PAUSED
	for step: int in 5000:
		var reason: StringName = reasons[rng.randi_range(0, reasons.size() - 1)]
		match rng.randi_range(0, 4):
			0:
				TimeControl.request_pause(clock)
				wanted = PAUSED
			1:
				TimeControl.request_resume(clock)
				wanted = RUNNING
			2:
				TimeControl.request_toggle(clock)
				wanted = RUNNING if wanted == PAUSED else PAUSED
			3:
				TimeControl.add_hold(clock, reason)
			_:
				TimeControl.release_hold(clock, reason)
		var label := "step %d: %s" % [step, str(clock.to_dict())]
		var held := not clock.holds.is_empty()
		assert_bool(clock.mode == HELD).override_failure_message(label).is_equal(held)
		var effective: ClockState.Mode = clock.mode_after_hold if held else clock.mode
		assert_int(effective).override_failure_message(label).is_equal(wanted)
