## Tests for the Gate Room's dial controls and Ring display: the hold-to-confirm button (held
## with the mouse path and with the gamepad accept button), the reasons it is disabled, the
## repeat warning and its second confirmation, and the seal animation following sim time.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#difficulty-and-accessibility
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


func _enter(kind: int) -> GateAddress:
	var address: GateAddress = Fixture.address_for(_simulation.state, kind)
	Fixture.select(_view, address)
	return address


func _controls() -> DialControls:
	return _view.find_child("DialControls", true, false) as DialControls


func _button() -> HoldButton:
	return _controls().get_dial_button()


func _ring() -> RingDisplay:
	return _view.find_child("RingDisplay", true, false) as RingDisplay


func _hold_fully() -> void:
	_button().begin_hold()
	_button().advance(HoldButton.HOLD_SECONDS)


## Sends the gamepad accept button (A) as a press or a release.
func _gamepad_accept(is_pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = is_pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_disabled_without_a_selection() -> void:
	assert_bool(_button().disabled).is_true()
	assert_str(_controls().get_reason_text()).is_equal(
		"Place seven glyphs in the Address Workbench first."
	)
	_enter(DialOutcome.Kind.NO_GATE)
	assert_bool(_button().disabled).is_false()
	assert_str(_controls().get_reason_text()).is_empty()


func test_disabled_while_the_ring_is_busy() -> void:
	_enter(DialOutcome.Kind.NO_GATE)
	_hold_fully()
	assert_bool(_button().disabled).is_true()
	assert_str(_controls().get_reason_text()).starts_with("The Ring is busy")
	SimClock.step_ticks(2)
	assert_bool(_button().disabled).is_false()


func test_disabled_with_the_translated_reason_when_the_charge_is_short() -> void:
	var address: GateAddress = _enter(DialOutcome.Kind.NO_GATE)
	_simulation.state.power.stored_mwh = 0.0
	SimClock.step_ticks(1)
	var needed: String = GateRoomFormat.energy(
		GateQueries.lock_energy_mwh(_simulation.state, address)
	)
	assert_bool(_button().disabled).is_true()
	assert_str(_controls().get_reason_text()).starts_with("Not enough charge")
	assert_str(_controls().get_reason_text()).contains(needed)
	TranslationServer.set_locale("pt_BR")
	assert_str(_controls().get_reason_text()).starts_with("Carga insuficiente")


func test_release_before_the_hold_time_does_not_dial() -> void:
	_enter(DialOutcome.Kind.NO_GATE)
	_button().begin_hold()
	_button().advance(HoldButton.HOLD_SECONDS - 0.1)
	assert_float(_button().get_progress()).is_between(0.8, 0.9)
	_button().cancel_hold()
	_button().advance(1.0)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_float(_button().get_progress()).is_equal(0.0)
	_hold_fully()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)


func test_the_hold_time_is_a_named_constant_of_six_tenths_of_a_second() -> void:
	assert_float(HoldButton.HOLD_SECONDS).is_equal(0.6)


func test_gamepad_accept_held_dials_and_released_early_does_not() -> void:
	_enter(DialOutcome.Kind.NO_GATE)
	_button().grab_focus()
	assert_bool(_button().has_focus()).is_true()
	_gamepad_accept(true)
	assert_bool(_button().is_holding()).is_true()
	await get_tree().create_timer(0.2).timeout
	_gamepad_accept(false)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	_gamepad_accept(true)
	await get_tree().create_timer(HoldButton.HOLD_SECONDS + 0.3).timeout
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
	_gamepad_accept(false)


