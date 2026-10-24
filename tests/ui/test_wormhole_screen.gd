## Tests for the wormhole screen in the Gate Room: what it shows for a lock (destination, time
## left counting with sim time, drain, bank, the actions now and later), Close by mouse,
## keyboard and gamepad, the close reasons and the way back to the console, and that no second
## dial can start while a wormhole is open, from the UI or as a command.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## gate-and-address-spec.md#dialing-outcomes-and-energy
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")

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


func _screen() -> WormholeScreen:
	return _view.get_overlays().get_wormhole_screen()


## Dials the address for [param kind] with the Dial button and skips the sequence.
func _dial(kind: int) -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, kind))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	_view.get_overlays().get_sequence().skip()


func _press(event_for_state: Callable) -> void:
	for is_pressed: bool in [true, false]:
		var event: InputEvent = event_for_state.call(is_pressed)
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func test_a_lock_shows_the_destination_time_drain_bank_and_actions() -> void:
	_dial(DialOutcome.Kind.LOCK)
	assert_bool(_screen().is_showing_open()).is_true()
	assert_str(_screen().get_destination_text()).is_equal("Destination: P3X-111")
	assert_str(_screen().get_time_left_text()).is_equal("Time left: 1 h 0 min of 1 h 0 min")
	assert_str(_screen().get_drain_text()).is_equal("Power drain: 20.0 MW")
	assert_str(_screen().get_bank_text()).starts_with("Capacitors: ")
	var texts: Array[String] = Fixture.visible_texts(_screen())
	(
		assert_array(texts)
		. contains(
			[
				"Wormhole open",
				tr(&"GATE_WORMHOLE_SUMMARY"),
				"What you can do now",
				"Close wormhole",
				"Read the far Ring's console",
				"Not available yet: arrives with the next card.",
				"Send the MOTH probe",
				"Not available yet: arrives in M3.",
			]
		)
	)
	assert_array(texts).not_contains([tr(&"GATE_MEANING_HOSTILE_LOCK")])
	assert_bool(_screen().get_close_button().disabled).is_false()
	for button_name: String in ["ConsoleButton", "MothButton"]:
		var later: Button = _screen().find_child(button_name, true, false) as Button
		assert_bool(later.disabled).is_true()
		assert_int(later.focus_mode).is_equal(Control.FOCUS_NONE)


func test_a_hostile_lock_warns_that_the_far_side_is_guarded() -> void:
	_dial(DialOutcome.Kind.HOSTILE_LOCK)
	assert_str(_screen().get_destination_text()).is_equal("Destination: P3X-444")
	assert_array(Fixture.visible_texts(_screen())).contains([tr(&"GATE_MEANING_HOSTILE_LOCK")])


## The bank line says whether the plant covers the drain or when the bank runs dry, and the
## screen never shows the lock energy of the address.
func test_the_bank_line_and_no_lock_energy() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	var lock_text: String = GateRoomFormat.energy(
		GateQueries.lock_energy_mwh(_simulation.state, address)
	)
	_simulation.state.power.plant_output_mw = 0.0
	_dial(DialOutcome.Kind.LOCK)
	var stored: float = _simulation.state.power.stored_mwh
	var minutes: int = WormholeText.ticks_until_empty(stored, 20.0)
	(
		assert_str(_screen().get_bank_text())
		. is_equal(
			(
				"Capacitors: %s of %s, falling. They run dry in %s, and then the wormhole collapses."
				% [
					GateRoomFormat.energy(stored),
					GateRoomFormat.energy(DialFixture.CAPACITY_MWH),
					GateRoomFormat.duration(minutes),
				]
			)
		)
	)
	_simulation.state.power.plant_output_mw = 30.0
	SimClock.step_ticks(1)
	assert_str(_screen().get_bank_text()).ends_with("The plant covers the drain.")
	for text: String in Fixture.visible_texts(_screen()):
		assert_str(text).not_contains(lock_text)


func test_ticks_until_empty() -> void:
	assert_int(WormholeText.ticks_until_empty(20.0, 20.0)).is_equal(60)
	assert_int(WormholeText.ticks_until_empty(0.5, 20.0)).is_equal(2)
	assert_int(WormholeText.ticks_until_empty(0.0, 20.0)).is_equal(0)
	assert_int(WormholeText.ticks_until_empty(10.0, 0.0)).is_equal(-1)


