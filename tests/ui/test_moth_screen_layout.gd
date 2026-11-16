## Tests that the MOTH scan screen fits the minimum window (the 1280 x 600 view area under the
## top bar at 1280 x 720) in en and pt_BR with the real font: no text is clipped and every
## character has a glyph, both live (with the targets listed) and at SIGNAL LOST.
## Bible: docs/content/m3-beyond-the-ring.md section 7 (MOTH scan screen),
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const SLACK: float = 1.0

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null
var _real_locale: String = ""


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _build(locale: String) -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	var game: GameState = ProbeFixture.state()
	_simulation = ProbeFixture.simulation(game)
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)
	ProbeFixture.open(_simulation)
	SimClock.pause()
	_simulation.submit(LaunchMothCommand.new())
	_simulation.submit(MothScanCommand.create(MothRules.Scan.LOOK_AROUND))
	SimClock.step_ticks(5)
	_simulation.submit(MothScanCommand.create(MothRules.Scan.CLOSE_LOOK, ProbeFixture.ANCHOR_ID))
	await get_tree().process_frame
	await get_tree().process_frame


func _assert_fits(root: Node, locale: String) -> void:
	for child: Node in root.get_children():
		_assert_fits(child, locale)
	if not root is Control or not (root as Control).is_visible_in_tree():
		return
	var text: String = ""
	var width: float = (root as Control).size.x
	if root is Label:
		text = (root as Label).tr((root as Label).text)
		if (root as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			width = INF
	elif root is Button:
		text = (root as Button).tr((root as Button).text)
		if (root as Button).autowrap_mode != TextServer.AUTOWRAP_OFF:
			width = INF
	if text.is_empty():
		return
	var control: Control = root as Control
	var font: Font = control.get_theme_font(&"font")
	var font_size: int = control.get_theme_font_size(&"font_size")
	for character: String in text:
		(
			assert_bool(font.has_char(character.unicode_at(0)))
			. override_failure_message("%s: no glyph for '%s'" % [locale, character])
			. is_true()
		)
	var needed: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	(
		assert_float(needed)
		. override_failure_message("%s: '%s' needs %d px, has %d" % [locale, text, needed, width])
		. is_less_equal(width + SLACK + 16.0)
	)


func _assert_screen_fits(locale: String) -> void:
	var screen: MothScreen = _view.get_moth_screen()
	assert_bool(screen.is_visible_in_tree()).is_true()
	var needed: Vector2 = screen.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(Fixture.VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(Fixture.VIEW_SIZE.y)
	assert_bool(_holder.get_global_rect().encloses(screen.get_global_rect())).is_true()
	_assert_fits(screen, locale)


@warning_ignore("unused_parameter")
func test_the_screen_fits_live_and_lost(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	await _build(locale)
	_assert_screen_fits(locale)
	_simulation.submit(CloseWormholeCommand.new())
	SimClock.step_ticks(1)
	await get_tree().process_frame
	assert_int(_view.get_moth_screen().get_phase()).is_equal(MothScreen.Phase.LOST)
	_assert_screen_fits(locale)


## The longest finished-scan text (STILLWATER's Look around) fits under the frame.
@warning_ignore("unused_parameter")
func test_the_longest_scan_text_fits(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	await _build(locale)
	var screen: MothScreen = _view.get_moth_screen()
	assert_str(screen.get_result_label().text).is_not_empty()
	screen.get_result_label().text = tr(&"MOTH_LOOK_STILLWATER")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_screen_fits(locale)
	assert_float(screen.get_frame().size.y).is_greater(200.0)
