class_name ArchiveView
extends GameView
## The Archive view, in three sections: Documents, Worlds (WorldsSection: every known world
## and its World Report) and the operations Log (LogList). Documents:
## every document the player holds in a list beside a reader. Opening a
## document reads it (a MarkDocumentReadCommand clears its unread mark); its image opens large
## in the image viewer; "Read with…" opens a second document beside the first, offering the
## document's pair first, so a note and a rubbing can be read together. The view only composes
## the parts and submits the read command; nothing here changes state.
## The tab title counts the unread documents, read from the Archive in the state.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#the-opening-puzzle,
## technical-architecture.md#input-accessibility-and-localisation,
## docs/content/m3-beyond-the-ring.md section 7 (World Report)

## The number of unread documents may have changed (a document arrived or was read, or a new
## simulation was bound); [method get_tab_title] has the new title.
signal unread_changed
## The World Report's **Plan expedition** was pressed, for [param world_id].
signal plan_requested(world_id: StringName)

const _TITLE_KEY: StringName = &"ARCHIVE_TITLE"
const _TITLE_UNREAD_KEY: StringName = &"ARCHIVE_TITLE_UNREAD"
## Section tab title keys, in tab order.
const _SECTION_KEYS: Array[StringName] = [
	&"ARCHIVE_SECTION_DOCUMENTS", &"ARCHIVE_SECTION_WORLDS", &"ARCHIVE_SECTION_LOG"
]
## Section tab indices.
const _DOCUMENTS_TAB: int = 0
const _WORLDS_TAB: int = 1
const _LOG_TAB: int = 2

var _simulation: Simulation = null
## Documents offered by the open "Read with…" menu, by item index.
var _menu_ids: Array[StringName] = []
## The control that opened the image viewer, given focus back when it closes.
var _image_return: Control = null
## A read command was queued while the clock ran: it applies with the next tick, after which
## the unread count changes.
var _unread_on_tick: bool = false

@onready var _sections: TabContainer = %Sections
@onready var _columns: Control = %Columns
@onready var _log: LogList = %LogList
@onready var _worlds: WorldsSection = %Worlds
@onready var _list: DocumentList = %DocumentList
@onready var _primary: DocumentReader = %PrimaryReader
@onready var _secondary: DocumentReader = %SecondaryReader
@onready var _viewer: ImageViewer = %ImageViewer
@onready var _menu: PopupMenu = %ReadWithMenu


func _ready() -> void:
	for index: int in _SECTION_KEYS.size():
		_sections.set_tab_title(index, _SECTION_KEYS[index])
	_secondary.set_secondary(true)
	_secondary.hide()
	_list.document_chosen.connect(open_document)
	_primary.read_with_pressed.connect(open_read_with_menu)
	_secondary.close_pressed.connect(close_beside)
	_primary.image_requested.connect(_on_image_requested.bind(_primary))
	_secondary.image_requested.connect(_on_image_requested.bind(_secondary))
	_viewer.closed.connect(_on_viewer_closed)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	_sections.tab_changed.connect(_link_sections.unbind(1))
	_log.link_up(_sections.get_tab_bar())
	_worlds.link_up(_sections.get_tab_bar())
	_worlds.plan_requested.connect(
		func(world_id: StringName) -> void: plan_requested.emit(world_id)
	)
	_link_sections()
	_link_filter()


func _enter_tree() -> void:
	EventBus.document_received.connect(_on_document_received)
	EventBus.tick_advanced.connect(_on_tick_advanced)


func _exit_tree() -> void:
	EventBus.document_received.disconnect(_on_document_received)
	EventBus.tick_advanced.disconnect(_on_tick_advanced)


## Connects the view to [param simulation]: the list is rebuilt from its Archive, and the
## readers and the image viewer are closed.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_unread_on_tick = false
	_list.setup(simulation)
	_log.setup(simulation)
	_worlds.setup(simulation)
	_viewer.close()
	_menu.hide()
	close_beside()
	_primary.clear()
	_link_filter()
	unread_changed.emit()


## Opens document [param document_id] in the first reader and marks it read. A document not in
## the Archive is ignored.
func open_document(document_id: StringName) -> void:
	if not _holds(document_id):
		return
	show_section(false)
	_show_in(_primary, document_id)
	_list.set_selected(document_id)
	if _secondary.get_document_id() == document_id:
		close_beside()
	_update_read_with()


## Opens document [param document_id] in a second reader beside the first and marks it read.
func open_beside(document_id: StringName) -> void:
	if not _holds(document_id) or document_id == _primary.get_document_id():
		return
	_show_in(_secondary, document_id)
	_secondary.show()
	_secondary.get_default_focus().grab_focus()


## Closes the second reader, giving focus back to the first when the second had it.
func close_beside() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_focus: bool = focused != null and _secondary.is_ancestor_of(focused)
	_secondary.hide()
	_secondary.clear()
	if had_focus:
		_primary.get_default_focus().grab_focus()


## Lists the documents to read beside the first one, its pair first, and focuses the first.
func open_read_with_menu() -> void:
	_menu_ids = _read_with_ids()
	if _menu_ids.is_empty():
		return
	_menu.clear()
	var def: DocumentDef = _def_of(_primary.get_document_id())
	var pair_id: StringName = def.pair_id if def != null else &""
	for index: int in _menu_ids.size():
		var title: String = DocumentText.title(_def_of(_menu_ids[index]))
		if _menu_ids[index] == pair_id:
			title = tr(&"ARCHIVE_READ_WITH_PAIR").format({"title": title})
		_menu.add_item(title, index)
	var button: Button = _primary.get_read_with_button()
	var corner: Vector2 = button.get_screen_position() + Vector2(0, button.size.y)
	_menu.popup(Rect2i(Vector2i(corner), Vector2i.ZERO))
	_menu.set_focused_item(0)


