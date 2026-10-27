## Tests for the Log's batched rows: a full log builds only the first batch, scrolling builds
## more, and the filter and the search still count and find every entry, built or not.
## Bible: game-design.md#core-loop (Archive: the operations log)
extends GdUnitTestSuite

const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const VIEW_SCENE: String = "res://src/ui/views/archive/archive_view.tscn"

var _holder: Control = null
var _log: LogList = null
var _simulation: Simulation = null


func before_test() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build_new(GameState.new_game(7, defs.balance), defs).value
	var entries: LogState = _simulation.state.operations_log
	for index: int in LogState.CAP:
		var kind: StringName = &"power" if index == 5 else &"document"
		entries.add(LogEntry.create(index, kind, &"", {"document_id": "doc_lintel_dossier"}))
	_holder = Control.new()
	_holder.size = Vector2(1280, 600)
	_holder.add_child((load(VIEW_SCENE) as PackedScene).instantiate())
	add_child(_holder)
	var view: ArchiveView = _holder.get_child(0) as ArchiveView
	view.setup(_simulation)
	view.show_section(true)
	_log = view.get_log_list()
	await UiInput.settle(view)


func after_test() -> void:
	if is_instance_valid(_holder):
		_holder.free()


func test_full_log_builds_one_batch() -> void:
	assert_int(_log.get_rows().size()).is_equal(LogList.BATCH)
	assert_int(_log.get_shown_count()).is_equal(LogState.CAP)
	assert_int(_log.get_rows()[0].get_entry().tick).is_equal(LogState.CAP - 1)


func test_scrolling_to_the_end_builds_more() -> void:
	var scroll: ScrollContainer = _log.get_node("Scroll")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	bar.value = bar.max_value
	await UiInput.settle(_log)
	assert_int(_log.get_rows().size()).is_equal(2 * LogList.BATCH)
	var ticks: Array[int] = []
	for row: ArchiveLogRow in _log.get_rows():
		ticks.append(row.get_entry().tick)
	var sorted: Array[int] = ticks.duplicate()
	sorted.sort()
	sorted.reverse()
	assert_array(ticks).is_equal(sorted)


func test_filter_finds_an_entry_not_built_yet() -> void:
	_log.set_kind_filter(&"power")
	assert_int(_log.get_shown_count()).is_equal(1)
	assert_int(_log.get_visible_rows().size()).is_equal(1)
	assert_int(_log.get_visible_rows()[0].get_entry().tick).is_equal(5)
	assert_str(_log.get_empty_text()).is_empty()


func test_search_counts_every_entry() -> void:
	_log.set_search("no such text")
	assert_int(_log.get_shown_count()).is_equal(0)
	assert_str(_log.get_empty_text()).is_not_empty()
	_log.set_search("")
	assert_int(_log.get_shown_count()).is_equal(LogState.CAP)
	assert_int(_log.get_visible_rows().size()).is_equal(LogState.CAP)
