class_name ViewSwitcher
extends Control
## Hosts the game views under a tab bar and shows one at a time. Each child of %Views is a
## [GameView]; its id is its node name in snake_case ([code]GateRoom[/code] is
## [code]&"gate_room"[/code]) and its tab follows child order. The tabs, the view actions
## (view_next and view_previous wrap at the ends; view_gate_room, view_archive) and the
## gamepad shoulders switch views. Hidden views stay in the tree and keep their own state,
## but are invisible, do not process and cannot take focus or the mouse. Only the view root's
## own process, focus and mouse modes are changed, and showing the view restores the values
## it had before it was hidden; descendants inherit and keep their own settings.
## The Archive's tab counts its unread documents ("Archive (2)"), as the Archive view
## reports them. When the Gate Room asks for a document (Read in the Archive on the wormhole
## screen), the switcher opens the Archive with that document selected.
## The switcher holds no game state: it passes the simulation down and forgets it.
## Bible: game-design.md#core-loop, technical-architecture.md#signals-and-scenes,
## technical-architecture.md#input-accessibility-and-localisation

## Emitted with the id of the view just shown: once for the first view when the switcher is
## ready, then each time another view replaces it.
signal view_changed(view_id: StringName)

## Id of the Gate Room view.
const GATE_ROOM: StringName = &"gate_room"
## Id of the Archive view.
const ARCHIVE: StringName = &"archive"

const _ACTION_NEXT: StringName = &"view_next"
const _ACTION_PREVIOUS: StringName = &"view_previous"
## Actions that open one view, as {action: view id}.
const _DIRECT_ACTIONS: Dictionary = {
	&"view_gate_room": GATE_ROOM,
	&"view_archive": ARCHIVE,
}

var _ids: Array[StringName] = []
var _views: Dictionary[StringName, GameView] = {}
var _current: StringName = &""
## The root modes each hidden view had before the switcher hid it, as
## {view id: [process_mode, focus_behavior_recursive, mouse_behavior_recursive]}.
var _saved_modes: Dictionary[StringName, Array] = {}

@onready var _tabs: TabBar = %Tabs
@onready var _views_root: Control = %Views


func _ready() -> void:
	_collect_views()
	for _id: StringName in _ids:
		_tabs.add_tab()
	_refresh_titles()
	_tabs.tab_changed.connect(_on_tab_changed)
	_tabs.tab_clicked.connect(_on_tab_clicked)
	var own: NodePath = _tabs.get_path_to(_tabs)
	_tabs.focus_neighbor_left = own
	_tabs.focus_neighbor_right = own
	if not _ids.is_empty():
		_activate(_ids[0])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_titles()


func _unhandled_input(event: InputEvent) -> void:
	var target: StringName = _view_for_event(event)
	if target == &"":
		return
	show_view(target)
	get_viewport().set_input_as_handled()


## Passes [param simulation] to every view, shown or hidden. Call it whenever a new
## simulation is bound: at start and after a load.
func setup(simulation: Simulation) -> void:
	for id: StringName in _ids:
		_views[id].setup(simulation)


## Shows the view [param view_id] ([constant GATE_ROOM], [constant ARCHIVE]), hides the
## others and gives focus to its default control. An unknown id warns and changes nothing.
func show_view(view_id: StringName) -> void:
	if not _views.has(view_id):
		push_warning("ViewSwitcher: unknown view %s" % view_id)
		return
	_activate(view_id)
	_views[view_id].get_default_focus().grab_focus()


## Returns the id of the view on screen.
func current_view_id() -> StringName:
	return _current


## Returns the view ids in tab order.
func get_view_ids() -> Array[StringName]:
	return _ids.duplicate()


## Returns the view [param view_id], or null if there is none.
func get_view(view_id: StringName) -> GameView:
	return _views.get(view_id)


## Returns the tab bar, the switcher's entry point for focus navigation.
func get_tab_bar() -> TabBar:
	return _tabs


## Sends focus from the tab bar up to [param control] (ui_up).
func set_focus_above(control: Control) -> void:
	_tabs.focus_neighbor_top = _tabs.get_path_to(control)


