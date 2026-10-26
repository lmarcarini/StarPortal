## Tests that the Gate Room fits the minimum window (1280 x 720, a 1280 x 600 view area under
## the tab and time bars) in English, in Brazilian Portuguese and under Godot's
## pseudolocalization (text about 30% longer): the laid-out content's minimum size fits the
## area, the Address Book list keeps room for a row, and no label or button is narrower than
## its text.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## gate-and-address-spec.md#the-dial-console
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
## Extra pixels a control may be short of its text before it counts as clipped.
const SLACK: float = 1.0

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.reload_pseudolocalization()
	TranslationServer.set_locale(_real_locale)


## Builds a busy Gate Room: a failed dial, a lock still open, the failed address loaded again
## (so the repeat warning shows), a glyph clicked and the book filtered by one glyph.
func _build(locale: String, is_pseudo: bool) -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	TranslationServer.pseudolocalization_enabled = is_pseudo
	TranslationServer.reload_pseudolocalization()
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)
	_dial(DialOutcome.Kind.NO_GATE)
	_dial(DialOutcome.Kind.LOCK)
	var failed: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.NO_GATE)
	Fixture.select(_view, failed)
	var palette: GlyphPalette = _view.find_child("Palette", true, false) as GlyphPalette
	palette.glyph_chosen.emit(failed.coordinates[0])
	_view.get_address_book().toggle_glyph(failed.coordinates[0])
	await get_tree().process_frame
	await get_tree().process_frame


func _dial(kind: int) -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, kind))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	SimClock.step_ticks(2)


## Visible controls whose single-line text is wider than the control.
func _clipped(root: Node) -> Array[String]:
	var found: Array[String] = []
	for child: Node in root.get_children():
		found.append_array(_clipped(child))
	if not (root is Control) or not (root as Control).is_visible_in_tree():
		return found
	var control: Control = root as Control
	if control is Label and (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
		_check_label(control as Label, found)
	elif control is Button and not (control is OptionButton):
		_check_button(control as Button, found)
	elif control is OptionButton:
		_check_option(control as OptionButton, found)
	return found


func _check_label(label: Label, found: Array[String]) -> void:
	var text: String = label.tr(label.text)
	var font: Font = label.get_theme_font(&"font")
	var size: int = label.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width > label.size.x + SLACK:
		found.append("%s: '%s' needs %d px, has %d" % [label.name, text, width, label.size.x])


func _check_button(button: Button, found: Array[String]) -> void:
	var text: String = button.tr(button.text)
	if text.is_empty():
		return
	var font: Font = button.get_theme_font(&"font")
	var size: int = button.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var room: float = (
		button.size.x
		- button.get_minimum_size().x
		+ font.get_string_size("", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	)
	if width > room + button.get_minimum_size().x - SLACK:
		found.append("%s: '%s' needs %d px, has %d" % [button.name, text, width, button.size.x])


func _check_option(option: OptionButton, found: Array[String]) -> void:
	var font: Font = option.get_theme_font(&"font")
	var size: int = option.get_theme_font_size(&"font_size")
	var arrow: float = 28.0
	var width: float = font.get_string_size(option.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width + arrow > option.size.x:
		found.append(
			"%s: '%s' needs %d px, has %d" % [option.name, option.text, width, option.size.x]
		)


@warning_ignore("unused_parameter")
func test_the_view_fits_the_minimum_window_and_no_text_is_clipped(
	locale: String,
	is_pseudo: bool,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		["en", false],
		["pt_BR", false],
		["en", true],
		["pt_BR", true],
	]
) -> void:
	await _build(locale, is_pseudo)
	var content: Control = _view.get_node("Margin") as Control
	var needed: Vector2 = content.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(Fixture.VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(Fixture.VIEW_SIZE.y)
	assert_array(_clipped(_view)).is_empty()
	var book: AddressBookPanel = _view.get_address_book()
	assert_int(book.get_rows().size()).is_greater(0)
	var scroll: Control = book.get_node("Scroll") as Control
	assert_float(scroll.size.y).is_greater_equal(book.get_rows()[0].size.y)


## The overlays (wormhole screen, result card, dialing sequence) fit the view area too, with
## no clipped text.
@warning_ignore("unused_parameter")
func test_the_overlays_fit_the_minimum_window(
	locale: String,
	is_pseudo: bool,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		["en", false],
		["pt_BR", true],
	]
) -> void:
	await _build(locale, is_pseudo)
	var overlays: GateOverlays = _view.get_overlays()
	assert_bool(overlays.get_wormhole_screen().is_showing_open()).is_true()
	overlays.get_result_card().show_entry(_simulation.state.gate.dial_log[0])
	await get_tree().process_frame
	var screens: Array[Control] = [
		overlays.get_wormhole_screen(), overlays.get_result_card(), overlays.get_sequence()
	]
	for screen: Control in screens:
		var needed: Vector2 = (
			(screen.get_node("Center/Panel") as Control).get_combined_minimum_size()
		)
		assert_float(needed.x).is_less_equal(Fixture.VIEW_SIZE.x)
		assert_float(needed.y).is_less_equal(Fixture.VIEW_SIZE.y)
	assert_array(_clipped(overlays)).is_empty()
