## Tests for the Archive view: the list is built from the Archive state at setup, newest first,
## and a late document_received never lists a document twice; a new document arrives unread;
## opening one reads it (MarkDocumentReadCommand) and the read survives a save and load; the
## kind filter; the reader's title, source, date and body; "Read with…" offers the pair first and
## opens it beside; and the Archive never shows the world a document is about.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#the-opening-puzzle
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/archive_fixture.gd")
const GateFixture := preload("res://tests/ui/gate_room_fixture.gd")
const SaveServiceScript := preload("res://src/services/save_service.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: ArchiveView = null
var _translation: Translation = null
var _real_locale: String = ""
var _saves: SaveServiceScript = null


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_translation = Fixture.translation()
	TranslationServer.add_translation(_translation)
	assert_array(Fixture.load_content()).is_empty()
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)
	await get_tree().process_frame


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	if _saves != null:
		_remove_saves()
	TranslationServer.remove_translation(_translation)
	TranslationServer.set_locale(_real_locale)
	Fixture.restore()


func _ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for row: DocumentRow in _view.get_list().get_rows():
		ids.append(row.get_document_id())
	return ids


func _row(document_id: StringName) -> DocumentRow:
	for row: DocumentRow in _view.get_list().get_rows():
		if row.get_document_id() == document_id:
			return row
	return null


