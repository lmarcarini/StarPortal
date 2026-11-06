class_name PersonnelView
extends GameView
## The Personnel tab (F5; docs/content/m26-staff-and-money.md section 6), available from the
## start: the [PersonnelBoard] (header, Roster and Candidates sub-tabs, the list) on the left
## and the SELECTED [PersonnelPanel] on the right. Hire, dismiss (hold), assign and unassign
## are commands; a refusal shows on the panel. The D-pad moves along the rows; (A) or Enter on
## a person opens Assign… (on a candidate, focuses Hire); (B) or Esc backs out of Assign…;
## (Y) toggles the sub-tabs, and the gamepad shoulders switch them too (past the first or
## last they switch the main tabs). The view rereads the state on every staff, money and room
## event, on showing, and on ticks that change an arrival's hours left, so it stays right
## while paused.
## Bible: docs/content/m26-staff-and-money.md section 6

var _simulation: Simulation = null
var _signature: int = 0

@onready var _board: PersonnelBoard = %Board
@onready var _panel: PersonnelPanel = %Panel


func _ready() -> void:
	_board.row_chosen.connect(_on_chosen)
	_board.row_activated.connect(_on_activated)
	_board.page_changed.connect(_on_page_changed)
	_panel.assign_pressed.connect(assign)
	_panel.unassign_pressed.connect(unassign)
	_panel.dismiss_held.connect(dismiss)
	_panel.hire_pressed.connect(hire)
	visibility_changed.connect(_on_visibility_changed)


func _enter_tree() -> void:
	_connect_events(true)


func _exit_tree() -> void:
	_connect_events(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads [param simulation]'s staff and candidates.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_panel.show_id(simulation.state, &"")
	refresh()


func get_default_focus() -> Control:
	var rows: Array[PersonnelRow] = _board.rows()
	return rows[0] if not rows.is_empty() else _board.get_tabs()


func get_title_key() -> StringName:
	return &"STAFF_TITLE"


## Returns the board, for tests.
func get_board() -> PersonnelBoard:
	return _board


## Returns the SELECTED panel, for tests.
func get_panel() -> PersonnelPanel:
	return _panel


## Rereads the list and the panel from the simulation; keeps the selection while it stays.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	_board.show_state(state)
	var shown: StringName = _panel.get_id()
	if _board.row_of(shown) == null:
		var rows: Array[PersonnelRow] = _board.rows()
		shown = rows[0].id if not rows.is_empty() else &""
	if not _panel.is_picking() or shown != _panel.get_id():
		_panel.show_id(state, shown)
	_signature = _staff_signature(state)


## Hires [param candidate_id]; a refusal shows on the panel.
func hire(candidate_id: StringName) -> void:
	_submit(HireCommand.create(candidate_id), &"STAFF_HIRED")


## Dismisses [param person_id]; a refusal shows on the panel.
func dismiss(person_id: StringName) -> void:
	_submit(DismissCommand.create(person_id), &"STAFF_DISMISSED")


## Assigns [param person_id] to [param room_id]; a refusal shows on the panel.
func assign(person_id: StringName, room_id: StringName) -> void:
	_submit(AssignStaffCommand.create(person_id, room_id), &"")
	var row: PersonnelRow = _board.row_of(person_id)
	if row != null:
		row.grab_focus()


## Unassigns [param person_id]; a refusal shows on the panel.
func unassign(person_id: StringName) -> void:
	_submit(UnassignStaffCommand.create(person_id), &"")


func _submit(command: Command, done_key: StringName) -> void:
	if _simulation == null:
		return
	var shown: StringName = _panel.get_id()
	var result: CommandResult = _simulation.submit(command)
	_panel.show_id(_simulation.state, shown)
	refresh()
	if not result.is_ok:
		_panel.show_notice(PersonnelText.refusal(result.error_code))
	elif not done_key.is_empty():
		_panel.show_notice(tr(done_key))
	if _panel.get_id() != shown:
		get_default_focus().grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _panel.is_picking() and event.is_action_pressed(&"ui_cancel"):
		_panel.show_id(_simulation.state, _panel.get_id())
		_focus_row()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventJoypadButton:
		return
	var button := event as InputEventJoypadButton
	var toggle: bool = button.pressed and button.button_index == JOY_BUTTON_Y
	var next: bool = InputActions.is_new_press(event, &"view_next")
	var back: bool = InputActions.is_new_press(event, &"view_previous")
	var page: PersonnelBoard.Page = _board.get_page()
	if (
		toggle
		or (next and page == PersonnelBoard.Page.ROSTER)
		or (back and page == PersonnelBoard.Page.CANDIDATES)
	):
		_board.toggle_page()
		get_viewport().set_input_as_handled()
		get_default_focus().grab_focus()


func _focus_row() -> void:
	var row: PersonnelRow = _board.row_of(_panel.get_id())
	(row if row != null else get_default_focus()).grab_focus()


func _on_chosen(id: StringName) -> void:
	if _simulation != null and id != _panel.get_id():
		_panel.show_id(_simulation.state, id)


func _on_activated(id: StringName) -> void:
	if _simulation == null:
		return
	_on_chosen(id)
	if _simulation.state.staff.find_person(id) != null:
		_panel.open_rooms()
		return
	var hire_button: Button = _panel.buttons()[3]
	if hire_button.visible and not hire_button.disabled:
		hire_button.grab_focus()


func _on_page_changed(_page: PersonnelBoard.Page) -> void:
	if _simulation != null:
		_panel.show_id(_simulation.state, &"")
		refresh()


func _connect_events(on: bool) -> void:
	var signals: Array[Signal] = [
		EventBus.staff_changed,
		EventBus.staff_arrived,
		EventBus.candidates_changed,
		EventBus.budget_changed,
		EventBus.room_build_started,
		EventBus.room_built,
		EventBus.room_demolished,
		EventBus.power_allocation_changed,
	]
	for event: Signal in signals:
		if on:
			event.connect(_on_event)
		else:
			event.disconnect(_on_event)
	if on:
		EventBus.tick_advanced.connect(_on_tick)
	else:
		EventBus.tick_advanced.disconnect(_on_tick)


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh()


## While shown, redraws when an arrival's hours left change or someone arrives.
func _on_tick(_tick: int) -> void:
	if _simulation != null and is_visible_in_tree():
		if _staff_signature(_simulation.state) != _signature:
			refresh()


static func _staff_signature(state: GameState) -> int:
	var parts: Array = [state.staff.people.size(), state.recruitment.candidates.size()]
	for person: PersonState in state.staff.people:
		parts.append(ceili(maxi(0, person.arrives_tick - state.clock.tick) / 60.0))
	return hash(parts)


## Ticks are skipped while the tab is hidden, so showing it rereads everything.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
