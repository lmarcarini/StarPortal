class_name LogList
extends VBoxContainer
## The Archive's operations log: every entry newest first, filtered by kind and by a text
## search, with how many show or why none do. Rows are made in batches, newest first: the first
## [constant BATCH] at once, more as the list scrolls near its end or while a filter shows too
## few; new entries are added at the top. Filtering hides rows and counts every entry, built or
## not. The D-pad path is section tabs, kind filter, search, rows and back. Reads state only.
## Bible: game-design.md#core-loop (Archive: the operations log)

## Kind filter value that shows every kind.
const ANY_KIND: StringName = &""
## Bus events after which the log may hold new entries, with their argument counts.
const _LOGGED_EVENTS: Dictionary[StringName, int] = {
	&"dial_resolved": 2,
	&"wormhole_closed": 1,
	&"document_received": 1,
	&"console_read": 1,
	&"horizon_record_taken": 1,
	&"capacitors_installed": 1,
	&"month_report_filed": 2,
	&"committee_warning": 1,
}

## Rows built at once, and the most built per scroll step.
const BATCH: int = 100
## Pixels from the end of the scroll at which the next batch is built.
const _NEAR_END: float = 200.0

const _ROW_SCENE: PackedScene = preload("res://src/ui/archive/log_row.tscn")

var _simulation: Simulation = null
## Rows, newest first, one per log entry.
var _rows: Array[ArchiveLogRow] = []
var _kind: StringName = ANY_KIND
var _query: String = ""
var _sync_queued: bool = false
## The bus handler connected for each logged event.
var _handlers: Dictionary[StringName, Callable] = {}
## Lower-case search text of each entry, in the current locale.
var _search_texts: Dictionary[LogEntry, String] = {}
## Entries matching the filter and the search, built or not.
var _shown: int = 0

@onready var _filter: OptionButton = %KindFilter
@onready var _search: LineEdit = %Search
@onready var _count: Label = %CountLabel
@onready var _rows_box: VBoxContainer = %Rows
@onready var _empty: Label = %EmptyLabel
@onready var _scroll: ScrollContainer = $Scroll


func _ready() -> void:
	_fill_filter_choices()
	_filter.item_selected.connect(_on_filter_selected)
	_search.text_changed.connect(set_search)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled.unbind(1))
	_filter.focus_neighbor_right = _filter.get_path_to(_search)
	_filter.focus_neighbor_left = _filter.get_path_to(_filter)
	_search.focus_neighbor_left = _search.get_path_to(_filter)
	_search.focus_neighbor_right = _search.get_path_to(_search)
	_rebuild()


func _enter_tree() -> void:
	for event_name: StringName in _LOGGED_EVENTS:
		_handlers[event_name] = _queue_sync.unbind(_LOGGED_EVENTS[event_name])
		EventBus.connect(event_name, _handlers[event_name])


func _exit_tree() -> void:
	for event_name: StringName in _handlers:
		EventBus.disconnect(event_name, _handlers[event_name])
	_handlers.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_filter_choices()
		_search_texts.clear()
		_search.placeholder_text = tr(&"LOG_SEARCH")
		_apply_filter()


## Connects the list to [param simulation] and builds the rows from its log; the filter and the
## search are cleared.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_kind = ANY_KIND
	_query = ""
	if is_node_ready():
		_filter.select(0)
		_search.text = ""
		_rebuild()


## Up from the kind filter and the search goes to [param above] (the section tabs).
func link_up(above: Control) -> void:
	_filter.focus_neighbor_top = _filter.get_path_to(above)
	_search.focus_neighbor_top = _search.get_path_to(above)


## Builds up to [constant BATCH] more rows, older than those built; false when none were left.
func build_more() -> bool:
	if _simulation == null:
		return false
	var entries: Array[LogEntry] = _simulation.state.operations_log.entries
	var next: int = entries.size() - 1 - _rows.size()
	if next < 0:
		return false
	for index: int in range(next, maxi(next - BATCH, -1), -1):
		var row: ArchiveLogRow = _make_row(entries[index])
		_rows_box.add_child(row)
		_rows.push_back(row)
		row.visible = row.matches(_kind, _query)
	_link_rows()
	return true


## Returns how many entries the filter and the search show, built or not.
func get_shown_count() -> int:
	return _shown


## Adds rows for the entries logged since the last sync, at the top; rebuilds when the log was
## replaced.
func sync() -> void:
	_sync_queued = false
	if _simulation == null or not is_node_ready():
		return
	var entries: Array[LogEntry] = _simulation.state.operations_log.entries
	var newest: LogEntry = null if _rows.is_empty() else _rows[0].get_entry()
	var start: int = 0
	if newest != null:
		start = entries.rfind(newest) + 1
		if start == 0:
			_rebuild()
			return
	for index: int in range(start, entries.size()):
		_add_row(entries[index])
	while _rows.size() > entries.size():
		var oldest: ArchiveLogRow = _rows.pop_back()
		_rows_box.remove_child(oldest)
		oldest.queue_free()
	_apply_filter()


