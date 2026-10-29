## Tests for the Address Book panel in the Gate Room: entries appear after dials and from
## documents and consoles, the glyph, text and source filters show exactly the matching
## entries with their count, Load fills the console's slots, and a note saved through the panel
## survives a save and load.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## game-design.md#difficulty-and-accessibility
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SaveServiceScript := preload("res://src/services/save_service.gd")

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


func _book() -> AddressBookPanel:
	return _view.get_address_book()


func _dial(address: GateAddress) -> void:
	Fixture.select(_view, address)
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	if _view.get_console().get_dial_controls().is_repeat_armed():
		button.begin_hold()
		button.advance(HoldButton.HOLD_SECONDS)
	SimClock.step_ticks(2)
	if _simulation.state.gate.mode == GateState.RingMode.LOCKED:
		(_view.find_child("CloseButton", true, false) as Button).pressed.emit()
	_view.get_overlays().get_result_card().dismiss()
	_view.get_overlays().get_wormhole_screen().dismiss()


## Opens the drawer and the filters header with clicks.
func _show_filters() -> void:
	await UiInput.click(_view.get_address_drawer().get_tab())
	await UiInput.click(_book().find_child("FiltersButton", true, false) as Control)


func _keys() -> Array[String]:
	var keys: Array[String] = []
	for row: AddressBookRow in _book().get_rows():
		keys.append(row.get_address_key())
	return keys


func _origin() -> int:
	return _simulation.state.galaxy.home().origin_glyph


## Adds an entry from [param source] for a random well-formed address to the book's top.
func _add_entry(rng: RandomNumberGenerator, source: AddressEntry.Source) -> AddressEntry:
	var glyphs: Array[int] = []
	while glyphs.size() < GateAddress.COORDINATE_COUNT:
		var glyph: int = rng.randi_range(0, GateAddress.GLYPH_COUNT - 1)
		if glyph != _origin() and not glyphs.has(glyph):
			glyphs.append(glyph)
	var key: String = GateAddress.create(glyphs, _origin()).key()
	var source_id: StringName = &""
	if source == AddressEntry.Source.DOCUMENT:
		source_id = &"doc_test_note"
	elif source == AddressEntry.Source.CONSOLE:
		source_id = DialFixture.BURIED_ID
	var entry := AddressEntry.create(key, source, source_id)
	_simulation.state.address_book.entries.push_front(entry)
	return entry


func test_an_empty_book_says_so() -> void:
	assert_int(_book().get_rows().size()).is_equal(0)
	assert_str(_book().get_count_text()).is_equal("0 addresses")
	assert_str(_book().get_empty_text()).starts_with("No addresses yet.")


func test_dials_add_entries_newest_first_and_name_only_locked_worlds() -> void:
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.NO_GATE))
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	var rows: Array[AddressBookRow] = _book().get_rows()
	assert_int(rows.size()).is_equal(2)
	assert_str(_book().get_count_text()).is_equal("2 addresses")
	assert_str(_book().get_empty_text()).is_empty()
	assert_str(rows[0].get_details_text()).is_equal("Dialed · P3X-111")
	assert_str(rows[1].get_details_text()).is_equal("Dialed · world unknown")
	assert_int(rows[0].get_entry().last_outcome).is_equal(DialOutcome.Kind.LOCK)


func test_document_and_console_entries_show_their_source() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var from_document: AddressEntry = _add_entry(rng, AddressEntry.Source.DOCUMENT)
	from_document.world_id = DialFixture.OPEN_ID
	_add_entry(rng, AddressEntry.Source.CONSOLE)
	EventBus.address_book_changed.emit()
	var rows: Array[AddressBookRow] = _book().get_rows()
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[0].get_details_text()).is_equal("Console of P3X-222 · world unknown")
	assert_str(rows[1].get_details_text()).is_equal("Document · P3X-111")


## Picking glyphs on the mini-palette shows exactly the entries holding all of them.
func test_glyph_filter_shows_exactly_the_entries_with_every_picked_glyph() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	for _index: int in 24:
		_add_entry(rng, AddressEntry.Source.DIALED)
	_view.setup(_simulation)
	await _show_filters()
	var filter: GlyphFilter = _book().find_child("GlyphFilter", true, false) as GlyphFilter
	for _round: int in 12:
		_book().clear_filters()
		var picked: Array[int] = []
		for _pick: int in rng.randi_range(1, 3):
			var glyph: int = rng.randi_range(0, GateAddress.GLYPH_COUNT - 1)
			if not picked.has(glyph):
				picked.append(glyph)
				await UiInput.click(filter.get_button(glyph))
		var expected: Array[String] = []
		for entry: AddressEntry in _simulation.state.address_book.entries:
			var seals: Array[int] = AddressEntry.glyphs_of(entry.address_key)
			if picked.all(func(glyph: int) -> bool: return seals.has(glyph)):
				expected.append(entry.address_key)
		assert_array(_keys()).is_equal(expected)
		var count: String = (
			"1 address" if expected.size() == 1 else "%d addresses" % expected.size()
		)
		assert_str(_book().get_count_text()).is_equal(count)
		for glyph: int in picked:
			assert_bool(filter.get_button(glyph).button_pressed).is_true()


