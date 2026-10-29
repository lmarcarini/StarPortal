## Tests for the Address Book drawer on the Gate Room's right edge: it starts collapsed to a tab
## naming the entry count, opens and closes by mouse, keyboard and gamepad, opens from the
## wormhole's Open the Address Book action above the status strip, and with 50 entries fits the
## minimum window in English and Brazilian Portuguese (the list scrolls).
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")

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
	await UiInput.settle(_view)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _drawer() -> AddressBookDrawer:
	return _view.get_address_drawer()


## Adds [param count] dialed entries with distinct addresses.
func _fill(count: int) -> void:
	var origin: int = _simulation.state.galaxy.home().origin_glyph
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	while _simulation.state.address_book.entries.size() < count:
		var glyphs: Array[int] = []
		while glyphs.size() < GateAddress.COORDINATE_COUNT:
			var glyph: int = rng.randi_range(0, GateAddress.GLYPH_COUNT - 1)
			if glyph != origin and not glyphs.has(glyph):
				glyphs.append(glyph)
		var key: String = GateAddress.create(glyphs, origin).key()
		if _simulation.state.address_book.find(key) == null:
			var entry := AddressEntry.create(key, AddressEntry.Source.DIALED, &"")
			entry.note = "Survey note %d" % _simulation.state.address_book.entries.size()
			_simulation.state.address_book.entries.push_front(entry)
	EventBus.address_book_changed.emit()


func test_starts_collapsed_with_the_count_on_the_tab() -> void:
	_fill(3)
	assert_bool(_drawer().is_open()).is_false()
	assert_bool(_drawer().get_tab().visible).is_true()
	assert_str(_drawer().get_tab_text()).is_equal("Address Book (3)")
	# Collapsed, the Ring and desk take the width up to the tab.
	var content: Control = _view.get_node("Margin") as Control
	assert_float(content.get_global_rect().end.x).is_greater(
		_view.get_global_rect().end.x - AddressBookDrawer.TAB_WIDTH - 16.0
	)


@warning_ignore("unused_parameter")
func test_opens_and_closes_by_mouse_keyboard_and_gamepad(
	device: String, test_parameters: Array = [["mouse"], ["keyboard"], ["gamepad"]]  # gdlint: ignore=unused-argument,max-line-length
) -> void:
	_fill(2)
	var tab: Button = _drawer().get_tab()
	match device:
		"mouse":
			await UiInput.click(tab)
		"keyboard":
			await _key(tab, KEY_ENTER)
		"gamepad":
			await UiInput.pad(tab, JOY_BUTTON_A)
	assert_bool(_drawer().is_open()).is_true()
	var focused: Control = _view.get_viewport().gui_get_focus_owner()
	assert_object(focused).is_same(_view.get_address_book().get_rows()[0])
	match device:
		"mouse":
			await UiInput.click(tab)
		"keyboard":
			await _key(focused, KEY_ESCAPE)
		"gamepad":
			await UiInput.pad(focused, JOY_BUTTON_B)
	assert_bool(_drawer().is_open()).is_false()


func _key(control: Control, keycode: Key) -> void:
	control.grab_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await UiInput.settle(control)


## While a wormhole is open, the strip stops left of the tab, and Open the Address Book opens
## the drawer above the strip with focus in the book.
func test_the_wormhole_action_opens_the_drawer_over_the_strip() -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	SimClock.step_ticks(2)
	await UiInput.settle(_view)
	var screen: WormholeScreen = _view.get_overlays().get_wormhole_screen()
	assert_bool(screen.is_showing_open()).is_true()
	var strip: Control = screen.get_node("Column") as Control
	assert_float(strip.get_global_rect().end.x).is_less_equal(
		_drawer().get_tab().get_global_rect().position.x
	)
	Fixture.open_actions(_view)
	screen.get_actions().book_requested.emit()
	await UiInput.settle(_view)
	assert_bool(_drawer().is_open()).is_true()
	assert_bool(screen.are_actions_shown()).is_false()
	var focused: Control = _view.get_viewport().gui_get_focus_owner()
	assert_bool(_drawer().is_ancestor_of(focused)).is_true()
	assert_int(_drawer().get_index()).is_greater(_view.get_overlays().get_index())


@warning_ignore("unused_parameter")
func test_fifty_entries_fit_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	_fill(50)
	_drawer().open()
	_view.get_address_book().show_filters(true)
	_view.get_address_book().select(_simulation.state.address_book.entries[0].address_key)
	await UiInput.settle(_view)
	var sheet: Control = _drawer().get_node("Sheet") as Control
	assert_float(_drawer().get_combined_minimum_size().y).is_less_equal(Fixture.VIEW_SIZE.y)
	assert_float(sheet.size.x).is_between(340.0, 400.0)
	var book: AddressBookPanel = _view.get_address_book()
	assert_int(book.get_rows().size()).is_equal(50)
	var row: AddressBookRow = book.get_rows()[0]
	assert_float(row.size.x).is_less_equal(sheet.size.x)
	var scroll: ScrollContainer = book.get_node("Scroll") as ScrollContainer
	assert_float(scroll.size.y).is_greater_equal(row.size.y)
	assert_bool(scroll.get_v_scroll_bar().visible).is_true()
	var strip: AddressStrip = row.find_child("Strip", true, false) as AddressStrip
	assert_int(strip.icon_size).is_greater_equal(32)
