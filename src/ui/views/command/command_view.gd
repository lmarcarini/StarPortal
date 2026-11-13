class_name CommandView
extends GameView
## The Command tab (F6; docs/content/m27-daily-rhythm.md section 4), available from the start:
## the [CommandBoard] (funds, money lines, trend, recent causes, warnings) on the left and the
## [CommandPanel] (Committee summary, or a money line's breakdown) on the right. (A), Enter or
## a click on a money line opens its breakdown; (B) or Esc closes it. Reads state only, and
## rereads it on every money, Confidence, staff and room event, on each settlement, on
## showing and on a locale change, so it stays right while paused. Sub-tabs at the top switch
## between this Overview and Requests (m4-core-systems.md section 4); the tab title gains
## "(!)" while an offer has not been seen in Requests.
## Bible: docs/content/m27-daily-rhythm.md section 4

var _simulation: Simulation = null
## Index of the money line whose breakdown is shown, or -1.
var _breakdown: int = -1
## Highest request uid seen in the Requests sub-tab.
var _seen_uid: int = -1
var _subtabs := HBoxContainer.new()
var _overview_button := Button.new()
var _requests_button := Button.new()
var _requests := RequestsPanel.new()

@onready var _board: CommandBoard = %Board
@onready var _panel: CommandPanel = %Panel


func _ready() -> void:
	_board.line_activated.connect(open_breakdown)
	visibility_changed.connect(_on_visibility_changed)
	_subtabs.position = Vector2(16, 8)
	for button: Button in [_overview_button, _requests_button]:
		button.toggle_mode = true
		_subtabs.add_child(button)
	_overview_button.text = &"COMMAND_SUBTAB_OVERVIEW"
	_requests_button.text = &"COMMAND_SUBTAB_REQUESTS"
	_overview_button.pressed.connect(show_requests.bind(false))
	_requests_button.pressed.connect(show_requests.bind(true))
	add_child(_subtabs)
	_requests.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_requests.offset_left = 16.0
	_requests.offset_top = 52.0
	_requests.offset_right = -16.0
	_requests.offset_bottom = -8.0
	add_child(_requests)
	show_requests(false)


func _enter_tree() -> void:
	_connect_events(true)


func _exit_tree() -> void:
	_connect_events(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads [param simulation]'s money and Committee.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_breakdown = -1
	_seen_uid = -1
	_requests.setup(simulation)
	refresh()


func get_default_focus() -> Control:
	var rows: Array[CommandRow] = _board.line_rows()
	return rows[0] if not rows.is_empty() else self


func get_title_key() -> StringName:
	return &"COMMAND_TITLE"


## The title, with "(!)" while an offer is new.
func get_tab_title() -> String:
	var title: String = tr(get_title_key())
	if has_new_offer():
		return tr(&"COMMAND_TITLE_NEW").format({"title": title})
	return title


## True while an offered request has not been seen in Requests.
func has_new_offer() -> bool:
	if _simulation == null:
		return false
	for record: RequestRecord in _simulation.state.requests.items:
		if record.state == RequestRecord.RequestState.OFFERED and record.uid > _seen_uid:
			return true
	return false


## Shows the Requests sub-tab ([param on]) or the Overview.
func show_requests(on: bool) -> void:
	(get_node(^"Columns") as Control).visible = not on
	_requests.visible = on
	_overview_button.button_pressed = not on
	_requests_button.button_pressed = on
	if on:
		_mark_seen()
		_requests.refresh()


## Returns the Requests panel.
func get_requests() -> RequestsPanel:
	return _requests


## Returns the Requests sub-tab button.
func get_requests_button() -> Button:
	return _requests_button


func _mark_seen() -> void:
	if _simulation == null:
		return
	for record: RequestRecord in _simulation.state.requests.items:
		_seen_uid = maxi(_seen_uid, record.uid)
	title_changed.emit()


## Returns the board, for tests.
func get_board() -> CommandBoard:
	return _board


## Returns the side panel, for tests.
func get_panel() -> CommandPanel:
	return _panel


## Rereads everything from the simulation; a shown breakdown stays while its line does.
func refresh() -> void:
	if _simulation == null or not is_node_ready():
		return
	_board.show_state(_simulation.state)
	if _breakdown >= _board.lines().size():
		_breakdown = -1
	if _breakdown < 0:
		_panel.show_summary(_simulation.state)
	else:
		_show_breakdown()


## Shows the breakdown of money line [param index] in the side panel.
func open_breakdown(index: int) -> void:
	if _simulation == null or index < 0 or index >= _board.lines().size():
		return
	_breakdown = index
	_show_breakdown()


## Closes the breakdown, back to the Committee summary, and focuses its line.
func close_breakdown() -> void:
	var index: int = _breakdown
	_breakdown = -1
	refresh()
	var rows: Array[CommandRow] = _board.line_rows()
	if index >= 0 and index < rows.size():
		rows[index].grab_focus()


func _show_breakdown() -> void:
	var state: GameState = _simulation.state
	var line: CommandLine = _board.lines()[_breakdown]
	_panel.show_breakdown(CommandText.line_name(state, line), CommandText.breakdown(state, line))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _breakdown < 0:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_breakdown()
		get_viewport().set_input_as_handled()


func _connect_events(on: bool) -> void:
	var signals: Array[Signal] = [
		EventBus.budget_changed,
		EventBus.confidence_changed,
		EventBus.day_started,
		EventBus.committee_commendation,
		EventBus.committee_warning,
		EventBus.staff_changed,
		EventBus.staff_arrived,
		EventBus.room_built,
		EventBus.room_demolished,
		EventBus.power_allocation_changed,
		EventBus.research_done,
		EventBus.request_offered,
		EventBus.request_changed,
	]
	for event: Signal in signals:
		if on:
			event.connect(_on_event)
		else:
			event.disconnect(_on_event)


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	title_changed.emit()
	if is_visible_in_tree():
		refresh()
		if _requests.visible:
			_requests.refresh()


## Events are skipped while the tab is hidden, so showing it rereads everything.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
