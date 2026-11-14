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

## Sub-tabs.
## Sub-tab ids for [method show_sub_tab].
const FINANCES_ID: StringName = &"finances"
const FACTIONS_ID: StringName = &"factions"
const REQUESTS_ID: StringName = &"requests"
const OVERVIEW: int = 0
const REQUESTS: int = 1
const FACTIONS: int = 2

var _simulation: Simulation = null
## Index of the money line whose breakdown is shown, or -1.
var _breakdown: int = -1
## Highest request uid seen in the Requests sub-tab.
var _seen_uid: int = -1
var _overview_button := Button.new()
var _requests_button := Button.new()
var _requests := RequestsPanel.new()
var _factions_button := Button.new()
var _factions := FactionsPanel.new()

@onready var _board: CommandBoard = %Board
@onready var _panel: CommandPanel = %Panel
@onready var _columns: ThreeColumn = %Columns


func _ready() -> void:
	_board.line_activated.connect(open_breakdown)
	visibility_changed.connect(_on_visibility_changed)
	var stack := VBoxContainer.new()
	stack.name = &"SubTabs"
	for button: Button in [_overview_button, _factions_button, _requests_button]:
		button.toggle_mode = true
		button.theme_type_variation = &"KeyButton"
		stack.add_child(button)
	_overview_button.text = &"COMMAND_SUBTAB_FINANCES"
	_requests_button.text = &"COMMAND_SUBTAB_REQUESTS"
	_factions_button.text = &"COMMAND_SUBTAB_FACTIONS"
	_overview_button.pressed.connect(show_subtab.bind(OVERVIEW))
	_requests_button.pressed.connect(show_subtab.bind(REQUESTS))
	_factions_button.pressed.connect(show_subtab.bind(FACTIONS))
	_columns.put_left([stack] as Array[Control])
	for panel: Control in [_requests, _factions]:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_columns.add_child(panel)
		_columns.move_child(panel, _board.get_index() + 1)
	show_subtab(OVERVIEW)


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
	_factions.setup(simulation)
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
	show_subtab(REQUESTS if on else OVERVIEW)


## Shows the sub-tab [param id]: finances, factions or requests (the top bar's funds and
## Confidence open Finances; a request alert opens Requests).
func show_sub_tab(id: StringName) -> void:
	match id:
		FACTIONS_ID:
			show_subtab(FACTIONS)
		REQUESTS_ID:
			show_subtab(REQUESTS)
		_:
			show_subtab(OVERVIEW)


## Shows sub-tab [param index]: OVERVIEW (Finances), REQUESTS or FACTIONS.
func show_subtab(index: int) -> void:
	_board.visible = index == OVERVIEW
	_panel.visible = index == OVERVIEW
	_requests.visible = index == REQUESTS
	_factions.visible = index == FACTIONS
	_overview_button.button_pressed = index == OVERVIEW
	_requests_button.button_pressed = index == REQUESTS
	_factions_button.button_pressed = index == FACTIONS
	if index == REQUESTS:
		_mark_seen()
		_requests.refresh()
	elif index == FACTIONS:
		_factions.refresh()


## Returns the Factions panel.
func get_factions() -> FactionsPanel:
	return _factions


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
		EventBus.standing_changed,
		EventBus.faction_met,
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
		if _factions.visible:
			_factions.refresh()


## Events are skipped while the tab is hidden, so showing it rereads everything.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
