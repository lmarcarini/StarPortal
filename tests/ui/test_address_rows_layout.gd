## Card #127: Address Book rows never overlap. With 1, 10 and 50 entries, in English, Brazilian
## Portuguese and under pseudolocalization, each row is at least a 32 px glyph strip plus a text
## line tall, no two rows' rects overlap and every glyph and label sits inside its row; with 50
## entries the list scrolls and gamepad focus moves row by row, keeping the row visible.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
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
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.reload_pseudolocalization()
	TranslationServer.set_locale(_real_locale)


func _book() -> AddressBookPanel:
	return _view.get_address_book()


## Adds [param count] entries with distinct addresses and long notes, then opens the drawer.
func _open_with(count: int, locale: String) -> void:
	TranslationServer.set_locale("en" if locale == "pseudo" else locale)
	TranslationServer.pseudolocalization_enabled = locale == "pseudo"
	TranslationServer.reload_pseudolocalization()
	var origin: int = _simulation.state.galaxy.home().origin_glyph
	var rng := RandomNumberGenerator.new()
	rng.seed = 127
	while _simulation.state.address_book.entries.size() < count:
		var glyphs: Array[int] = []
		while glyphs.size() < GateAddress.COORDINATE_COUNT:
			var glyph: int = rng.randi_range(0, GateAddress.GLYPH_COUNT - 1)
			if glyph != origin and not glyphs.has(glyph):
				glyphs.append(glyph)
		var key: String = GateAddress.create(glyphs, origin).key()
		if _simulation.state.address_book.find(key) == null:
			var source: AddressEntry.Source = AddressEntry.Source.CONSOLE
			var entry := AddressEntry.create(key, source, &"")
			entry.note = "A long survey note about this world, number %d" % count
			_simulation.state.address_book.entries.push_front(entry)
	EventBus.address_book_changed.emit()
	_view.get_address_drawer().open()
	_book().select(_simulation.state.address_book.entries[0].address_key)
	await UiInput.settle(_view)
	await UiInput.settle(_view)


func _assert_inside(child: Control, row: AddressBookRow) -> void:
	var outer: Rect2 = row.get_global_rect().grow(0.5)
	(
		assert_bool(outer.encloses(child.get_global_rect()))
		. override_failure_message(
			"%s %s leaves row %s" % [child.name, child.get_global_rect(), row.get_global_rect()]
		)
		. is_true()
	)


func _assert_row_layout(row: AddressBookRow) -> void:
	assert_float(row.size.y).is_greater_equal(AddressBookRow.MIN_HEIGHT)
	var strip: AddressStrip = row.find_child("Strip", true, false) as AddressStrip
	for child: Node in strip.get_children():
		if child is GlyphIcon:
			assert_float((child as Control).size.y).is_greater_equal(32.0)
			_assert_inside(child as Control, row)
	for name: String in ["Icon", "Details", "Note"]:
		var part: Control = row.find_child(name, true, false) as Control
		if part.is_visible_in_tree():
			_assert_inside(part, row)


@warning_ignore("unused_parameter")
func test_rows_never_overlap(
	count: int,
	locale: String,
	test_parameters: Array = [
		[1, "en"],
		[10, "en"],
		[50, "en"],
		[1, "pt_BR"],
		[10, "pt_BR"],
		[50, "pt_BR"],
		[1, "pseudo"],
		[10, "pseudo"],
		[50, "pseudo"],
	]  # gdlint: ignore=unused-argument
) -> void:
	await _open_with(count, locale)
	var rows: Array[AddressBookRow] = _book().get_rows()
	assert_int(rows.size()).is_equal(count)
	for index: int in rows.size():
		_assert_row_layout(rows[index])
		if index > 0:
			var above: Rect2 = rows[index - 1].get_global_rect()
			assert_float(rows[index].get_global_rect().position.y).is_greater_equal(above.end.y)


func test_fifty_rows_scroll_and_pad_focus_follows() -> void:
	await _open_with(50, "pt_BR")
	var scroll: ScrollContainer = _book().get_node("Scroll") as ScrollContainer
	assert_bool(scroll.get_v_scroll_bar().visible).is_true()
	var rows: Array[AddressBookRow] = _book().get_rows()
	var view_rect: Rect2 = scroll.get_global_rect().grow(0.5)
	for index: int in range(1, 12):
		await UiInput.pad(rows[index - 1], JOY_BUTTON_DPAD_DOWN)
		var focused: Control = _view.get_viewport().gui_get_focus_owner()
		assert_object(focused).is_same(rows[index])
		assert_bool(view_rect.encloses(focused.get_global_rect())).is_true()
