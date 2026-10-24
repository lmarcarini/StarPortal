## Tests for the dialing sequence in the Gate Room: it holds time, lights the eight seals in
## order with one steady light each, steps the clock only until the dial resolves, releases
## the hold back to the player's own Running or Paused, and skipping (button, Escape, gamepad
## B) at any point gives the same result as watching. Also: two dials can never both start.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#state-machines, game-design.md#time-real-time-with-pause
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _sequence() -> DialSequence:
	return _view.get_overlays().get_sequence()


## Loads the address for [param kind] and holds Dial to the end.
func _hold_dial(kind: int) -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, kind))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)


func _send_joypad(button_index: JoyButton) -> void:
	for is_pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = is_pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _send_key(keycode: Key) -> void:
	for is_pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = is_pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func test_a_dial_holds_time_lights_eight_seals_in_order_and_restores_the_pause() -> void:
	var modes: Array[int] = []
	var record: Callable = func(mode: int) -> void: modes.append(mode)
	EventBus.time_mode_changed.connect(record)
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.PAUSED)
	_hold_dial(DialOutcome.Kind.NO_GATE)
	assert_bool(_sequence().is_open()).is_true()
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.HELD)
	assert_array(_simulation.state.clock.holds).is_equal([DialSequence.HOLD_REASON])
	var lit: Array[int] = []
	for step: int in GateAddress.SEAL_COUNT:
		assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
		assert_int(_simulation.state.clock.tick).is_equal(0)
		_sequence().advance(DialSequence.SEAL_SECONDS)
		lit.append(_sequence().get_lit_seals() if _sequence().is_open() else 8)
	EventBus.time_mode_changed.disconnect(record)
	assert_array(lit).is_equal([1, 2, 3, 4, 5, 6, 7, 8])
	assert_bool(_sequence().is_open()).is_false()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(1)
	assert_array(modes).is_equal([ClockState.Mode.HELD, ClockState.Mode.PAUSED])
	assert_array(_simulation.state.clock.holds).is_empty()
	assert_bool(_view.get_overlays().get_result_card().is_open()).is_true()


func test_a_running_clock_runs_again_after_the_sequence() -> void:
	SimClock.resume()
	_hold_dial(DialOutcome.Kind.BLOCKED)
	assert_bool(_sequence().is_open()).is_false()
	SimClock.step_ticks(1)
	assert_bool(_sequence().is_open()).is_true()
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.HELD)
	assert_int(SimClock.advance_by_seconds(10.0)).is_equal(0)
	_sequence().skip()
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.RUNNING)
	assert_int(_simulation.state.gate.dial_log[0].outcome).is_equal(DialOutcome.Kind.BLOCKED)


## The player pauses while the sequence holds time: the hold never undoes that pause.
func test_a_pause_asked_during_the_sequence_is_kept_after_it() -> void:
	SimClock.resume()
	_hold_dial(DialOutcome.Kind.NO_GATE)
	SimClock.step_ticks(1)
	SimClock.pause()
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.HELD)
	_sequence().advance(DialSequence.SEAL_SECONDS * GateAddress.SEAL_COUNT)
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.PAUSED)


## Skipping after any number of lit seals, or watching to the end, gives the same dial: the
## same outcome, energy, log tick and clock tick, and the clock never runs past the resolution.
@warning_ignore("unused_parameter")
func test_skip_at_any_point_gives_the_same_result_as_watching(
	kind: int,
	seconds_before_skip: float,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		[DialOutcome.Kind.NO_GATE, 0.0],
		[DialOutcome.Kind.NO_GATE, 1.6],
		[DialOutcome.Kind.NO_GATE, 3.9],
		[DialOutcome.Kind.NO_GATE, -1.0],
		[DialOutcome.Kind.LOCK, 0.0],
		[DialOutcome.Kind.LOCK, 2.2],
		[DialOutcome.Kind.LOCK, -1.0],
	]
) -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, kind)
	var lock_energy: float = GateQueries.lock_energy_mwh(_simulation.state, address)
	_hold_dial(kind)
	if seconds_before_skip < 0.0:
		for _frame: int in 100:
			_sequence().advance(0.05)
	else:
		_sequence().advance(seconds_before_skip)
		_sequence().skip()
	assert_bool(_sequence().is_open()).is_false()
	var duration: int = _simulation.state.balance.dial_duration_ticks
	assert_int(_simulation.state.clock.tick).is_equal(duration)
	var entry: DialLogEntry = _simulation.state.gate.dial_log[0]
	assert_int(entry.outcome).is_equal(kind)
	assert_int(entry.tick).is_equal(duration)
	var expected: float = EnergyMath.dial_cost_mwh(lock_energy, kind, _simulation.state.balance)
	assert_float(entry.energy_spent_mwh).is_equal_approx(expected, 0.0001)
	if kind == DialOutcome.Kind.LOCK:
		assert_int(_simulation.state.gate.lock_started_tick).is_equal(duration)
		assert_int(GateQueries.open_ticks_left(_simulation.state)).is_equal(
			_simulation.state.balance.max_open_ticks
		)
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.PAUSED)


