class_name AlertList
extends PanelContainer
## The top bar's alert list: a drop-down under the alerts button, newest first. Each row has
## a status lamp (shape and colour by severity) and the alert's line; choosing it emits
## [signal alert_chosen]; event-style rows have a dismiss key. Opening it never pauses the
## game. Alerts come from AlertRules, plus site_finished from this session's room_built
## events (no Log entry exists for it, so it does not survive a load). Dismissed alerts are
## remembered for the session only.
## Bible: docs/content/interface-pass.md section 3 (Alerts)

## The player chose [param entry].
signal alert_chosen(entry: AlertEntry)
## The alerts changed: count or worst severity may differ.
signal changed

var _state: GameState = null
var _rescue: RescueAlert = null
var _entries: Array[AlertEntry] = []
var _dismissed: Dictionary[String, bool] = {}
var _sites: Array[AlertEntry] = []
var _rows := VBoxContainer.new()


func _init() -> void:
	name = &"AlertList"
	theme_type_variation = &"PanelBezel"
	visible = false
	custom_minimum_size = Vector2(420, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 280)
	add_child(scroll)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.room_built.connect(_on_room_built)
	EventBus.game_loaded.connect(_on_loaded)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick)
	EventBus.room_built.disconnect(_on_room_built)
	EventBus.game_loaded.disconnect(_on_loaded)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads alerts from [param state] (after a start or a load).
func bind(state: GameState) -> void:
	if state != _state:
		_sites.clear()
	_state = state
	refresh()


## Adds the rescue window of [param alert] to the list while it is open.
func set_rescue(alert: RescueAlert) -> void:
	_rescue = alert
	if not alert.changed.is_connected(refresh):
		alert.changed.connect(refresh)
	refresh()


## The alerts shown now, newest first.
func entries() -> Array[AlertEntry]:
	return _entries.duplicate()


## Shows or hides the list; showing it focuses its first row.
func toggle() -> void:
	visible = not visible
	if visible:
		refresh()
		var first: Control = first_row()
		if first != null:
			first.grab_focus()


## The first row's choose button, or null when there are no alerts.
func first_row() -> Button:
	for row: Node in _rows.get_children():
		var button := row.get_child(0) as Button
		if button != null:
			return button
	return null


## Hides [param entry] for the rest of the session (event-style alerts only).
func dismiss(entry: AlertEntry) -> void:
	if not entry.dismissible:
		return
	_dismissed[entry.key()] = true
	refresh()


## Rebuilds the alerts from the state and redraws the rows.
func refresh() -> void:
	if _state == null:
		return
	var found: Array[AlertEntry] = AlertRules.current(_state)
	var since: int = _state.clock.tick - AlertRules.EVENT_TICKS
	for site: AlertEntry in _sites:
		if site.tick >= since:
			found.append(site)
	if _rescue != null and _rescue.is_window_open():
		var rescue := AlertEntry.create(
			&"rescue", AlertEntry.ALARM, ViewSwitcher.GATE_ROOM, _state.clock.tick
		)
		rescue.args = {"line": _rescue.stack_entry()}
		found.append(rescue)
	_entries = []
	for entry: AlertEntry in found:
		if not _dismissed.has(entry.key()):
			_entries.append(entry)
	AlertRules.sort_newest_first(_entries)
	if visible:
		_draw_rows()
	changed.emit()


func _draw_rows() -> void:
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = &"ALERT_NONE"
		empty.theme_type_variation = &"StencilLabel"
		_rows.add_child(empty)
		return
	for entry: AlertEntry in _entries:
		_rows.add_child(_row(entry))


func _row(entry: AlertEntry) -> HBoxContainer:
	var row := HBoxContainer.new()
	var choose := Button.new()
	choose.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	choose.text = AlertText.line(entry, _state)
	choose.icon = StatusLamp.icon(AlertText.lamp_status(entry.severity), 14)
	choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose.pressed.connect(_choose.bind(entry))
	row.add_child(choose)
	if entry.dismissible:
		var dismiss_button := Button.new()
		dismiss_button.text = &"ALERT_DISMISS"
		dismiss_button.pressed.connect(dismiss.bind(entry))
		row.add_child(dismiss_button)
	return row


func _choose(entry: AlertEntry) -> void:
	visible = false
	alert_chosen.emit(entry)


func _on_tick(_tick: int) -> void:
	if _state != null and (_state.clock.tick % 60 == 0 or visible):
		refresh()


func _on_room_built(site_id: StringName) -> void:
	if _state == null:
		return
	var entry := AlertEntry.create(
		&"site_finished", AlertEntry.INFO, ViewSwitcher.BASE, _state.clock.tick
	)
	entry.target = site_id
	entry.dismissible = true
	var room: RoomState = _state.base.find_room(site_id)
	var def: RoomDef = null if room == null else _state.room_defs.get(room.def_id)
	entry.args = {"name": "" if def == null else tr(def.name_key)}
	_sites.append(entry)
	refresh()


func _on_loaded(_slot: StringName) -> void:
	_sites.clear()
	refresh()
