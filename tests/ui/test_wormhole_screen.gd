## Tests for the open wormhole in the Gate Room, with no modal: the status strip (destination,
## time left counting with sim time, drain, bank), the portal that shows and hides the actions
## by mouse, keyboard and gamepad, Close (hold) by each of them, the close reasons on the strip,
## and that no second dial can start while a wormhole is open, from the UI or as a command.
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
	assert_bool(_screen().are_actions_shown()).is_false()
	assert_array(Fixture.visible_texts(_screen())).contains(["Click the Ring for its actions."])
	Fixture.open_actions(_view)
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
				"What you can do now",
				"Extend the pole camera",
				"Close the wormhole (hold)",
				"Read the far Ring's console",
				tr(&"GATE_CONSOLE_HINT"),
				"Open the Address Book",
				"Send a probe",
				"Probes are not ready yet.",
			]
		)
	)
	assert_array(texts).not_contains([tr(&"GATE_MEANING_HOSTILE_LOCK")])
	assert_bool(_screen().get_actions().get_close_button().disabled).is_false()
	assert_bool(_screen().get_console().get_read_button().disabled).is_false()
	var later: Button = _screen().find_child("ProbeButton", true, false) as Button
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
	PowerFixture.set_charge(_simulation.state, 0)
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
	PowerFixture.set_charge(_simulation.state, 26)
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
	assert_bool(_screen().is_showing_closed()).is_true()
	assert_bool(_view.get_overlays().is_open()).is_false()
	assert_int(_view.get_ring_view().get_horizon_state()).is_equal(RingView.Horizon.CLOSING)
	assert_str(_screen().get_closed_text()).is_equal(
		"Wormhole closed: the maximum open time ran out."
	)
	assert_str(_screen().get_destination_text()).is_empty()


@warning_ignore("unused_parameter")
func test_the_portal_and_close_work_by_mouse_keyboard_and_gamepad(
	device: String, test_parameters: Array = [["mouse"], ["keyboard"], ["gamepad"]]  # gdlint: ignore=unused-argument,max-line-length
) -> void:
	_dial(DialOutcome.Kind.LOCK)
	await get_tree().process_frame
	await get_tree().process_frame
	var ring: RingView = _view.get_ring_view()
	assert_object(_focus_owner()).is_same(ring)
	_activate(device, ring)
	await get_tree().process_frame
	assert_bool(_screen().are_actions_shown()).is_true()
	var first: Control = _screen().get_actions().get_camera_button()
	assert_object(_focus_owner()).is_same(first)
	# Cancel hides the actions and gives focus back to the Ring; the Ring shows them again.
	_press(_cancel_event.bind(device))
	await get_tree().process_frame
	assert_bool(_screen().are_actions_shown()).is_false()
	assert_object(_focus_owner()).is_same(ring)
	_activate(device, ring)
	await get_tree().process_frame
	var close: HoldButton = _screen().get_actions().get_close_button()
	close.grab_focus()
	match device:
		"mouse":
			close.button_down.emit()
		"keyboard":
			Input.parse_input_event(_key_event(true, KEY_ENTER))
			Input.flush_buffered_events()
		"gamepad":
			Input.parse_input_event(_joypad_event(true, JOY_BUTTON_A))
			Input.flush_buffered_events()
	assert_bool(close.is_holding()).is_true()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	close.advance(HoldButton.HOLD_SECONDS)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(_screen().get_closed_text()).is_equal("Wormhole closed on your order.")
	ring.advance(RingView.CLOSE_SECONDS)
	assert_int(ring.get_horizon_state()).is_equal(RingView.Horizon.DARK)
	await get_tree().process_frame
	assert_object(_focus_owner()).is_same(_view.get_console().get_default_focus())
	_screen().get_back_button().pressed.emit()
	assert_bool(_screen().visible).is_false()


func _activate(device: String, ring: RingView) -> void:
	match device:
		"mouse":
			for is_pressed: bool in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = is_pressed
				click.position = ring.get_global_rect().get_center()
				click.global_position = click.position
				_holder.get_viewport().push_input(click, true)
		"keyboard":
			_press(_key_event.bind(KEY_ENTER))
		"gamepad":
			_press(_joypad_event.bind(JOY_BUTTON_A))


func _cancel_event(is_pressed: bool, device: String) -> InputEvent:
	if device == "gamepad":
		return _joypad_event(is_pressed, JOY_BUTTON_B)
	return _key_event(is_pressed, KEY_ESCAPE)


func _focus_owner() -> Control:
	return _holder.get_viewport().gui_get_focus_owner()


## Review nit (#121): B / Escape dismisses the "wormhole closed" message.
@warning_ignore("unused_parameter")
func test_cancel_dismisses_the_closed_message(
	device: String, test_parameters: Array = [["keyboard"], ["gamepad"]]  # gdlint: ignore=unused-argument,max-line-length
) -> void:
	_dial(DialOutcome.Kind.LOCK)
	Fixture.close_wormhole(_view)
	await get_tree().process_frame
	assert_bool(_screen().is_showing_closed()).is_true()
	_press(_cancel_event.bind(device))
	await get_tree().process_frame
	assert_bool(_screen().is_showing_closed()).is_false()
	assert_bool(_screen().visible).is_false()


func test_a_power_collapse_says_so() -> void:
	_dial(DialOutcome.Kind.LOCK)
	PowerFixture.set_charge(_simulation.state, 0)
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
	Fixture.open_actions(_view)
	await get_tree().process_frame
	# Ruling (PR #119, card #109): no modal; the strip and actions sit beside the Ring, never
	# over it, and the console stays in view, its Dial button disabled.
	var column: Control = _screen().get_node("Column") as Control
	assert_int(column.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(_screen().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_object(_screen().find_child("Dim", true, false)).is_null()
	var ring_rect: Rect2 = _view.get_ring_view().get_global_rect()
	assert_bool(column.get_global_rect().intersects(ring_rect)).is_false()
	assert_bool(_view.get_console().is_visible_in_tree()).is_true()


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
