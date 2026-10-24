## Tests that the Archive works by mouse, keyboard and gamepad alone: opening a document from the
## list, scrolling a long text, "Read with…" and its menu, two readers that scroll independently,
## and the image viewer (zoom and pan by wheel, drag, buttons and arrows; Cancel closes it and
## focus goes back to the image).
## Bible: game-design.md#core-loop, technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/archive_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: ArchiveView = null
var _translation: Translation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_translation = Fixture.translation()
	TranslationServer.add_translation(_translation)
	Fixture.load_content()
	_simulation = Fixture.simulation()
	_simulation.submit(DeliverDocumentCommand.create(Fixture.DOSSIER))
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
	TranslationServer.remove_translation(_translation)
	TranslationServer.set_locale(_real_locale)
	Fixture.restore()


func _focus_owner() -> Control:
	return _holder.get_viewport().gui_get_focus_owner()


func _row(document_id: StringName) -> DocumentRow:
	for row: DocumentRow in _view.get_list().get_rows():
		if row.get_document_id() == document_id:
			return row
	return null


## Mouse: a click opens a document, the wheel scrolls its text, the image opens large, the
## wheel zooms it, a drag pans it and Close shuts it.
func test_mouse_reads_and_views_the_image() -> void:
	await UiInput.click(_row(Fixture.DOSSIER))
	var reader: DocumentReader = _view.get_reader()
	assert_str(String(reader.get_document_id())).is_equal("doc_dossier")
	await Fixture.wheel(reader.get_scroll(), false)
	assert_int(reader.get_scroll().scroll_vertical).is_greater(0)
	await UiInput.click(_row(Fixture.RUBBING))
	await UiInput.click(reader.get_image_button())
	var viewer: ImageViewer = _view.get_image_viewer()
	assert_bool(viewer.is_open()).is_true()
	var fitted: Vector2 = viewer.get_picture().size
	await Fixture.wheel(viewer.get_frame(), true)
	assert_float(viewer.get_zoom_pan().zoom).is_greater(1.0)
	assert_float(viewer.get_picture().size.x).is_greater(fitted.x)
	var before: Vector2 = viewer.get_zoom_pan().offset
	await UiInput.drag(viewer.get_frame(), viewer.find_child("FitButton", true, false) as Control)
	assert_bool(viewer.get_zoom_pan().offset.is_equal_approx(before)).is_false()
	await UiInput.click(viewer.find_child("CloseButton", true, false) as Control)
	assert_bool(viewer.is_open()).is_false()
	assert_object(_focus_owner()).is_same(reader.get_image_button())


## Keyboard: Enter opens the focused row, Right moves into the reader, Down scrolls the text,
## "Read with…" opens the menu whose first item is the pair, and Enter opens it beside.
func test_keyboard_reads_two_documents_side_by_side() -> void:
	_view.get_default_focus().grab_focus()
	assert_object(_focus_owner()).is_same(_row(Fixture.DOSSIER))
	await Fixture.key(KEY_ENTER)
	var reader: DocumentReader = _view.get_reader()
	assert_str(String(reader.get_document_id())).is_equal("doc_dossier")
	await Fixture.key(KEY_RIGHT)
	assert_bool(reader.is_ancestor_of(_focus_owner())).is_true()
	reader.get_scroll().grab_focus()
	await Fixture.key(KEY_DOWN)
	await Fixture.key(KEY_DOWN)
	assert_int(reader.get_scroll().scroll_vertical).is_equal(2 * ScrollPane.STEP)
	reader.get_read_with_button().grab_focus()
	await Fixture.key(KEY_ENTER)
	var menu: PopupMenu = _view.get_read_with_menu()
	assert_bool(menu.visible).is_true()
	await Fixture.key(KEY_ENTER)
	var beside: DocumentReader = _view.get_reader(true)
	assert_bool(beside.visible).is_true()
	assert_str(String(beside.get_document_id())).is_not_empty()
	assert_bool(beside.is_ancestor_of(_focus_owner())).is_true()


## Two readers scroll independently, and Up at the top moves focus on instead of sticking.
func test_two_readers_scroll_independently() -> void:
	_view.open_document(Fixture.NOTE)
	_view.open_beside(Fixture.DOSSIER)
	await UiInput.settle(_view)
	var left: ScrollPane = _view.get_reader().get_scroll()
	var right: ScrollPane = _view.get_reader(true).get_scroll()
	right.grab_focus()
	await Fixture.pad(JOY_BUTTON_DPAD_DOWN)
	await Fixture.pad(JOY_BUTTON_DPAD_DOWN)
	assert_int(right.scroll_vertical).is_equal(2 * ScrollPane.STEP)
	assert_int(left.scroll_vertical).is_equal(0)
	await Fixture.key(KEY_PAGEUP)
	assert_int(right.scroll_vertical).is_equal(0)
	await Fixture.key(KEY_UP)
	assert_object(_focus_owner()).is_not_same(right)


## Gamepad: A opens a row and the image, the d-pad pans a zoomed image, the Zoom buttons work
## by A, and B closes the viewer with focus back on the image.
func test_gamepad_views_the_image() -> void:
	_row(Fixture.RUBBING).grab_focus()
	await Fixture.pad(JOY_BUTTON_A)
	var reader: DocumentReader = _view.get_reader()
	assert_str(String(reader.get_document_id())).is_equal("doc_rubbing")
	reader.get_image_button().grab_focus()
	await Fixture.pad(JOY_BUTTON_A)
	var viewer: ImageViewer = _view.get_image_viewer()
	assert_bool(viewer.is_open()).is_true()
	assert_object(_focus_owner()).is_same(viewer.get_frame())
	var zoom_in: Button = viewer.find_child("ZoomInButton", true, false) as Button
	await UiInput.pad(zoom_in, JOY_BUTTON_A)
	await Fixture.pad(JOY_BUTTON_A)
	assert_float(viewer.get_zoom_pan().zoom).is_equal_approx(ZoomPan.STEP * ZoomPan.STEP, 0.001)
	viewer.get_frame().grab_focus()
	var before: Vector2 = viewer.get_zoom_pan().offset
	await Fixture.pad(JOY_BUTTON_DPAD_RIGHT)
	assert_float(viewer.get_zoom_pan().offset.x).is_less(before.x)
	assert_object(_focus_owner()).is_same(viewer.get_frame())
	await Fixture.pad(JOY_BUTTON_B)
	assert_bool(viewer.is_open()).is_false()
	assert_object(_focus_owner()).is_same(reader.get_image_button())


## At fit zoom the arrows cannot pan, so they move focus to the toolbar.
func test_arrows_leave_a_fitted_image() -> void:
	_view.open_document(Fixture.RUBBING)
	_view.get_reader().get_image_button().pressed.emit()
	await UiInput.settle(_view)
	var viewer: ImageViewer = _view.get_image_viewer()
	assert_object(_focus_owner()).is_same(viewer.get_frame())
	await Fixture.key(KEY_UP)
	assert_bool(viewer.find_child("Toolbar", true, false).is_ancestor_of(_focus_owner())).is_true()


## Right from the kind filter goes into the open document, never up to the view tabs.
func test_right_from_the_filter_enters_the_reader() -> void:
	var filter: OptionButton = _view.get_list().get_filter_button()
	filter.grab_focus()
	await Fixture.key(KEY_RIGHT)
	assert_object(_focus_owner()).is_same(filter)
	_view.open_document(Fixture.NOTE)
	filter.grab_focus()
	await Fixture.key(KEY_RIGHT)
	assert_object(_focus_owner()).is_same(_view.get_reader().get_default_focus())
