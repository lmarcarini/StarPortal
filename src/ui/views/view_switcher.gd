class_name ViewSwitcher
extends Control
## Hosts the game views and shows one at a time, grouped into four stations (M4.10-03): Gate,
## Base (with Personnel's roster), Lab (Research) and Office (Command, Archive and Personnel's
## hiring); the station keys on the frame pick a station (F1-F4, Q/E cycle) and the tab bar
## shows only the current station's folders. Each child of %Views is a
## [GameView]; its id is its node name in snake_case ([code]GateRoom[/code] is
## [code]&"gate_room"[/code]) and its tab follows child order. The station actions
## (view_next E and view_previous Q wrap over the stations; view_gate_room F1, view_base F2,
## view_research F3 for the Lab, view_office F4) and the gamepad shoulders switch stations;
## the tabs switch folders. Each tab has a code-drawn icon (TabIcon), lit
## orange on the current tab, and a dot while its view needs attention
## ([method GameView.needs_attention]). A view that is not available
## ([method GameView.is_available]: the Research tab before a lab finishes) has its tab
## hidden, is skipped by view_next and view_previous, and its action does nothing.
## Hidden views stay in the tree and keep their own state, but are invisible, do not process
## and cannot take focus or the mouse. Only the view root's own process, focus and mouse modes
## are changed, and showing the view restores the values it had before it was hidden;
## descendants inherit and keep their own settings.
## The Archive's tab counts its unread documents ("Archive (2)"), as the Archive view
## reports them. When the Gate station asks to build the first Capacitor Bank, it opens the
## Base with the bank's ghost placed.
## When the World Report asks to plan an expedition, it opens the Gate's mission sheet on it.
## The switcher holds no game state: it passes the simulation down and forgets it.
## Bible: game-design.md#core-loop, technical-architecture.md#signals-and-scenes,
## technical-architecture.md#input-accessibility-and-localisation,
## docs/content/interface-pass.md section 4

## Emitted with the id of the view just shown: once for the first view when the switcher is
## ready, then each time another view replaces it.
signal view_changed(view_id: StringName)
## The station on screen changed (or its attention or availability did).
signal stations_changed

## Id of the Gate Room view.
const GATE_ROOM: StringName = &"gate_room"
## Id of the Archive view.
const ARCHIVE: StringName = &"archive"
## Id of the Base view.
const BASE: StringName = &"base"
## Id of the Research view.
const RESEARCH: StringName = &"research"
## Id of the Personnel view.
const PERSONNEL: StringName = &"personnel"
## Id of the Command view.
const COMMAND: StringName = &"command"

## The four stations (M4.10-03) and the views each hosts as folders, first the default.
## Personnel is the Base's roster and the Office's hiring folder.
const STATIONS: Dictionary[StringName, Array] = {
	&"gate": [GATE_ROOM],
	&"base": [BASE],
	&"lab": [RESEARCH],
	&"office": [COMMAND, ARCHIVE, PERSONNEL],
}
## Station order for the keys and Q/E.
const STATION_ORDER: Array[StringName] = [&"gate", &"base", &"lab", &"office"]

## Added to a tab's title while its view needs attention.
const ATTENTION_DOT: String = " •"

const _ACTION_NEXT: StringName = &"view_next"
const _ACTION_PREVIOUS: StringName = &"view_previous"
## Actions that open one station, as {action: station id}: F1-F4.
const _DIRECT_ACTIONS: Dictionary = {
	&"view_gate_room": &"gate",
	&"view_base": &"base",
	&"view_research": &"lab",
	&"view_office": &"office",
}

var _ids: Array[StringName] = []
var _views: Dictionary[StringName, GameView] = {}
var _current: StringName = &""
## The root modes each hidden view had before the switcher hid it, as
## {view id: [process_mode, focus_behavior_recursive, mouse_behavior_recursive]}.
var _saved_modes: Dictionary[StringName, Array] = {}
var _station: StringName = &"gate"
var _last_folder: Dictionary[StringName, StringName] = {}

@onready var _tabs: TabBar = %Tabs
@onready var _views_root: Control = %Views


func _ready() -> void:
	_collect_views()
	for _id: StringName in _ids:
		_tabs.add_tab()
	_refresh_titles()
	_refresh_availability()
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
	_refresh_availability()


## Shows the view [param view_id] ([constant GATE_ROOM], [constant ARCHIVE],
## [constant BASE]), hides the others and gives focus to its default control. An unknown id
## warns and changes nothing.
func show_view(view_id: StringName) -> void:
	if not _views.has(view_id):
		push_warning("ViewSwitcher: unknown view %s" % view_id)
		return
	if not _views[view_id].is_available():
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


