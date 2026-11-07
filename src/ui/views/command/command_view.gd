class_name CommandView
extends GameView
## The Command tab (F6; docs/content/m27-daily-rhythm.md section 4), available from the start:
## the [CommandBoard] (funds, money lines, trend, recent causes, warnings) on the left and the
## [CommandPanel] (Committee summary, or a money line's breakdown) on the right. (A), Enter or
## a click on a money line opens its breakdown; (B) or Esc closes it. Reads state only, and
## rereads it on every money, Confidence, staff and room event, on each settlement, on
## showing and on a locale change, so it stays right while paused.
## Bible: docs/content/m27-daily-rhythm.md section 4

var _simulation: Simulation = null
## Index of the money line whose breakdown is shown, or -1.
var _breakdown: int = -1

@onready var _board: CommandBoard = %Board
@onready var _panel: CommandPanel = %Panel


func _ready() -> void:
	_board.line_activated.connect(open_breakdown)
	visibility_changed.connect(_on_visibility_changed)


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
	refresh()


func get_default_focus() -> Control:
	var rows: Array[CommandRow] = _board.line_rows()
	return rows[0] if not rows.is_empty() else self


func get_title_key() -> StringName:
	return &"COMMAND_TITLE"


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
	]
	for event: Signal in signals:
		if on:
			event.connect(_on_event)
		else:
			event.disconnect(_on_event)


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	if is_visible_in_tree():
		refresh()


## Events are skipped while the tab is hidden, so showing it rereads everything.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
