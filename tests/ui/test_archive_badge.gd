## Tests for the Archive tab's unread count: a new game's tab counts its start documents,
## reading one lowers the count (also when the read applies with the next tick), a document
## that arrives raises it, 0 shows no number, and the count follows the language.
## Bible: game-design.md#core-loop,
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const ArchiveFixture := preload("res://tests/ui/archive_fixture.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

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
	_simulation = ArchiveFixture.simulation()
	SimClock.start(_simulation)
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	_switcher = (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
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


func _archive() -> ArchiveView:
	return _switcher.get_view(ViewSwitcher.ARCHIVE) as ArchiveView


func _title() -> String:
	return _switcher.get_tab_bar().get_tab_title(5)


func test_a_new_game_counts_its_start_documents() -> void:
	assert_str(_title()).is_equal("Archive (2)")
	assert_int(_archive().get_unread_count()).is_equal(2)


func test_reading_lowers_the_count_and_zero_shows_no_number() -> void:
	_archive().open_document(ArchiveFixture.NOTE)
	assert_str(_title()).is_equal("Archive (1)")
	_archive().open_document(ArchiveFixture.RUBBING)
	assert_str(_title()).is_equal("Archive")
	_archive().open_document(ArchiveFixture.NOTE)
	assert_str(_title()).is_equal("Archive")


## While the clock runs, the read command applies with the next tick: the count follows then.
func test_a_read_queued_while_running_lowers_the_count_on_the_next_tick() -> void:
	SimClock.resume()
	_archive().open_document(ArchiveFixture.NOTE)
	assert_str(_title()).is_equal("Archive (2)")
	SimClock.step_ticks(1)
	assert_str(_title()).is_equal("Archive (1)")


func test_an_arriving_document_raises_the_count() -> void:
	_simulation.submit(DeliverDocumentCommand.create(ArchiveFixture.DOSSIER))
	assert_str(_title()).is_equal("Archive (3)")


func test_the_count_follows_the_language() -> void:
	TranslationServer.set_locale("pt_BR")
	await get_tree().process_frame
	assert_str(_title()).is_equal("Arquivo (2)")


## The count is read from the bound simulation: a load with all read shows no number.
func test_setup_reads_the_new_simulations_archive() -> void:
	var loaded: Simulation = ArchiveFixture.simulation()
	for id: StringName in loaded.state.archive.received:
		loaded.state.archive.read[id] = true
	SimClock.start(loaded)
	_switcher.setup(loaded)
	assert_str(_title()).is_equal("Archive")
