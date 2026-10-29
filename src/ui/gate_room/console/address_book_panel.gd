class_name AddressBookPanel
extends VBoxContainer
## The Address Book, in the Gate Room's side panel (AddressBookDrawer): every address the player has
## found or dialed, newest first, as rows of large glyphs. The filters sit in a collapsible header
## (Filters), closed by default; they filter by glyphs (a compact 36-glyph palette; an entry must
## hold every picked glyph), by text in the note or the world's name, and by source. It says how
## many addresses match, or why none show. Selecting a row and pressing Load asks the console to
## fill its slots (the drawer then collapses); the selected entry's note is edited below the list
## and saved with a NoteAddressCommand. The panel never changes state itself.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## game-design.md#difficulty-and-accessibility

## The player pressed Load on a selected entry: fill the slots with [param address].
signal load_requested(address: GateAddress)

const _ROW_SCENE: PackedScene = preload("res://src/ui/gate_room/console/address_book_row.tscn")

var _simulation: Simulation = null
var _filter: AddressBookFilter = AddressBookFilter.new()
var _rows: Array[AddressBookRow] = []
## Address key of the selected entry, or "" for none.
var _selected: String = ""
## Address key whose note the note field holds, so a rebuild keeps a note being typed.
var _note_key: String = ""

@onready var _filters_button: Button = %FiltersButton
@onready var _filter_box: Control = %FilterBox
@onready var _search: LineEdit = %SearchEdit
@onready var _source: OptionButton = %SourceFilter
@onready var _glyphs: GlyphFilter = %GlyphFilter
@onready var _count: Label = %CountLabel
@onready var _clear_filters: Button = %ClearFiltersButton
@onready var _rows_box: VBoxContainer = %Rows
@onready var _empty: Label = %EmptyLabel
@onready var _note_edit: LineEdit = %NoteEdit
@onready var _save_note: Button = %SaveNoteButton
@onready var _load: Button = %LoadButton


func _ready() -> void:
	_note_edit.max_length = AddressEntry.MAX_NOTE_LENGTH
	_fill_source_choices()
	_filters_button.toggled.connect(show_filters)
	_search.text_changed.connect(_on_search_changed)
	_source.item_selected.connect(_on_source_selected)
	_glyphs.glyph_toggled.connect(_on_glyph_toggled)
	_clear_filters.pressed.connect(clear_filters)
	_save_note.pressed.connect(save_note)
	_note_edit.text_submitted.connect(func(_text: String) -> void: save_note())
	_load.pressed.connect(load_selected)
	_rebuild()


func _enter_tree() -> void:
	EventBus.address_book_changed.connect(_on_book_changed)