func _remove_saves() -> void:
	var dir := DirAccess.open(_saves.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(_saves.saves_dir.path_join(file_name))
		DirAccess.remove_absolute(_saves.saves_dir)
	_saves.free()
	_saves = null


## The start documents are in the state at setup: listed newest first, unread, with a count.
func test_list_is_built_from_the_archive_at_setup() -> void:
	assert_array(_ids()).is_equal([Fixture.RUBBING, Fixture.NOTE])
	assert_bool(_row(Fixture.NOTE).is_unread()).is_true()
	assert_bool(_row(Fixture.RUBBING).is_unread()).is_true()
	assert_str(_view.get_list().get_count_text()).is_equal("2 documents")
	assert_str(_row(Fixture.NOTE).get_title_text()).is_equal("Field note, lintel")
	assert_str(_row(Fixture.RUBBING).tooltip_text).is_equal("Image")


## The start documents' document_received events come out with the first tick, after setup:
## the list refreshes from the state and shows each document once.
func test_late_start_events_do_not_duplicate_rows() -> void:
	var received: Array[StringName] = []
	var on_received: Callable = func(id: StringName) -> void: received.append(id)
	EventBus.document_received.connect(on_received)
	SimClock.step_ticks(1)
	EventBus.document_received.disconnect(on_received)
	assert_array(received).is_equal([Fixture.NOTE, Fixture.RUBBING])
	assert_array(_ids()).is_equal([Fixture.RUBBING, Fixture.NOTE])


## A document delivered later appears at the top with the unread mark.
func test_a_new_document_appears_unread_on_top() -> void:
	_simulation.submit(DeliverDocumentCommand.create(Fixture.DOSSIER))
	await get_tree().process_frame
	assert_array(_ids()).is_equal([Fixture.DOSSIER, Fixture.RUBBING, Fixture.NOTE])
	assert_bool(_row(Fixture.DOSSIER).is_unread()).is_true()
	assert_str(_view.get_list().get_count_text()).is_equal("3 documents")


## Opening a document shows its title, source, arrival date and body, and reads it.
func test_opening_a_document_reads_it() -> void:
	_view.open_document(Fixture.NOTE)
	var reader: DocumentReader = _view.get_reader()
	assert_str(String(reader.get_document_id())).is_equal("doc_note")
	var texts: Array[String] = reader.get_shown_texts()
	assert_str(texts[0]).is_equal("Field note, lintel")
	assert_str(texts[1]).is_equal("Source: Survey team, 1958")
	assert_str(texts[2]).is_equal("Received 2026-01-01 00:00")
	assert_str(texts[3]).is_equal("The bird first.\n\nThen the one that holds fire, then water.")
	assert_bool(reader.get_image_button().visible).is_false()
	assert_bool(_simulation.state.archive.is_read(Fixture.NOTE)).is_true()
	assert_bool(_row(Fixture.NOTE).is_unread()).is_false()
	assert_bool(_row(Fixture.NOTE).button_pressed).is_true()
	assert_bool(_row(Fixture.RUBBING).is_unread()).is_true()


## While the clock runs, the read command applies on the next tick; the mark clears at once.
func test_reading_while_running_clears_the_mark() -> void:
	SimClock.simulation.state.clock.is_paused = false
	_view.open_document(Fixture.RUBBING)
	assert_bool(_row(Fixture.RUBBING).is_unread()).is_false()
	SimClock.step_ticks(1)
	assert_bool(_simulation.state.archive.is_read(Fixture.RUBBING)).is_true()


## A read document stays read after a save and a load; the unread one stays unread.
func test_read_mark_survives_save_and_load() -> void:
	_view.open_document(Fixture.NOTE)
	_saves = SaveServiceScript.new()
	_saves.saves_dir = "user://test_archive_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	assert_bool(_saves.save_game(_simulation.state, &"archive").is_ok).is_true()
	var loaded: Result = _saves.load_game(&"archive")
	assert_bool(loaded.is_ok).override_failure_message(str(loaded.detail)).is_true()
	var state: GameState = loaded.value
	var simulation := Simulation.new(state)
	SimClock.start(simulation)
	_view.setup(simulation)
	assert_array(_ids()).is_equal([Fixture.RUBBING, Fixture.NOTE])
	assert_bool(_row(Fixture.NOTE).is_unread()).is_false()
	assert_bool(_row(Fixture.RUBBING).is_unread()).is_true()
	assert_str(String(_view.get_reader().get_document_id())).is_empty()


## The kind filter shows only documents of that kind, or says none are.
func test_kind_filter() -> void:
	var list: DocumentList = _view.get_list()
	list.set_kind_filter(DocumentDef.Kind.IMAGE)
	assert_array(_ids()).is_equal([Fixture.RUBBING])
	assert_str(list.get_count_text()).is_equal("1 document")
	list.set_kind_filter(DocumentDef.Kind.DOSSIER)
	assert_array(_ids()).is_empty()
	assert_str(list.get_empty_text()).is_equal("No document of this kind.")
	list.set_kind_filter(DocumentList.ANY_KIND)
	assert_int(_ids().size()).is_equal(2)


## "Read with…" offers the pair first, marked, and opens it in a second reader.
func test_read_with_offers_the_pair_first() -> void:
	_simulation.submit(DeliverDocumentCommand.create(Fixture.DOSSIER))
	_view.open_document(Fixture.NOTE)
	assert_bool(_view.get_reader().get_read_with_button().disabled).is_false()
	_view.open_read_with_menu()
	var menu: PopupMenu = _view.get_read_with_menu()
	assert_int(menu.item_count).is_equal(2)
	assert_str(menu.get_item_text(0)).is_equal("Rubbing of the lintel (read together)")
	assert_str(menu.get_item_text(1)).is_equal("Directorate file 61-B")
	menu.id_pressed.emit(menu.get_item_id(0))
	var beside: DocumentReader = _view.get_reader(true)
	assert_bool(beside.visible).is_true()
	assert_str(String(beside.get_document_id())).is_equal("doc_rubbing")
	assert_bool(beside.get_image_button().visible).is_true()
	assert_bool(_simulation.state.archive.is_read(Fixture.RUBBING)).is_true()
	_view.close_beside()
	assert_bool(beside.visible).is_false()


## With one document held there is nothing to read beside it.
func test_read_with_needs_another_document() -> void:
	_simulation.state.archive.received.assign([Fixture.NOTE])
	_view.setup(_simulation)
	_view.open_document(Fixture.NOTE)
	assert_bool(_view.get_reader().get_read_with_button().disabled).is_true()


## A document's world, its name and its answer are never shown.
func test_never_shows_the_world_or_the_answer() -> void:
	_view.open_document(Fixture.NOTE)
	_view.open_beside(Fixture.RUBBING)
	await get_tree().process_frame
	var texts: Array[String] = GateFixture.visible_texts(_view)
	texts.append_array(_view.get_reader().get_shown_texts())
	texts.append_array(_view.get_reader(true).get_shown_texts())
	for text: String in texts:
		assert_str(text).not_contains(Fixture.WORLD_NAME)
		assert_str(text).not_contains("13")


## A document id the Archive does not hold opens nothing.
func test_unknown_document_is_ignored() -> void:
	_view.open_document(Fixture.DOSSIER)
	assert_str(String(_view.get_reader().get_document_id())).is_empty()
	assert_bool(_simulation.state.archive.read.is_empty()).is_true()