func _collect_views() -> void:
	for child: Node in _views_root.get_children():
		var view: GameView = child as GameView
		if view == null:
			push_warning("ViewSwitcher: %s is not a GameView" % child.name)
			continue
		var id: StringName = StringName(String(child.name).to_snake_case())
		_ids.append(id)
		_views[id] = view
		_set_active(id, false)
		_connect_view(view)


## Listens to the requests of the views that make any: the Archive's unread count and the
## Gate Room's request to read a document.
func _connect_view(view: GameView) -> void:
	if view is ArchiveView:
		(view as ArchiveView).unread_changed.connect(_refresh_titles)
	elif view is GateRoomView:
		(view as GateRoomView).archive_requested.connect(_on_archive_requested)


## Shows [param view_id] and hides the others, without moving focus.
func _activate(view_id: StringName) -> void:
	if view_id == _current:
		return
	_current = view_id
	for id: StringName in _ids:
		_set_active(id, id == view_id)
	var view: GameView = _views[view_id]
	_tabs.focus_neighbor_bottom = _tabs.get_path_to(view.get_default_focus())
	_tabs.current_tab = _ids.find(view_id)
	view_changed.emit(view_id)


## Returns the view [param event] asks for, or [code]&""[/code] if it is no view action.
func _view_for_event(event: InputEvent) -> StringName:
	if _ids.is_empty():
		return &""
	if InputActions.is_new_press(event, _ACTION_NEXT):
		return _neighbour(1)
	if InputActions.is_new_press(event, _ACTION_PREVIOUS):
		return _neighbour(-1)
	for action: StringName in _DIRECT_ACTIONS:
		if InputActions.is_new_press(event, action):
			return _DIRECT_ACTIONS[action]
	return &""


## Returns the id [param offset] tabs away from the current one, wrapping at the ends.
func _neighbour(offset: int) -> StringName:
	return _ids[posmod(_ids.find(_current) + offset, _ids.size())]


func _refresh_titles() -> void:
	for index: int in _ids.size():
		var view: GameView = _views[_ids[index]]
		var archive: ArchiveView = view as ArchiveView
		var title: String = archive.get_tab_title() if archive != null else tr(view.get_title_key())
		_tabs.set_tab_title(index, title)


## Shows or hides the view [param view_id].
func _set_active(view_id: StringName, active: bool) -> void:
	if active:
		_show(_views[view_id], view_id)
	else:
		_hide(_views[view_id], view_id)


## Makes [param view] visible and restores the root modes saved when it was hidden.
func _show(view: GameView, view_id: StringName) -> void:
	view.visible = true
	if not _saved_modes.has(view_id):
		return
	var saved: Array = _saved_modes[view_id]
	_saved_modes.erase(view_id)
	view.process_mode = saved[0]
	view.focus_behavior_recursive = saved[1]
	view.mouse_behavior_recursive = saved[2]


## Hides [param view]: saves its root modes (once, while hidden), then disables processing,
## focus and the mouse for it and everything under it that inherits.
func _hide(view: GameView, view_id: StringName) -> void:
	view.visible = false
	if not _saved_modes.has(view_id):
		_saved_modes[view_id] = [
			view.process_mode, view.focus_behavior_recursive, view.mouse_behavior_recursive
		]
	view.process_mode = PROCESS_MODE_DISABLED
	view.focus_behavior_recursive = FOCUS_BEHAVIOR_DISABLED
	view.mouse_behavior_recursive = MOUSE_BEHAVIOR_DISABLED


## Keyboard or gamepad moves along the focused tab bar: the view changes but focus stays on
## the tabs, so the player can keep moving along them.
func _on_tab_changed(index: int) -> void:
	if index < 0 or index >= _ids.size() or _ids[index] == _current:
		return
	if _tabs.has_focus():
		_activate(_ids[index])
	else:
		show_view(_ids[index])


## A click on a tab opens its view and gives the view focus.
func _on_tab_clicked(index: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	show_view(_ids[index])


## Opens the Archive with [param document_id] selected and read, and focuses its row.
func _on_archive_requested(document_id: StringName) -> void:
	if not _views.has(ARCHIVE):
		return
	var archive: ArchiveView = _views[ARCHIVE] as ArchiveView
	if archive == null:
		return
	archive.open_document(document_id)
	show_view(ARCHIVE)
