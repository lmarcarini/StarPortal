## Slow reasons on the clock (docs/content/event-time.md section 2): min(cruise, 1x) while
## any is active, counted per source, overrides that stick until the event ends, holds and
## pause untouched, and saves keep them.
extends GdUnitTestSuite


func test_effective_speed_follows_slows() -> void:
	var clock := ClockState.new()
	clock.speed_index = 3
	assert_int(TimeControl.effective_speed_index(clock)).is_equal(3)
	TimeControl.add_slow(clock, &"dialling")
	assert_int(TimeControl.effective_speed_index(clock)).is_equal(1)
	clock.speed_index = 0
	assert_int(TimeControl.effective_speed_index(clock)).is_equal(0)
	clock.speed_index = 3
	TimeControl.release_slow(clock, &"dialling")
	assert_int(TimeControl.effective_speed_index(clock)).is_equal(3)
	assert_int(clock.speed_index).is_equal(3)


func test_twice_is_a_no_op_and_sources_count_apart() -> void:
	var clock := ClockState.new()
	assert_bool(TimeControl.add_slow(clock, &"awaiting_answer", &"a")).is_true()
	assert_bool(TimeControl.add_slow(clock, &"awaiting_answer", &"a")).is_false()
	assert_bool(TimeControl.add_slow(clock, &"awaiting_answer", &"b")).is_true()
	TimeControl.release_slow(clock, &"awaiting_answer", &"a")
	assert_bool(TimeControl.is_slowed(clock)).is_true()
	assert_bool(TimeControl.release_slow(clock, &"awaiting_answer", &"a")).is_false()
	TimeControl.release_slow(clock, &"awaiting_answer", &"b")
	assert_bool(TimeControl.is_slowed(clock)).is_false()


func test_override_sticks_until_the_event_ends() -> void:
	var clock := ClockState.new()
	TimeControl.add_slow(clock, &"gate_ops")
	TimeControl.add_slow(clock, &"incursion")
	assert_bool(TimeControl.can_override(clock)).is_true()
	TimeControl.override(clock)
	assert_array(clock.slows).is_equal([&"incursion"])
	assert_bool(TimeControl.can_override(clock)).is_false()
	assert_bool(TimeControl.add_slow(clock, &"gate_ops")).is_false()
	TimeControl.release_slow(clock, &"gate_ops")
	assert_bool(TimeControl.add_slow(clock, &"gate_ops")).is_true()


func test_pause_and_holds_unchanged() -> void:
	var clock := ClockState.new()
	TimeControl.add_slow(clock, &"dialling")
	TimeControl.request_resume(clock)
	assert_bool(clock.is_paused).is_false()
	TimeControl.add_hold(clock, &"x")
	assert_int(clock.mode).is_equal(ClockState.Mode.HELD)
	TimeControl.release_hold(clock, &"x")
	assert_int(clock.mode).is_equal(ClockState.Mode.RUNNING)


func test_save_round_trip_and_old_saves() -> void:
	var clock := ClockState.new()
	TimeControl.add_slow(clock, &"awaiting_answer", &"kindred")
	TimeControl.add_slow(clock, &"dialling")
	TimeControl.override(clock)
	TimeControl.add_slow(clock, &"incursion")
	var data: Dictionary = JSON.parse_string(JSON.stringify(clock.to_dict()))
	assert_array(ClockState.validate_dict(data)).is_empty()
	var back: ClockState = ClockState.from_dict(data)
	assert_array(back.slows).is_equal(clock.slows)
	assert_array(back.overridden).is_equal(clock.overridden)
	data.erase("slows")
	data.erase("overridden")
	assert_array(ClockState.from_dict(data).slows).is_empty()
	var old: Dictionary = {"format_version": 16, "tick": 0, "state": {"clock": {}}}
	var migrated: Result = SaveMigrator.migrate(old)
	assert_bool(migrated.is_ok).is_true()
	var root: Dictionary = migrated.value
	var state: Dictionary = root["state"]
	var clock_dict: Dictionary = state["clock"]
	assert_array(clock_dict["slows"]).is_empty()


func test_override_command() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var state := GameState.new_game(2, defs.balance)
	var simulation: Simulation = GameSetup.build_new(state, defs).value
	assert_str(String(simulation.submit(OverrideSlowCommand.create()).error_code)).is_equal(
		"nothing_to_override"
	)
	TimeControl.add_slow(state.clock, &"dialling")
	assert_bool(simulation.submit(OverrideSlowCommand.create()).is_ok).is_true()
	simulation.advance_tick()
	assert_bool(TimeControl.is_slowed(state.clock)).is_false()
