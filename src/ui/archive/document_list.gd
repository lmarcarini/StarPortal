class_name DocumentList
extends VBoxContainer
## The Archive's list: every document the player holds, newest first, filtered by kind, with
## how many show or why none do. It is always rebuilt from the Archive state, never appended
## to, so a document_received for a document already listed (the start documents, which are
## in the state at setup but announced on the next tick) never shows it twice. Pressing a row
## asks the view to open that document.
## Bible: game-design.md#core-loop

## The player pressed the row of [param document_id].
signal document_chosen(document_id: StringName)

## Kind filter value that shows every kind.
const ANY_KIND: int = -1

const _ROW_SCENE: PackedScene = preload("res://src/ui/archive/document_row.tscn")

var _simulation: Simulation = null
var _rows: Array[DocumentRow] = []
var _kind: int = ANY_KIND
var _selected: StringName = &""

@onready var _filter: OptionButton = %KindFilter
@onready var _count: Label = %CountLabel
@onready var _rows_box: VBoxContainer = %Rows
@onready var _empty: Label = %EmptyLabel


func _ready() -> void:
	_fill_filter_choices()
	_filter.item_selected.connect(func(index: int) -> void: set_kind_filter(index - 1))
	refresh()


func _enter_tree() -> void:
	EventBus.document_received.connect(_on_document_received)


func _exit_tree() -> void:
	EventBus.document_received.disconnect(_on_document_received)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_filter_choices()
		refresh()


## Connects the list to [param simulation] and builds it from the Archive state; the filter
## and the selection are dropped.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_kind = ANY_KIND
	_selected = &""
	if is_node_ready():
		_filter.select(0)
		refresh()


## Rebuilds the rows from the Archive state, keeping focus on the focused document's row.
func refresh() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var refocus: StringName = &""
	if focused is DocumentRow and is_ancestor_of(focused):
		refocus = (focused as DocumentRow).get_document_id()
	_build_rows()
	var count_key: StringName = &"ARCHIVE_COUNT_ONE" if _rows.size() == 1 else &"ARCHIVE_COUNT"
	_count.text = tr(count_key).format({"count": _rows.size()})
	_render_empty()
	set_selected(_selected)
	if not refocus.is_empty():
		_focus_row(refocus)


## Shows only documents of [param kind] (a DocumentDef.Kind), or every kind for
## [constant ANY_KIND].
func set_kind_filter(kind: int) -> void:
	_kind = kind if kind >= 0 and kind < DocumentText.KIND_KEYS.size() else ANY_KIND
	_filter.select(_kind + 1)
	refresh()


## Returns the kind filter, [constant ANY_KIND] for every kind.
func get_kind_filter() -> int:
	return _kind


## Shows the row of [param document_id] pressed and the others not.
func set_selected(document_id: StringName) -> void:
	_selected = document_id
	for row: DocumentRow in _rows:
		row.set_pressed_no_signal(row.get_document_id() == document_id)


## Updates every row's unread mark from the Archive state.
func refresh_marks() -> void:
	if _simulation == null:
		return
	for row: DocumentRow in _rows:
		row.set_unread(not _simulation.state.archive.is_read(row.get_document_id()))


## Hides the unread mark of [param document_id] (its read command was accepted).
func mark_read(document_id: StringName) -> void:
	for row: DocumentRow in _rows:
		if row.get_document_id() == document_id:
			row.set_unread(false)


## Returns the rows shown, newest first.
func get_rows() -> Array[DocumentRow]:
	return _rows


## Returns the "N documents" line.
func get_count_text() -> String:
	return _count.text


## Returns the message shown when no row is, or "" while rows show.
func get_empty_text() -> String:
	return _empty.text if _empty.visible else ""


## Returns the kind filter's drop-down.
func get_filter_button() -> OptionButton:
	return _filter


## Returns the selected row, else the first row, else the kind filter.
func get_first_focus() -> Control:
	for row: DocumentRow in _rows:
		if row.get_document_id() == _selected:
			return row
	return _filter if _rows.is_empty() else _rows[0]


func _fill_filter_choices() -> void:
	var chosen: int = maxi(_filter.selected, 0)
	_filter.clear()
	_filter.add_item(tr(&"ARCHIVE_FILTER_ALL"))
	for key: StringName in DocumentText.KIND_KEYS:
		_filter.add_item(tr(key))
	_filter.select(chosen)


func _build_rows() -> void:
	for row: DocumentRow in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	if _simulation == null:
		return
	var archive: ArchiveState = _simulation.state.archive
	for document_id: StringName in DocumentText.newest_first(archive.received):
		var def: DocumentDef = Registry.get_def(document_id) as DocumentDef
		var kind: int = def.kind if def != null else DocumentDef.Kind.NOTE
		if _kind != ANY_KIND and kind != _kind:
			continue
		var row: DocumentRow = _ROW_SCENE.instantiate() as DocumentRow
		row.setup(document_id, def, not archive.is_read(document_id))
		row.chosen.connect(func(id: StringName) -> void: document_chosen.emit(id))
		_rows_box.add_child(row)
		_rows.append(row)


func _focus_row(document_id: StringName) -> void:
	for row: DocumentRow in _rows:
		if row.get_document_id() == document_id:
			row.grab_focus()
			return
	get_first_focus().grab_focus()


func _render_empty() -> void:
	_empty.visible = _rows.is_empty()
	var none_held: bool = _simulation == null or _simulation.state.archive.received.is_empty()
	_empty.text = tr(&"ARCHIVE_EMPTY") if none_held else tr(&"ARCHIVE_EMPTY_FILTERED")


func _on_document_received(_document_id: StringName) -> void:
	if is_node_ready():
		refresh()