func test_the_skip_button_has_focus_and_skips() -> void:
	_hold_dial(DialOutcome.Kind.NO_GATE)
	await get_tree().process_frame
	var skip: Button = _sequence().get_skip_button()
	assert_object(_holder.get_viewport().gui_get_focus_owner()).is_same(skip)
	skip.pressed.emit()
	assert_bool(_sequence().is_open()).is_false()
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(1)


func test_escape_and_gamepad_b_skip() -> void:
	_hold_dial(DialOutcome.Kind.NO_GATE)
	_sequence().advance(1.0)
	_send_key(KEY_ESCAPE)
	assert_bool(_sequence().is_open()).is_false()
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(1)
	_view.get_overlays().get_result_card().dismiss()
	_hold_dial(DialOutcome.Kind.BLOCKED)
	assert_bool(_sequence().is_open()).is_true()
	_send_joypad(JOY_BUTTON_B)
	assert_bool(_sequence().is_open()).is_false()
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(2)


## Reduced flashing: lit seals only ever go up, one at a time, so each seal changes once and
## stays lit; nothing blinks.
func test_each_seal_lights_once_and_stays_lit() -> void:
	_hold_dial(DialOutcome.Kind.LOCK)
	var ring: SealRing = _sequence().find_child("SealRing", true, false) as SealRing
	var previous: int = 0
	while _sequence().is_open():
		_sequence().advance(0.07)
		var now: int = ring.lit
		assert_int(now - previous).is_between(0, 1)
		previous = now
	assert_int(previous).is_equal(GateAddress.SEAL_COUNT)
	assert_bool(ring.is_processing()).is_false()


func test_the_sequence_names_the_glyphs_but_never_the_world() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	_hold_dial(DialOutcome.Kind.LOCK)
	assert_str(_sequence().get_address_text()).is_equal(
		"Address: " + GateRoomFormat.address_text(address)
	)
	for text: String in Fixture.visible_texts(_sequence()):
		for designation: String in Fixture.DESIGNATIONS.values():
			assert_str(text).not_contains(designation)


## A game saved during the sequence loads with the Ring dialing and time held: the view
## replays the sequence, which resolves the dial and releases the hold.
func test_a_game_loaded_mid_dial_replays_the_sequence() -> void:
	var loaded: Simulation = Fixture.simulation()
	var address: GateAddress = Fixture.address_for(loaded.state, DialOutcome.Kind.BLOCKED)
	loaded.submit(DialCommand.create(address))
	TimeControl.add_hold(loaded.state.clock, DialSequence.HOLD_REASON)
	SimClock.start(loaded)
	_view.setup(loaded)
	assert_bool(_sequence().is_open()).is_true()
	_sequence().skip()
	assert_int(loaded.state.gate.dial_log[0].outcome).is_equal(DialOutcome.Kind.BLOCKED)
	assert_array(loaded.state.clock.holds).is_empty()
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.PAUSED)


## Ticks run by someone else (tools, tests) that resolve the dial end the sequence at once.
func test_a_dial_resolved_elsewhere_ends_the_sequence() -> void:
	_hold_dial(DialOutcome.Kind.NO_GATE)
	SimClock.step_ticks(2)
	assert_bool(_sequence().is_open()).is_false()
	assert_array(_simulation.state.clock.holds).is_empty()
	assert_int(_simulation.state.clock.tick).is_equal(2)


## While the clock runs, a dial applies on the next tick, so the Dial button can be held twice
## before it does: the queue re-validates the second at flush and refuses it. Only one dial.
func test_two_dials_queued_in_one_tick_start_only_one() -> void:
	SimClock.resume()
	var started: Array[String] = []
	var rejected: Array[StringName] = []
	var on_started: Callable = func(key: String) -> void: started.append(key)
	var on_rejected: Callable = func(_type: StringName, code: StringName) -> void:
		rejected.append(code)
	EventBus.dial_started.connect(on_started)
	EventBus.command_rejected.connect(on_rejected)
	_hold_dial(DialOutcome.Kind.NO_GATE)
	_hold_dial(DialOutcome.Kind.LOCK)
	SimClock.step_ticks(1)
	EventBus.dial_started.disconnect(on_started)
	EventBus.command_rejected.disconnect(on_rejected)
	assert_int(started.size()).is_equal(1)
	assert_array(rejected).is_equal([&"ring_busy"])
	_sequence().skip()
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(1)
