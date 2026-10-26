## Tests that the Archive fits the minimum window (1280 x 720, a 1280 x 600 view area under the
## tab and time bars) in English, in Brazilian Portuguese and under Godot's pseudolocalization:
## with a long document and an image read side by side, and with the image viewer open, the
## laid-out content's minimum size fits the area and no single-line label or button is
## narrower than its text (labels that end in an ellipsis by design are skipped).
## Bible: technical-architecture.md#input-accessibility-and-localisation, game-design.md#core-loop
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/archive_fixture.gd")
## Extra pixels a control may be short of its text before it counts as clipped.
const SLACK: float = 1.0
## Room an OptionButton keeps for its arrow.
const ARROW: float = 28.0

var _simulation: Simulation = null
var _holder: Control = null
var _view: ArchiveView = null
var _translation: Translation = null
var _real_locale: String = ""


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.remove_translation(_translation)
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.reload_pseudolocalization()
	TranslationServer.set_locale(_real_locale)
	Fixture.restore()


## Builds a busy Archive: every fixture document held, the long dossier open with the rubbing
## (an image) beside it.
func _build(locale: String, is_pseudo: bool) -> void:
	_real_locale = TranslationServer.get_locale()
	_translation = Fixture.translation()
	TranslationServer.add_translation(_translation)
	TranslationServer.set_locale(locale)
	TranslationServer.pseudolocalization_enabled = is_pseudo
	TranslationServer.reload_pseudolocalization()
	Fixture.load_content()
	_simulation = Fixture.simulation()
	_simulation.submit(DeliverDocumentCommand.create(Fixture.DOSSIER))
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)
	_view.open_document(Fixture.DOSSIER)
	_view.open_beside(Fixture.RUBBING)
	await get_tree().process_frame
	await get_tree().process_frame


## Visible controls whose single-line text is wider than the control.
func _clipped(root: Node) -> Array[String]:
	var found: Array[String] = []
	for child: Node in root.get_children():
		found.append_array(_clipped(child))
	if not (root is Control) or not (root as Control).is_visible_in_tree():
		return found
	if root is Label:
		var label: Label = root as Label
		var single: bool = label.autowrap_mode == TextServer.AUTOWRAP_OFF
		if single and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
			_check(label, _shown(label, label.text), 0.0, found)
	elif root is OptionButton:
		_check(root as Control, (root as OptionButton).text, ARROW, found)
	elif root is Button and not (root is DocumentRow) and (root as Button).icon == null:
		_check(root as Control, _shown(root as Control, (root as Button).text), 8.0, found)
	return found


## [param text] as [param control] draws it: translated only when it translates by itself.
func _shown(control: Control, text: String) -> String:
	return control.tr(text) if control.can_auto_translate() else text


func _check(control: Control, text: String, padding: float, found: Array[String]) -> void:
	if text.is_empty():
		return
	var font: Font = control.get_theme_font(&"font")
	var size: int = control.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width + padding > control.size.x + SLACK:
		found.append("%s: '%s' needs %d px, has %d" % [control.name, text, width, control.size.x])


func _assert_fits(content: Control) -> void:
	var needed: Vector2 = content.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(Fixture.VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(Fixture.VIEW_SIZE.y)


@warning_ignore("unused_parameter")
func test_the_archive_fits_the_minimum_window_and_no_text_is_clipped(
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
	_assert_fits(_view.get_node("%Columns") as Control)
	assert_array(_clipped(_view)).is_empty()
	var reader: DocumentReader = _view.get_reader()
	assert_float(reader.get_scroll().size.y).is_greater(200.0)
	assert_int(reader.get_scroll().max_scroll()).is_greater(0)
	_view.get_reader(true).get_image_button().pressed.emit()
	await get_tree().process_frame
	var viewer: ImageViewer = _view.get_image_viewer()
	assert_bool(viewer.is_open()).is_true()
	_assert_fits(viewer.get_node("Layout") as Control)
	assert_array(_clipped(viewer)).is_empty()
	assert_float(viewer.get_frame().size.y).is_greater(400.0)