## Shows station [param station]: the folder last open there, else its first available one.
func show_station(station: StringName) -> void:
	var folder: StringName = folder_of(station)
	if folder.is_empty():
		return
	_station = station
	show_view(folder)


## The station on screen.
func current_station() -> StringName:
	return _station


## The view station [param station] opens on: its last folder, else its first available; &""
## when none is available (the Lab before a Research Lab exists).
func folder_of(station: StringName) -> StringName:
	var last: StringName = _last_folder.get(station, &"")
	if not last.is_empty() and _views.has(last) and _views[last].is_available():
		return last
	for id: StringName in STATIONS.get(station, []):
		if _views.has(id) and _views[id].is_available():
			return id
	return &""


## True when station [param station] has an available view.
func is_station_available(station: StringName) -> bool:
	return not folder_of(station).is_empty()


## True when a view of station [param station] needs attention (GameView.needs_attention).
func station_needs_attention(station: StringName) -> bool:
	for id: StringName in STATIONS.get(station, []):
		if _views.has(id) and _views[id].is_available() and _views[id].needs_attention():
			return true
	return false


## The station hosting [param view_id]: the current one when it does, else the first.
func station_of(view_id: StringName) -> StringName:
	var here: Array = STATIONS.get(_station, [])
	if here.has(view_id):
		return _station
	for station: StringName in STATION_ORDER:
		var folders: Array = STATIONS[station]
		if folders.has(view_id):
			return station
	return _station


## Returns the tab bar (the current station's folders), the entry point for focus navigation.
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
		view.availability_changed.connect(_refresh_availability)
		view.title_changed.connect(_refresh_titles)


## Listens to the requests of the views that make any: the Archive's unread count and plan
## requests, Personnel's show on plan and the Gate station's capacitor bank.
func _connect_view(view: GameView) -> void:
	if view is ArchiveView:
		(view as ArchiveView).unread_changed.connect(_refresh_titles)
		(view as ArchiveView).plan_requested.connect(ViewRequests.plan.bind(self))
		(view as ArchiveView).team_report_requested.connect(ViewRequests.team_report.bind(self))
	elif view is PersonnelView:
		(view as PersonnelView).show_on_plan.connect(ViewRequests.show_on_plan.bind(self))
	elif view is GateStationView:
		(view as GateStationView).capacitor_bank_requested.connect(
			ViewRequests.capacitor_bank.bind(self)
		)
		(view as GateStationView).report_opened.connect(show_view.bind(GATE_ROOM))


## Shows [param view_id] and hides the others, without moving focus.
func _activate(view_id: StringName) -> void:
	if view_id == _current:
		return
	_current = view_id
	_station = station_of(view_id)
	_last_folder[_station] = view_id
	for id: StringName in _ids:
		_set_active(id, id == view_id)
	var view: GameView = _views[view_id]
	_tabs.focus_neighbor_bottom = _tabs.get_path_to(view.get_default_focus())
	_refresh_availability()
	_tabs.current_tab = _ids.find(view_id)
	_refresh_titles()
	view_changed.emit(view_id)
	stations_changed.emit()


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
			var station: StringName = _DIRECT_ACTIONS[action]
			return _enter(station)
	return &""


## The folder of station [param station], made current; &"" when it has none available.
func _enter(station: StringName) -> StringName:
	var folder: StringName = folder_of(station)
	if not folder.is_empty():
		_station = station
	return folder


## The folder of the station [param offset] away from the current one, wrapping and skipping
## unavailable stations.
func _neighbour(offset: int) -> StringName:
	var index: int = STATION_ORDER.find(_station)
	for _step: int in STATION_ORDER.size():
		index = posmod(index + offset, STATION_ORDER.size())
		if is_station_available(STATION_ORDER[index]):
			break
	return _enter(STATION_ORDER[index])


## Hides the tab of every view that is not available; leaves a view that stops being
## available for the first available one.
func _refresh_availability() -> void:
	var folders: Array = STATIONS.get(_station, [])
	for index: int in _ids.size():
		var shown: bool = _views[_ids[index]].is_available() and folders.has(_ids[index])
		_tabs.set_tab_hidden(index, not shown)
	if _views.has(_current) and not _views[_current].is_available():
		_activate(_ids[0])
	stations_changed.emit()


## Sets each tab's title, with the dot while its view needs attention, and its icon.
func _refresh_titles() -> void:
	var scale: float = Settings.get_float(&"display", &"ui_scale")
	for index: int in _ids.size():
		var view: GameView = _views[_ids[index]]
		var title: String = view.get_tab_title()
		if view.needs_attention():
			title += ATTENTION_DOT
		_tabs.set_tab_title(index, title)
		var color: Color = UiPalette.SELECT if _ids[index] == _current else UiPalette.TEXT_DIM
		_tabs.set_tab_icon(index, TabIcon.texture(_ids[index], scale, color))


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
