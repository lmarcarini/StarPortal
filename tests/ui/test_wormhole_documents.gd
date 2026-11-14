## Tests for the documents a wormhole brings, on the wormhole strip and actions: a first lock
## alone shows nothing; Extend the pole camera sends the camera and shows its progress while it
## goes through, and once the horizon record is taken ("Horizon record taken") the strip names
## the documents by title and the actions offer Read in the Archive, which opens the Archive
## with the first one selected; back in the Gate Room the strip still shows, focus is on the
## Ring and a click on it brings the actions back, with Dial still disabled; a lock that
## delivers nothing shows no line; the gamepad reaches the button; the strip and actions fit
## the minimum window in en and pt_BR with five new documents and the console's finds.
## Runs the whole view switcher over the dialing fixture galaxy, with a DocumentSystem that
## delivers two fixture documents with the open world's horizon record.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## game-design.md#core-loop
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const ArchiveFixture := preload("res://tests/ui/archive_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"
## Delivered with the open world's horizon record, in id order.
const LOCK_DOCUMENTS: Array[StringName] = [ArchiveFixture.DOSSIER, ArchiveFixture.NOTE]

var _root: Control = null
var _switcher: ViewSwitcher = null
var _simulation: Simulation = null
var _strings: Translation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_array(ArchiveFixture.load_content()).is_empty()
	_strings = ArchiveFixture.translation()
	TranslationServer.add_translation(_strings)
	_simulation = _make_simulation()
	SimClock.start(_simulation)
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	_switcher = (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	_switcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_switcher)
	add_child(_root)
	_switcher.setup(_simulation)
	await get_tree().process_frame


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.remove_translation(_strings)
	TranslationServer.set_locale(_real_locale)
	ArchiveFixture.restore()


## The gate fixture's simulation, plus a DocumentSystem: the dossier and the note arrive with the
## open world's horizon record; the Archive starts with the rubbing, read.
func _make_simulation() -> Simulation:
	var state: GameState = Fixture.simulation().state
	state.archive.add(ArchiveFixture.RUBBING, 0)
	state.archive.read[ArchiveFixture.RUBBING] = true
	var documents: Array[DocumentDef] = []
	for id: StringName in LOCK_DOCUMENTS:
		var def: DocumentDef = (Registry.get_def(id) as DocumentDef).duplicate() as DocumentDef
		def.arrival = DocumentDef.Arrival.ON_FIRST_LOCK
		def.arrival_world_id = DialFixture.OPEN_ID
		documents.append(def)
	var systems: Array[SimSystem] = [
		PowerSystem.new(state.balance), GateSystem.new(), DocumentSystem.new(documents)
	]
	return Simulation.new(state, systems)


func _gate() -> GateRoomView:
	return _switcher.get_view(ViewSwitcher.GATE_ROOM) as GateRoomView


func _archive() -> ArchiveView:
	return _switcher.get_view(ViewSwitcher.ARCHIVE) as ArchiveView


func _screen() -> WormholeScreen:
	return _gate().get_overlays().get_wormhole_screen()


func _line() -> Label:
	return _screen().get_node("%NewDocuments") as Label


func _focus_owner() -> Control:
	return _root.get_viewport().gui_get_focus_owner()


func _dial_button() -> Button:
	return _gate().get_console().get_dial_controls().get_dial_button()


## Dials the fixture world that gives [param kind] and skips the sequence.
func _dial(kind: int) -> void:
	Fixture.select(_gate(), Fixture.address_for(_simulation.state, kind))
	var button: HoldButton = _gate().find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	_gate().get_overlays().get_sequence().skip()
	Fixture.open_actions(_gate())
	await get_tree().process_frame


func _camera_button() -> Button:
	return _screen().get_actions().get_camera_button()


## Presses Extend the pole camera and runs the clock until the record is taken.
func _take_record() -> void:
	_camera_button().pressed.emit()
	SimClock.step_ticks(ExtendPoleCameraCommand.EXTEND_TICKS)
	await get_tree().process_frame


func _close_wormhole() -> void:
	Fixture.close_wormhole(_gate())
	_screen().dismiss()
	await get_tree().process_frame


## The lock alone names nothing; the camera button sends the camera, is disabled while it goes
## through, and the record names the documents it delivered.
func test_the_horizon_record_names_the_documents_it_delivered() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	assert_bool(_screen().is_showing_open()).is_true()
	assert_bool(_line().visible).is_false()
	var camera: Button = _camera_button()
	assert_bool(camera.is_visible_in_tree()).is_true()
	assert_bool(camera.disabled).is_false()
	assert_str(camera.tr(camera.text)).is_equal("Extend the pole camera")
	camera.pressed.emit()
	await get_tree().process_frame
	assert_bool(camera.disabled).is_true()
	assert_str(camera.tr(camera.text)).is_equal("The pole camera is going through…")
	assert_str(_screen().get_actions().get_camera_note()).is_equal("Horizon record in 5 min")
	var progress: ProgressBar = _screen().find_child("CameraProgress", true, false) as ProgressBar
	assert_bool(progress.is_visible_in_tree()).is_true()
	SimClock.step_ticks(2)
	assert_float(progress.value).is_equal(2.0)
	assert_str(_screen().get_actions().get_camera_note()).is_equal("Horizon record in 3 min")
	assert_bool(_line().visible).is_false()
	SimClock.step_ticks(ExtendPoleCameraCommand.EXTEND_TICKS - 2)
	await get_tree().process_frame
	assert_bool(progress.visible).is_false()
	assert_bool(camera.disabled).is_true()
	assert_str(camera.tr(camera.text)).is_equal("Horizon record taken")
	assert_bool(_line().is_visible_in_tree()).is_true()
	assert_str(_line().text).is_equal(
		"New in the Archive: Directorate file 61-B, Field note, lintel"
	)
	var button: Button = _screen().get_actions().get_archive_button()
	assert_bool(button.is_visible_in_tree()).is_true()
	assert_str(button.tr(button.text)).is_equal("Read in the Archive")
	assert_str(_switcher.get_tab_bar().get_tab_title(5)).is_equal("Archive (2)")


## Read in the Archive opens the Archive with the first new document selected and read; back
## in the Gate Room the strip still shows, focus is on the Ring, and the portal brings the
## actions back.
func test_read_in_the_archive_and_back_to_the_wormhole() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	await _take_record()
	_screen().get_actions().get_archive_button().pressed.emit()
	await get_tree().process_frame
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	assert_str(String(_archive().get_reader().get_document_id())).is_equal("doc_dossier")
	assert_object(_focus_owner()).is_same(_archive().get_default_focus())
	assert_str(_switcher.get_tab_bar().get_tab_title(5)).is_equal("Archive (1)")
	assert_bool(_screen().are_actions_shown()).is_false()
	_switcher.show_view(ViewSwitcher.GATE_ROOM)
	await get_tree().process_frame
	assert_bool(_screen().is_showing_open()).is_true()
	assert_bool(_line().is_visible_in_tree()).is_true()
	assert_object(_focus_owner()).is_same(_gate().get_ring_view())
	assert_bool(_dial_button().disabled).is_true()
	await ArchiveFixture.pad(JOY_BUTTON_A)
	assert_bool(_screen().are_actions_shown()).is_true()
	assert_object(_focus_owner()).is_same(_screen().get_default_focus())
	assert_bool(_dial_button().disabled).is_true()


## Locking the same world again delivers nothing new: no line, no button. A first lock of a
## world with no documents shows none either.
func test_a_lock_that_delivers_nothing_shows_no_line() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	await _take_record()
	await _close_wormhole()
	await _dial(DialOutcome.Kind.LOCK)
	assert_bool(_camera_button().disabled).is_true()
	assert_bool(_screen().is_showing_open()).is_true()
	assert_bool(_line().visible).is_false()
	assert_bool(_screen().get_actions().get_archive_button().visible).is_false()
	await _close_wormhole()
	await _dial(DialOutcome.Kind.HOSTILE_LOCK)
	await _take_record()
	assert_bool(_screen().is_showing_open()).is_true()
	assert_bool(_line().visible).is_false()
	assert_bool(_screen().get_actions().get_archive_button().visible).is_false()


func test_the_gamepad_reaches_read_in_the_archive() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	await _take_record()
	assert_object(_focus_owner()).is_same(_screen().get_console().get_read_button())
	await ArchiveFixture.pad(JOY_BUTTON_DPAD_DOWN)
	assert_object(_focus_owner()).is_same(_screen().get_actions().get_archive_button())
	await ArchiveFixture.pad(JOY_BUTTON_A)
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	assert_str(String(_archive().get_reader().get_document_id())).is_equal("doc_dossier")


@warning_ignore("unused_parameter")
func test_the_strip_and_actions_fit_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	await _dial(DialOutcome.Kind.LOCK)
	await _take_record()
	_screen().get_console().read()
	_line().text = WormholeText.new_documents_line(_five_documents())
	await get_tree().process_frame
	await get_tree().process_frame
	var column: Control = _screen().get_node("Column") as Control
	var strip: Control = _screen().get_node("%Strip") as Control
	var panel: Control = _screen().get_node("%ActionsPanel") as Control
	assert_bool(panel.is_visible_in_tree()).is_true()
	assert_float(column.get_combined_minimum_size().x).is_less_equal(column.size.x)
	# The strip leaves the actions room for at least a few rows; they scroll beyond that.
	assert_float(strip.size.y).is_less_equal(column.size.y / 2.0)
	assert_float(panel.size.y).is_greater_equal(120.0)
	(
		assert_bool(column.get_global_rect().intersects(_gate().get_ring_view().get_global_rect()))
		. is_false()
	)
	for button: Button in [
		_screen().get_actions().get_archive_button(), _screen().get_actions().get_close_button()
	]:
		assert_float(button.get_combined_minimum_size().x).is_less_equal(button.size.x)
	assert_float(_line().size.x).is_less_equal(strip.size.x)


## Five documents with long titles: the fixture's three, twice the dossier's.
func _five_documents() -> Array[DocumentDef]:
	var defs: Array[DocumentDef] = []
	for id: StringName in [
		ArchiveFixture.DOSSIER,
		ArchiveFixture.NOTE,
		ArchiveFixture.RUBBING,
		ArchiveFixture.DOSSIER,
		ArchiveFixture.NOTE
	]:
		defs.append(Registry.get_def(id) as DocumentDef)
	return defs
