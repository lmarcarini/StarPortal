## Tests for the documents a lock delivers, on the wormhole screen: a first lock that delivers
## documents names them by title and offers Read in the Archive, which opens the Archive with the
## first one selected; the way back to the wormhole is the return bar, as from the Address
## Book, with Dial still disabled; a lock that delivers nothing shows no line; the gamepad
## reaches the button; the screen fits the minimum window in en and pt_BR.
## Runs the whole view switcher over the dialing fixture galaxy, with a DocumentSystem that
## delivers two fixture documents on the first lock of the open world.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## game-design.md#core-loop
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const ArchiveFixture := preload("res://tests/ui/archive_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"
## Delivered on the first lock of the open world, in id order.
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


## The gate fixture's simulation, plus a DocumentSystem: the dossier and the note arrive on the
## first lock of the open world; the Archive starts with the rubbing, read.
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
	await get_tree().process_frame


func _close_wormhole() -> void:
	_screen().get_close_button().pressed.emit()
	_screen().dismiss()
	await get_tree().process_frame


func test_a_first_lock_names_the_documents_it_delivered() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	assert_bool(_screen().is_showing_open()).is_true()
	assert_bool(_line().is_visible_in_tree()).is_true()
	assert_str(_line().text).is_equal(
		"New in the Archive: Directorate file 61-B, Field note, lintel"
	)
	var button: Button = _screen().get_archive_button()
	assert_bool(button.is_visible_in_tree()).is_true()
	assert_str(button.tr(button.text)).is_equal("Read in the Archive")
	assert_str(_switcher.get_tab_bar().get_tab_title(1)).is_equal("Archive (2)")


## Read in the Archive opens the Archive with the first new document selected and read; the
## Gate Room keeps the wormhole aside, and its return bar brings the wormhole back.
func test_read_in_the_archive_and_back_to_the_wormhole() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	_screen().get_archive_button().pressed.emit()
	await get_tree().process_frame
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	assert_str(String(_archive().get_reader().get_document_id())).is_equal("doc_dossier")
	assert_object(_focus_owner()).is_same(_archive().get_default_focus())
	assert_str(_switcher.get_tab_bar().get_tab_title(1)).is_equal("Archive (1)")
	assert_bool(_screen().is_away()).is_true()
	_switcher.show_view(ViewSwitcher.GATE_ROOM)
	await get_tree().process_frame
	var back: Button = _screen().get_return_button()
	assert_bool(back.is_visible_in_tree()).is_true()
	assert_object(_focus_owner()).is_same(back)
	assert_bool(_dial_button().disabled).is_true()
	back.pressed.emit()
	await get_tree().process_frame
	assert_bool(_screen().is_showing_open()).is_true()
	assert_object(_focus_owner()).is_same(_screen().get_close_button())
	assert_bool(_dial_button().disabled).is_true()


## Locking the same world again delivers nothing new: no line, no button. A first lock of a
## world with no documents shows none either.
func test_a_lock_that_delivers_nothing_shows_no_line() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	await _close_wormhole()
	await _dial(DialOutcome.Kind.LOCK)
	assert_bool(_screen().is_showing_open()).is_true()
	assert_bool(_line().visible).is_false()
	assert_bool(_screen().get_archive_button().visible).is_false()
	await _close_wormhole()
	await _dial(DialOutcome.Kind.HOSTILE_LOCK)
	assert_bool(_screen().is_showing_open()).is_true()
	assert_bool(_line().visible).is_false()
	assert_bool(_screen().get_archive_button().visible).is_false()


func test_the_gamepad_reaches_read_in_the_archive() -> void:
	await _dial(DialOutcome.Kind.LOCK)
	assert_object(_focus_owner()).is_same(_screen().get_close_button())
	await ArchiveFixture.pad(JOY_BUTTON_DPAD_UP)
	assert_object(_focus_owner()).is_same(_screen().get_archive_button())
	await ArchiveFixture.pad(JOY_BUTTON_A)
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	assert_str(String(_archive().get_reader().get_document_id())).is_equal("doc_dossier")


@warning_ignore("unused_parameter")
func test_the_screen_with_new_documents_fits_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	await _dial(DialOutcome.Kind.LOCK)
	await get_tree().process_frame
	var panel: Control = _screen().get_node("Center/Panel") as Control
	var needed: Vector2 = panel.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(Fixture.VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(Fixture.VIEW_SIZE.y)
	var button: Button = _screen().get_archive_button()
	assert_float(button.get_combined_minimum_size().x).is_less_equal(button.size.x)
	assert_float(_line().size.x).is_less_equal(panel.size.x)