func test_repeat_warning_needs_a_second_confirmation() -> void:
	var address: GateAddress = _enter(DialOutcome.Kind.NO_GATE)
	assert_str(_controls().get_warning_text()).is_empty()
	_hold_fully()
	SimClock.step_ticks(2)
	assert_str(_controls().get_warning_text()).starts_with("Dialed on 2026-01-01 00:02: No gate.")
	_hold_fully()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_bool(_controls().is_repeat_armed()).is_true()
	assert_str(_button().text).is_equal("Hold again to dial anyway")
	_hold_fully()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_str(_simulation.state.gate.current_address.key()).is_equal(address.key())
	assert_bool(_controls().is_repeat_armed()).is_false()


func test_repeat_confirmation_is_dropped_when_the_selection_changes() -> void:
	var first: GateAddress = _enter(DialOutcome.Kind.NO_GATE)
	_hold_fully()
	SimClock.step_ticks(2)
	_hold_fully()
	assert_bool(_controls().is_repeat_armed()).is_true()
	_enter(DialOutcome.Kind.BLOCKED)
	assert_bool(_controls().is_repeat_armed()).is_false()
	assert_str(_controls().get_warning_text()).is_empty()
	Fixture.select(_view, first)
	assert_str(_controls().get_warning_text()).is_not_empty()
	assert_bool(_controls().is_repeat_armed()).is_false()


func test_a_lock_is_not_a_failed_attempt() -> void:
	_enter(DialOutcome.Kind.LOCK)
	_hold_fully()
	SimClock.step_ticks(2)
	(_view.find_child("CloseButton", true, false) as Button).pressed.emit()
	assert_str(_controls().get_warning_text()).is_empty()
	_hold_fully()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)


func test_lit_seals_spread_eight_seals_over_the_dial_duration() -> void:
	assert_int(RingDisplay.lit_seals(0.0, 2)).is_equal(0)
	assert_int(RingDisplay.lit_seals(0.5, 2)).is_equal(2)
	assert_int(RingDisplay.lit_seals(1.0, 2)).is_equal(4)
	assert_int(RingDisplay.lit_seals(1.5, 2)).is_equal(6)
	assert_int(RingDisplay.lit_seals(2.0, 2)).is_equal(8)
	assert_int(RingDisplay.lit_seals(9.0, 2)).is_equal(8)
	assert_int(RingDisplay.lit_seals(1.0, 0)).is_equal(8)


func test_seals_light_per_tick_and_hold_while_paused() -> void:
	_enter(DialOutcome.Kind.LOCK)
	assert_int(_ring().get_lit_seals()).is_equal(0)
	_hold_fully()
	assert_int(_ring().get_lit_seals()).is_equal(0)
	assert_str(_ring().get_status_text()).is_equal("Seals engaging: 0 of 8")
	_ring()._process(5.0)
	assert_int(_ring().get_lit_seals()).is_equal(0)
	SimClock.step_ticks(1)
	assert_int(_ring().get_lit_seals()).is_equal(4)
	_ring()._process(5.0)
	assert_int(_ring().get_lit_seals()).is_equal(4)
	SimClock.step_ticks(1)
	assert_int(_ring().get_lit_seals()).is_equal(8)
	assert_str(_ring().get_status_text()).is_equal("Wormhole open")


func test_seals_follow_real_time_times_speed_while_running_and_hold_when_held() -> void:
	_enter(DialOutcome.Kind.LOCK)
	_hold_fully()
	_simulation.state.clock.is_paused = false
	_ring()._process(0.5)
	assert_int(_ring().get_lit_seals()).is_equal(2)
	SimClock.hold(&"test")
	_ring()._process(5.0)
	assert_int(_ring().get_lit_seals()).is_equal(2)
	SimClock.release(&"test")
	_simulation.state.clock.is_paused = true
	_ring()._process(5.0)
	assert_int(_ring().get_lit_seals()).is_equal(2)
	_simulation.state.clock.is_paused = false
	_simulation.state.clock.speed_index = 3
	_ring()._process(0.05)
	assert_int(_ring().get_lit_seals()).is_equal(3)
	_ring()._process(5.0)
	assert_int(_ring().get_lit_seals()).is_less(5)