## Shows the Documents section ([param show_log] false) or the Log.
func show_section(show_log: bool) -> void:
	_sections.current_tab = _LOG_TAB if show_log else _DOCUMENTS_TAB


## Shows the Worlds section.
func show_worlds() -> void:
	_sections.current_tab = _WORLDS_TAB


## Returns the Worlds section.
func get_worlds() -> WorldsSection:
	return _worlds


## Returns the operations log list.
func get_log_list() -> LogList:
	return _log


## Returns the document list.
func get_list() -> DocumentList:
	return _list


## Returns the first reader ([param secondary] false) or the second.
func get_reader(secondary: bool = false) -> DocumentReader:
	return _secondary if secondary else _primary


## Returns the image viewer.
func get_image_viewer() -> ImageViewer:
	return _viewer


## Returns the "Read with…" menu.
func get_read_with_menu() -> PopupMenu:
	return _menu


## In Documents, the selected document's row, else the first row, else the kind filter; in
## Worlds, the open world's row, else the first, else the section tabs; in the Log, its first
## row shown, else its kind filter.
func get_default_focus() -> Control:
	if _sections.current_tab == _LOG_TAB:
		return _log.get_first_focus()
	if _sections.current_tab == _WORLDS_TAB:
		var row: Control = _worlds.get_first_focus()
		return row if row != null else _sections.get_tab_bar()
	return _list.get_first_focus()


## Returns [code]ARCHIVE_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY


## Returns the number of documents in the Archive not read yet; 0 before setup.
func get_unread_count() -> int:
	if _simulation == null:
		return 0
	var archive: ArchiveState = _simulation.state.archive
	return (
		archive.received.filter(func(id: StringName) -> bool: return not archive.is_read(id)).size()
	)


## Returns the translated tab title: "Archive (2)" with unread documents, "Archive" with none.
func get_tab_title() -> String:
	var count: int = get_unread_count()
	if count == 0:
		return tr(_TITLE_KEY)
	return tr(_TITLE_UNREAD_KEY).format({"count": count})


func _holds(document_id: StringName) -> bool:
	return _simulation != null and _simulation.state.archive.has_document(document_id)


func _def_of(document_id: StringName) -> DocumentDef:
	return Registry.get_def(document_id) as DocumentDef


## Shows [param document_id] in [param reader] and submits its read command when unread.
func _show_in(reader: DocumentReader, document_id: StringName) -> void:
	var archive: ArchiveState = _simulation.state.archive
	var tick: int = archive.received_tick.get(document_id, 0)
	reader.show_document(document_id, _def_of(document_id), tick)
	if archive.is_read(document_id):
		return
	if not _simulation.submit(MarkDocumentReadCommand.create(document_id)).is_ok:
		return
	_list.mark_read(document_id)
	_unread_on_tick = _unread_on_tick or not archive.is_read(document_id)
	unread_changed.emit()


func _read_with_ids() -> Array[StringName]:
	var shown: StringName = _primary.get_document_id()
	if _simulation == null or shown.is_empty():
		return []
	var def: DocumentDef = _def_of(shown)
	var pair_id: StringName = def.pair_id if def != null else &""
	return DocumentText.read_with_order(shown, pair_id, _simulation.state.archive.received)


func _update_read_with() -> void:
	_primary.set_read_with_enabled(not _read_with_ids().is_empty())
	_link_filter()


## Right from the kind filter goes into the open document, else stays put: the nearest
## control to its right is otherwise the view tab bar above it.
func _link_filter() -> void:
	var filter: OptionButton = _list.get_filter_button()
	var target: Control = filter
	if not _primary.get_document_id().is_empty():
		target = _primary.get_default_focus()
	filter.focus_neighbor_right = filter.get_path_to(target)


## In the Log, Down from the section tabs goes to its kind filter; in Worlds, to the open or
## first world; in Documents, the nearest.
func _link_sections() -> void:
	var tabs: TabBar = _sections.get_tab_bar()
	var down: NodePath = NodePath()
	if _sections.current_tab == _LOG_TAB:
		down = tabs.get_path_to(_log.get_filter_button())
	elif _sections.current_tab == _WORLDS_TAB and _worlds.get_first_focus() != null:
		down = tabs.get_path_to(_worlds.get_first_focus())
	tabs.focus_neighbor_bottom = down


func _on_menu_id_pressed(index: int) -> void:
	if index >= 0 and index < _menu_ids.size():
		open_beside(_menu_ids[index])


func _on_image_requested(texture: Texture2D, reader: DocumentReader) -> void:
	_image_return = reader.get_image_button()
	_columns.focus_behavior_recursive = FOCUS_BEHAVIOR_DISABLED
	_viewer.open(texture)


## The list and readers under the viewer take focus again; the image's button gets it back.
func _on_viewer_closed() -> void:
	_columns.focus_behavior_recursive = FOCUS_BEHAVIOR_INHERITED
	if is_instance_valid(_image_return) and _image_return.is_visible_in_tree():
		_image_return.grab_focus()
	_image_return = null


func _on_document_received(_document_id: StringName) -> void:
	_update_read_with()
	unread_changed.emit()


func _on_tick_advanced(_tick: int) -> void:
	if _unread_on_tick:
		_unread_on_tick = false
		unread_changed.emit()