func _exit_tree() -> void:
	EventBus.address_book_changed.disconnect(_on_book_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_source_choices()
		_rebuild()


## Connects the panel to [param simulation]; the filter and the selection are dropped.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_filter.clear()
	_selected = ""
	_note_key = "-"
	if is_node_ready():
		_search.text = ""
		_source.select(0)
		_rebuild()


## Shows the filters (glyphs, text, source) when [param shown], hides them otherwise.
func show_filters(shown: bool) -> void:
	_filters_button.set_pressed_no_signal(shown)
	_filter_box.visible = shown


## True while the filters show.
func are_filters_shown() -> bool:
	return _filter_box.visible


## Returns the filter, for tests.
func get_filter() -> AddressBookFilter:
	return _filter


## Returns the rows shown, newest first.
func get_rows() -> Array[AddressBookRow]:
	return _rows


## Returns the "N addresses" line.
func get_count_text() -> String:
	return _count.text


## Returns the message shown when no row is, or "" while rows show.
func get_empty_text() -> String:
	return _empty.text if _empty.visible else ""


## Selects the entry of [param address_key] ("" for none) and shows its note for editing.
func select(address_key: String) -> void:
	_selected = address_key
	_render_selection()


## Returns the selected entry's address key, or "".
func get_selected() -> String:
	return _selected


## Adds or removes [param glyph] in the glyph filter.
func toggle_glyph(glyph: int) -> void:
	_filter.toggle_glyph(glyph)
	_rebuild()


## Drops every filter.
func clear_filters() -> void:
	_filter.clear()
	_search.text = ""
	_source.select(0)
	_rebuild()


## Asks the console to load the selected entry's address. Does nothing with no selection.
func load_selected() -> void:
	if _selected.is_empty():
		return
	load_requested.emit(AddressBookRow.address_of(_selected))


## Saves the note field as the selected entry's note (a NoteAddressCommand).
func save_note() -> void:
	if _simulation == null or _selected.is_empty():
		return
	_simulation.submit(NoteAddressCommand.create(_selected, _note_edit.text))


## Returns the first row, the panel's focus target; with no row, the search field when the
## filters show, else the Filters button.
func get_first_focus() -> Control:
	if not _rows.is_empty():
		return _rows[0]
	return _search if _filter_box.visible else _filters_button


func _fill_source_choices() -> void:
	var chosen: int = maxi(_source.selected, 0)
	_source.clear()
	for key: StringName in AddressBookText.SOURCE_FILTER_KEYS:
		_source.add_item(tr(key))
	_source.select(chosen)


func _rebuild() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var refocus: String = ""
	if focused is AddressBookRow:
		refocus = (focused as AddressBookRow).get_address_key()
	_build_rows()
	var count_key: StringName = &"BOOK_COUNT_ONE" if _rows.size() == 1 else &"BOOK_COUNT"
	_count.text = tr(count_key).format({"count": _rows.size()})
	_clear_filters.disabled = _filter.is_empty()
	_glyphs.show_picked(_filter.glyphs, tr)
	_render_empty()
	_render_selection()
	if not refocus.is_empty():
		_focus_row(refocus)


func _build_rows() -> void:
	for row: AddressBookRow in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	var entries: Array[AddressEntry] = []
	if _simulation != null:
		entries = _filter.apply(_simulation.state.address_book, _simulation.state)
	for entry: AddressEntry in entries:
		var row: AddressBookRow = _ROW_SCENE.instantiate() as AddressBookRow
		row.setup(entry, _simulation.state)
		row.chosen.connect(select)
		_rows_box.add_child(row)
		_rows.append(row)


## Gives focus back to the row of [param address_key] after a rebuild, or to the first focus.
func _focus_row(address_key: String) -> void:
	for row: AddressBookRow in _rows:
		if row.get_address_key() == address_key:
			row.grab_focus()
			return
	get_first_focus().grab_focus()


func _render_empty() -> void:
	_empty.visible = _rows.is_empty()
	if _simulation == null or _simulation.state.address_book.entries.is_empty():
		_empty.text = tr(&"BOOK_EMPTY")
	else:
		_empty.text = tr(&"BOOK_EMPTY_FILTERED")


func _render_selection() -> void:
	var entry: AddressEntry = null
	if _simulation != null and not _selected.is_empty():
		entry = _simulation.state.address_book.find(_selected)
	if entry == null:
		_selected = ""
	for row: AddressBookRow in _rows:
		row.set_selected(row.get_address_key() == _selected)
	_note_edit.editable = entry != null
	if _note_key != _selected:
		_note_key = _selected
		_note_edit.text = entry.note if entry != null else ""
	_save_note.disabled = entry == null
	_load.disabled = entry == null


func _on_search_changed(text: String) -> void:
	_filter.text = text
	_rebuild()


func _on_source_selected(index: int) -> void:
	_filter.source = index - 1 if index > 0 else AddressBookFilter.ANY_SOURCE
	_rebuild()


func _on_glyph_toggled(glyph: int) -> void:
	toggle_glyph(glyph)


func _on_book_changed() -> void:
	if is_node_ready():
		_rebuild()
