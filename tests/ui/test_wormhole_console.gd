## Tests for the far Ring's console on the wormhole screen: Read the far Ring's console by
## mouse, keyboard and gamepad adds the listed addresses (shown as glyph rows, never named), a
## read console stays read, and Open the Address Book sets the wormhole aside behind a return
## bar with Dial still disabled; the player comes back by the bar or Cancel, and the screen
## comes back by itself when the wormhole closes or is about to.
## Bible: gate-and-address-spec.md#where-addresses-come-from (Ring consoles),
## gate-and-address-spec.md#probing-the-unknown,
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole
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


func _console() -> ConsoleFinds:
	return _screen().get_console()


func _focus_owner() -> Control:
	return _holder.get_viewport().gui_get_focus_owner()


## Dials the open fixture world with the Dial button and skips the sequence.
func _dial_open() -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	_view.get_overlays().get_sequence().skip()


func _press(event_for_state: Callable) -> void:
	for is_pressed: bool in [true, false]:
		var event: InputEvent = event_for_state.call(is_pressed)
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _listed() -> Array[StringName]:
	return ConsoleLog.listed_worlds(DialFixture.OPEN_ID, _simulation.state.galaxy)


@warning_ignore("unused_parameter")
func test_read_works_by_mouse_keyboard_and_gamepad(
	device: String, test_parameters: Array = [["mouse"], ["keyboard"], ["gamepad"]]  # gdlint: ignore=unused-argument,max-line-length
) -> void:
	_dial_open()
	await get_tree().process_frame
	var read: Button = _console().get_read_button()
	match device:
		"mouse":
			read.pressed.emit()
		"keyboard":
			_press(_key_event.bind(KEY_DOWN))
			assert_object(_focus_owner()).is_same(read)
			_press(_key_event.bind(KEY_ENTER))
		"gamepad":
			_press(_joypad_event.bind(JOY_BUTTON_DPAD_DOWN))
			assert_object(_focus_owner()).is_same(read)
			_press(_joypad_event.bind(JOY_BUTTON_A))
	var listed: Array[StringName] = _listed()
	assert_int(_simulation.state.address_book.entries.size()).is_equal(listed.size() + 1)
	assert_bool(read.disabled).is_true()
	assert_int(_console().get_strips().size()).is_equal(listed.size())
	var first: GateAddress = DialFixture.address_of(_simulation.state.galaxy, listed[0])
	assert_array(_console().get_strips()[0].get_glyph_indices()).is_equal(first.seals())
	var note: String = "Console read: %d new addresses in the Address Book" % listed.size()
	assert_str(_console().get_note_text()).starts_with(note)
	await get_tree().process_frame
	assert_object(_focus_owner()).is_same(_console().get_book_button())


## No world the console lists is named anywhere in the Gate Room before it is locked.
func test_listed_worlds_stay_unnamed() -> void:
	_dial_open()
	_console().read()
	var texts: Array[String] = Fixture.visible_texts(_holder)
	for id: StringName in _listed():
		var designation: String = Fixture.DESIGNATIONS[id]
		for text: String in texts:
			assert_str(text).not_contains(designation)


## A read console stays read: dialed again, the button is disabled and the finds still show.
func test_a_read_console_stays_read() -> void:
	_dial_open()
	_console().read()
	_screen().get_close_button().pressed.emit()
	_screen().dismiss()
	_dial_open()
	assert_bool(_console().get_read_button().disabled).is_true()
	assert_int(_console().get_strips().size()).is_equal(_listed().size())
	assert_bool(_console().get_book_button().visible).is_true()


## Open the Address Book sets the wormhole aside: the book tab shows and has focus, the return
## bar shows the time left, Dial stays disabled; the bar's button and Cancel bring it back.
func test_address_book_round_trip() -> void:
	_dial_open()
	_console().read()
	_console().get_book_button().pressed.emit()
	await get_tree().process_frame
	assert_bool(_screen().is_away()).is_true()
	assert_bool(_view.get_overlays().is_open()).is_false()
	var book: AddressBookPanel = _view.get_address_book()
	assert_bool(book.is_visible_in_tree()).is_true()
	assert_object(_focus_owner()).is_same(book.get_first_focus())
	var back: Button = _screen().get_return_button()
	assert_bool(back.is_visible_in_tree()).is_true()
	assert_str(back.text).is_equal("Wormhole open (1 h 0 min left): back to it")
	assert_bool(_view.get_console().get_dial_controls().get_dial_button().disabled).is_true()
	back.pressed.emit()
	await get_tree().process_frame
	assert_bool(_screen().is_showing_open()).is_true()
	assert_object(_focus_owner()).is_same(_screen().get_close_button())
	_console().get_book_button().pressed.emit()
	await get_tree().process_frame
	_press(_joypad_event.bind(JOY_BUTTON_B))
	assert_bool(_screen().is_showing_open()).is_true()


## While aside, the screen comes back by itself when the wormhole is about to time out, and
## shows why when it closes.
func test_the_screen_comes_back_when_the_wormhole_ends() -> void:
	_dial_open()
	_console().read()
	_screen().step_away()
	var left: int = GateQueries.open_ticks_left(_simulation.state)
	SimClock.step_ticks(left - WormholeScreen.RETURN_WARNING_TICKS - 1)
	assert_bool(_screen().is_away()).is_true()
	SimClock.step_ticks(1)
	assert_bool(_screen().is_showing_open()).is_true()
	_screen().step_away()
	SimClock.step_ticks(WormholeScreen.RETURN_WARNING_TICKS)
	assert_bool(_screen().is_away()).is_false()
	assert_str(_screen().get_closed_text()).is_equal(
		"Wormhole closed: the maximum open time ran out."
	)


## While aside, a wormhole that closes for lack of charge brings the screen back with why.
func test_a_collapse_while_aside_shows_the_reason() -> void:
	_dial_open()
	_console().read()
	_screen().step_away()
	_simulation.state.power.plant_output_mw = 0.0
	_simulation.state.power.stored_mwh = 0.0
	SimClock.step_ticks(1)
	assert_str(_screen().get_closed_text()).is_equal("Wormhole collapsed: the capacitors ran dry.")


func test_texts_follow_the_locale() -> void:
	_dial_open()
	TranslationServer.set_locale("pt_BR")
	assert_str(_console().get_note_text()).starts_with("Copia o registro")


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