func test_the_timer_counts_with_sim_time_and_closes_at_sixty_minutes() -> void:
	_dial(DialOutcome.Kind.LOCK)
	SimClock.step_ticks(10)
	assert_str(_screen().get_time_left_text()).is_equal("Time left: 50 min of 1 h 0 min")
	SimClock.step_ticks(49)
	assert_str(_screen().get_time_left_text()).is_equal("Time left: 1 min of 1 h 0 min")
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	SimClock.step_ticks(1)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_bool(_screen().is_open()).is_true()
	assert_str(_screen().get_closed_text()).is_equal(
		"Wormhole closed: the maximum open time ran out."
	)
	assert_str(_screen().get_destination_text()).is_empty()


@warning_ignore("unused_parameter")
func test_close_works_by_mouse_keyboard_and_gamepad(
	device: String, test_parameters: Array = [["mouse"], ["keyboard"], ["gamepad"]]  # gdlint: ignore=unused-argument,max-line-length
) -> void:
	_dial(DialOutcome.Kind.LOCK)
	await get_tree().process_frame
	var close: Button = _screen().get_close_button()
	assert_object(_holder.get_viewport().gui_get_focus_owner()).is_same(close)
	match device:
		"mouse":
			close.pressed.emit()
		"keyboard":
			_press(_key_event.bind(KEY_ENTER))
		"gamepad":
			_press(_joypad_event.bind(JOY_BUTTON_A))
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(_screen().get_closed_text()).is_equal("Wormhole closed on your order.")
	await get_tree().process_frame
	var back: Button = _screen().get_back_button()
	assert_object(_holder.get_viewport().gui_get_focus_owner()).is_same(back)
	_press(_joypad_event.bind(JOY_BUTTON_B))
	assert_bool(_view.get_overlays().is_open()).is_false()


func test_a_power_collapse_says_so() -> void:
	_dial(DialOutcome.Kind.LOCK)
	_simulation.state.power.plant_output_mw = 0.0
	_simulation.state.power.stored_mwh = 0.0
	SimClock.step_ticks(1)
	assert_str(_screen().get_closed_text()).is_equal("Wormhole collapsed: the capacitors ran dry.")


## The Ring holds one wormhole: while it is open the Dial button is disabled with a reason, the
## screen covers the console, and a DialCommand posted directly is refused.
func test_no_second_dial_while_a_wormhole_is_open() -> void:
	_dial(DialOutcome.Kind.LOCK)
	var world: StringName = _simulation.state.gate.connected_world_id
	Fixture.select(_view, Fixture.address_for(_simulation.state, DialOutcome.Kind.HOSTILE_LOCK))
	var controls: DialControls = _view.get_console().get_dial_controls()
	assert_bool(controls.get_dial_button().disabled).is_true()
	assert_str(controls.get_reason_text()).is_equal(
		"A wormhole is open: close it before dialing again."
	)
	controls.get_dial_button().begin_hold()
	controls.get_dial_button().advance(HoldButton.HOLD_SECONDS)
	var other: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.HOSTILE_LOCK)
	var result: CommandResult = _simulation.submit(DialCommand.create(other))
	assert_bool(result.is_ok).is_false()
	assert_str(String(result.error_code)).is_equal("ring_busy")
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_str(String(_simulation.state.gate.connected_world_id)).is_equal(String(world))
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(1)
	await get_tree().process_frame
	var dim: Control = _screen().get_node("Dim") as Control
	assert_int(dim.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(dim.get_global_rect().encloses(_view.get_console().get_global_rect())).is_true()


func test_a_game_loaded_with_a_wormhole_open_shows_the_screen() -> void:
	var loaded: Simulation = Fixture.simulation()
	loaded.submit(DialCommand.create(Fixture.address_for(loaded.state, DialOutcome.Kind.LOCK)))
	SimClock.start(loaded)
	SimClock.step_ticks(2)
	_view.setup(loaded)
	assert_bool(_screen().is_showing_open()).is_true()
	assert_str(_screen().get_destination_text()).is_equal("Destination: P3X-111")


func test_texts_follow_the_locale() -> void:
	_dial(DialOutcome.Kind.LOCK)
	TranslationServer.set_locale("pt_BR")
	assert_str(_screen().get_drain_text()).is_equal("Consumo de energia: 20.0 MW")


func _key_event(is_pressed: bool, keycode: Key) -> InputEvent:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = is_pressed
	return event


func _joypad_event(is_pressed: bool, button_index: JoyButton) -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = is_pressed
	return event
