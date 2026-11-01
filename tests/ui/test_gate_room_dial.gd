## Tests for the dial console's dial controls: the hold-to-confirm button (held with the mouse
## path and with the gamepad accept button), the reasons it is disabled, and the repeat
## warning and its second confirmation. The seal animation is tested in test_dial_sequence.
## Bible: gate-and-address-spec.md#the-dial-console,
## gate-and-address-spec.md#dialing-outcomes-and-energy,
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


func test_disabled_until_seven_glyphs_are_placed() -> void:
	assert_bool(_button().disabled).is_true()
	assert_str(_controls().get_reason_text()).is_equal(
		"Place a glyph in each of the seven seals first."
	)
	assert_str(_button().tooltip_text).is_equal(_controls().get_reason_text())
	_enter(DialOutcome.Kind.NO_GATE)
	assert_bool(_button().disabled).is_false()
	assert_str(_controls().get_reason_text()).is_empty()
	TranslationServer.set_locale("pt_BR")
	_view.get_console().clear_seal(1)
	assert_str(_controls().get_reason_text()).is_equal(
		"Coloque antes um glifo em cada um dos sete selos."
	)


func test_disabled_while_the_ring_is_dialing() -> void:
	_enter(DialOutcome.Kind.NO_GATE)
	_hold_fully()
	assert_bool(_button().disabled).is_true()
	assert_str(_controls().get_reason_text()).is_equal("The Ring is dialing.")
	SimClock.step_ticks(2)
	assert_bool(_button().disabled).is_false()


func test_disabled_while_a_wormhole_is_open_even_with_an_empty_console() -> void:
	_enter(DialOutcome.Kind.LOCK)
	_hold_fully()
	SimClock.step_ticks(2)
	assert_bool(_button().disabled).is_true()
	assert_str(_controls().get_reason_text()).starts_with("A wormhole is open")
	_view.get_console().clear_all()
	assert_str(_controls().get_reason_text()).starts_with("A wormhole is open")
	Fixture.close_wormhole(_view)
	assert_str(_controls().get_reason_text()).is_equal(
		"Place a glyph in each of the seven seals first."
	)


func test_a_dial_submits_exactly_one_command_with_the_console_address() -> void:
	var address: GateAddress = _enter(DialOutcome.Kind.BLOCKED)
	var dials: Array[String] = []
	var record: Callable = func(key: String) -> void: dials.append(key)
	EventBus.dial_started.connect(record)
	_hold_fully()
	_hold_fully()
	EventBus.dial_started.disconnect(record)
	assert_array(dials).is_equal([address.key()])
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_str(_simulation.state.gate.current_address.key()).is_equal(address.key())
	assert_int(_simulation.state.gate.current_address.origin).is_equal(
		_simulation.state.galaxy.home().origin_glyph
	)


func test_disabled_with_no_capacitors_or_an_empty_bank() -> void:
	_enter(DialOutcome.Kind.NO_GATE)
	_simulation.state.power.stored_mwh = 0.0
	_controls().set_address(_view.get_console().get_address())
	assert_bool(_button().disabled).is_true()
	assert_str(_controls().get_reason_text()).is_equal("Capacitors empty.")
	PowerFixture.remove_banks(_simulation.state)
	_controls().set_address(_view.get_console().get_address())
	assert_str(_controls().get_reason_text()).is_equal("No capacitors installed.")
	TranslationServer.set_locale("pt_BR")
	assert_str(_controls().get_reason_text()).is_equal("Nenhum capacitor instalado.")


## A bank holding some charge, but less than the address needs, still lets the player hold
## Dial; DialCommand refuses it and the panel says so without numbers.
func test_a_dial_short_of_charge_is_refused_with_a_line_and_no_numbers() -> void:
	var address: GateAddress = _enter(DialOutcome.Kind.NO_GATE)
	var needed: float = GateQueries.lock_energy_mwh(_simulation.state, address)
	_simulation.state.power.stored_mwh = needed / 2.0
	_controls().set_address(address)
	assert_bool(_button().disabled).is_false()
	assert_str(_controls().get_reason_text()).is_empty()
	_hold_fully()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(_controls().get_reason_text()).is_equal(
		"Not enough charge. The Ring would not turn."
	)
	assert_str(_controls().get_reason_text()).not_contains("MWh")
	_view.get_console().clear_seal(1)
	assert_str(_controls().get_reason_text()).is_equal(
		"Place a glyph in each of the seven seals first."
	)


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
	Fixture.close_wormhole(_view)
	assert_str(_controls().get_warning_text()).is_empty()
	_hold_fully()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