## Picking a glyph again removes it from the filter; no match says why the list is empty.
func test_glyph_filter_toggles_and_explains_an_empty_result() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var entry: AddressEntry = _add_entry(rng, AddressEntry.Source.DIALED)
	_view.setup(_simulation)
	var seals: Array[int] = AddressEntry.glyphs_of(entry.address_key)
	var missing: int = 0
	while seals.has(missing):
		missing += 1
	_book().toggle_glyph(missing)
	assert_int(_book().get_rows().size()).is_equal(0)
	assert_str(_book().get_empty_text()).is_equal("No address matches these filters.")
	_book().toggle_glyph(missing)
	assert_array(_keys()).is_equal([entry.address_key])


func test_text_and_source_filters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var noted: AddressEntry = _add_entry(rng, AddressEntry.Source.DIALED)
	noted.note = "Quiet MOUNTAIN pass"
	var named: AddressEntry = _add_entry(rng, AddressEntry.Source.DOCUMENT)
	named.world_id = DialFixture.GUARDED_ID
	_add_entry(rng, AddressEntry.Source.CONSOLE)
	_view.setup(_simulation)
	var search: LineEdit = _book().find_child("SearchEdit", true, false) as LineEdit
	search.text = "mountain"
	search.text_changed.emit(search.text)
	assert_array(_keys()).is_equal([noted.address_key])
	search.text = "p3x-444"
	search.text_changed.emit(search.text)
	assert_array(_keys()).is_equal([named.address_key])
	search.text = ""
	search.text_changed.emit(search.text)
	var source: OptionButton = _book().find_child("SourceFilter", true, false) as OptionButton
	source.select(1)
	source.item_selected.emit(1)
	assert_array(_keys()).is_equal([named.address_key])
	assert_str(_book().get_count_text()).is_equal("1 address")


## Open the drawer, select a row and press Load: the console's slots hold the address and the
## drawer collapses.
func test_load_fills_the_console_slots_and_collapses() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.BLOCKED)
	_dial(address)
	_view.get_console().clear_all()
	await UiInput.click(_view.get_address_drawer().get_tab())
	assert_bool(_view.get_address_drawer().is_open()).is_true()
	var load_button: Button = _book().find_child("LoadButton", true, false) as Button
	assert_bool(load_button.disabled).is_true()
	await UiInput.click(_book().get_rows()[0])
	assert_str(_book().get_selected()).is_equal(address.key())
	await UiInput.click(load_button)
	assert_bool(_view.get_console().get_address().equals(address)).is_true()
	assert_bool(_view.get_address_drawer().is_open()).is_false()
	var dial: Control = _view.find_child("DialButton", true, false) as Control
	assert_object(_view.get_viewport().gui_get_focus_owner()).is_same(dial)


## A note typed for the selected entry is saved with a NoteAddressCommand and survives a save
## and load.
func test_a_note_saves_and_survives_save_and_load() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.NO_GATE)
	_dial(address)
	_view.get_address_drawer().open()
	await UiInput.settle(_view)
	_book().select(address.key())
	var note_edit: LineEdit = _book().find_child("NoteEdit", true, false) as LineEdit
	note_edit.text = "Nothing there. Recheck seal 3?"
	await UiInput.click(_book().find_child("SaveNoteButton", true, false) as Button)
	assert_str(_simulation.state.address_book.find(address.key()).note).is_equal(note_edit.text)
	assert_str(_book().get_rows()[0].get_note_text()).is_equal(note_edit.text)
	# The note shows on the selected row only.
	var note: Label = _book().get_rows()[0].find_child("Note", true, false) as Label
	assert_bool(note.visible).is_true()
	_book().select("")
	assert_bool(note.visible).is_false()
	var service: SaveServiceScript = SaveServiceScript.new()
	service.saves_dir = "user://test_saves_book_%d" % Time.get_ticks_usec()
	assert_bool(service.save_game(_simulation.state, &"book_note").is_ok).is_true()
	var loaded: Result = service.load_game(&"book_note")
	_remove_saves(service)
	assert_bool(loaded.is_ok).is_true()
	var state: GameState = loaded.value
	state.galaxy = _simulation.state.galaxy
	state.balance = _simulation.state.balance
	var reloaded: Simulation = DialFixture.simulation(state)
	_view.setup(reloaded)
	assert_str(_book().get_rows()[0].get_note_text()).is_equal("Nothing there. Recheck seal 3?")


## Drive it like a player: place seven glyphs three different ways (drag onto the slot, click
## or gamepad accept to fill the next empty seal), dial, load the address
## back from the book and dial it again, confirming the repeat.
func test_place_three_ways_dial_load_and_dial_again() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.NO_GATE)
	var palette: GlyphPalette = _view.find_child("Palette", true, false) as GlyphPalette
	var seals: SealRow = _view.find_child("SealRow", true, false) as SealRow
	for index: int in GateAddress.COORDINATE_COUNT:
		var glyph: PaletteGlyph = palette.get_button(address.coordinates[index])
		var slot: SealSlot = seals.get_slot(index + 1)
		match index % 3:
			0:
				await UiInput.drag(glyph, slot)
			1:
				await UiInput.click(glyph)
			_:
				await UiInput.pad(glyph, JOY_BUTTON_A)
	assert_bool(_view.get_console().get_address().equals(address)).is_true()
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	SimClock.step_ticks(2)
	_view.get_console().clear_all()
	_book().select(address.key())
	_book().load_selected()
	assert_bool(_view.get_console().get_address().equals(address)).is_true()
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(1)


func _remove_saves(service: SaveServiceScript) -> void:
	var dir := DirAccess.open(service.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(service.saves_dir.path_join(file_name))
		DirAccess.remove_absolute(service.saves_dir)
	service.free()
