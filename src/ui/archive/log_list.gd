class_name LogList
extends VBoxContainer
## The Archive's operations log: every entry newest first, filtered by kind and by a text
## search, with how many show or why none do. Rows are made once per entry and added at the top
## as the log grows; filtering only hides rows. Reads state only.
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
}

const _ROW_SCENE: PackedScene = preload("res://src/ui/archive/log_row.tscn")

var _simulation: Simulation = null
## Rows, newest first, one per log entry.
var _rows: Array[ArchiveLogRow] = []
var _kind: StringName = ANY_KIND
var _query: String = ""
var _sync_queued: bool = false
## The bus handler connected for each logged event.
var _handlers: Dictionary[StringName, Callable] = {}

@onready var _filter: OptionButton = %KindFilter
@onready var _search: LineEdit = %Search
@onready var _count: Label = %CountLabel
@onready var _rows_box: VBoxContainer = %Rows
@onready var _empty: Label = %EmptyLabel


func _ready() -> void:
	_fill_filter_choices()
	_filter.item_selected.connect(_on_filter_selected)
	_search.text_changed.connect(set_search)
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
	if _simulation == null:
		_apply_filter()
		return
	sync()


func _add_row(entry: LogEntry) -> void:
	var row: ArchiveLogRow = _ROW_SCENE.instantiate() as ArchiveLogRow
	row.setup(entry, _simulation.state)
	_rows_box.add_child(row)
	_rows_box.move_child(row, 0)
	_rows.push_front(row)


func _apply_filter() -> void:
	var shown: int = 0
	for row: ArchiveLogRow in _rows:
		row.visible = row.matches(_kind, _query)
		shown += 1 if row.visible else 0
	var count_key: StringName = &"LOG_COUNT_ONE" if shown == 1 else &"LOG_COUNT"
	_count.text = tr(count_key).format({"count": shown})
	_empty.visible = shown == 0
	_empty.text = tr(&"LOG_EMPTY") if _rows.is_empty() else tr(&"LOG_EMPTY_FILTERED")


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