## Shows only entries of [param kind] (a LogEntry kind), or every kind for [constant ANY_KIND].
func set_kind_filter(kind: StringName) -> void:
	_kind = kind if LogEntry.KINDS.has(kind) else ANY_KIND
	_filter.select(LogEntry.KINDS.find(_kind) + 1)
	_apply_filter()


## Shows only entries whose text contains [param text], ignoring case.
func set_search(text: String) -> void:
	_query = text.strip_edges().to_lower()
	if _search.text != text:
		_search.text = text
	_apply_filter()


## Returns the rows, newest first, shown or not.
func get_rows() -> Array[ArchiveLogRow]:
	return _rows


## Returns the rows shown, newest first.
func get_visible_rows() -> Array[ArchiveLogRow]:
	var shown: Array[ArchiveLogRow] = []
	shown.assign(_rows.filter(func(row: ArchiveLogRow) -> bool: return row.visible))
	return shown


## Returns the "N entries" line.
func get_count_text() -> String:
	return _count.text


## Returns the message shown when no row is, or "" while rows show.
func get_empty_text() -> String:
	return _empty.text if _empty.visible else ""


## Returns the kind filter's drop-down.
func get_filter_button() -> OptionButton:
	return _filter


## Returns the search field.
func get_search_field() -> LineEdit:
	return _search


## Returns the first row shown, else the kind filter.
func get_first_focus() -> Control:
	for row: ArchiveLogRow in _rows:
		if row.visible:
			return row
	return _filter


func _rebuild() -> void:
	for row: ArchiveLogRow in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	_search.placeholder_text = tr(&"LOG_SEARCH")
	_search_texts.clear()
	if _simulation != null:
		build_more()
	_apply_filter()


func _make_row(entry: LogEntry) -> ArchiveLogRow:
	var row: ArchiveLogRow = _ROW_SCENE.instantiate() as ArchiveLogRow
	row.setup(entry, _simulation.state)
	return row


func _add_row(entry: LogEntry) -> void:
	var row: ArchiveLogRow = _make_row(entry)
	_rows_box.add_child(row)
	_rows_box.move_child(row, 0)
	_rows.push_front(row)


## Hides rows that don't match, counts every matching entry, and builds more while fewer than
## a batch of built rows show.
func _apply_filter() -> void:
	var visible_rows: int = 0
	for row: ArchiveLogRow in _rows:
		row.visible = row.matches(_kind, _query)
		visible_rows += 1 if row.visible else 0
	while visible_rows < BATCH and build_more():
		visible_rows = get_visible_rows().size()
	_shown = _count_matches()
	var count_key: StringName = &"LOG_COUNT_ONE" if _shown == 1 else &"LOG_COUNT"
	_count.text = tr(count_key).format({"count": _shown})
	_empty.visible = _shown == 0
	_empty.text = tr(&"LOG_EMPTY") if _rows.is_empty() else tr(&"LOG_EMPTY_FILTERED")
	_link_rows()


func _count_matches() -> int:
	if _simulation == null:
		return 0
	var count: int = 0
	for entry: LogEntry in _simulation.state.operations_log.entries:
		if not _kind.is_empty() and entry.kind != _kind:
			continue
		if not _query.is_empty():
			if not _search_texts.has(entry):
				var text: String = ArchiveLogRow.search_text(entry, _simulation.state)
				_search_texts[entry] = text.to_lower()
			if not _search_texts[entry].contains(_query):
				continue
		count += 1
	return count


## Down from the filter and the search reaches the first row shown, whose Up returns to the
## search; with no row shown they stay put.
func _link_rows() -> void:
	var first: Control = null
	for row: ArchiveLogRow in _rows:
		row.focus_neighbor_top = NodePath()
		if first == null and row.visible:
			first = row
	if first == null:
		_filter.focus_neighbor_bottom = _filter.get_path_to(_filter)
		_search.focus_neighbor_bottom = _search.get_path_to(_search)
		return
	first.focus_neighbor_top = first.get_path_to(_search)
	_filter.focus_neighbor_bottom = _filter.get_path_to(first)
	_search.focus_neighbor_bottom = _search.get_path_to(first)


func _on_scrolled() -> void:
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	if bar.value + bar.page >= bar.max_value - _NEAR_END:
		build_more()


func _fill_filter_choices() -> void:
	var chosen: int = maxi(_filter.selected, 0)
	_filter.clear()
	_filter.add_item(tr(&"LOG_FILTER_ALL"))
	for key: StringName in ArchiveLogRow.KIND_KEYS:
		_filter.add_item(tr(key))
	_filter.select(chosen)


func _on_filter_selected(index: int) -> void:
	set_kind_filter(LogEntry.KINDS[index - 1] if index > 0 else ANY_KIND)


func _queue_sync() -> void:
	if not _sync_queued:
		_sync_queued = true
		sync.call_deferred()
