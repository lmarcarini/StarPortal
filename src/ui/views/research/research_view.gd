class_name ResearchView
extends GameView
## The Research tab (F4; docs/content/m25-lean-start.md section 3, "Where it lives"): the
## [ResearchBoard] (header, category sub-tabs and the tech tree) on the left and the SELECTED
## panel on the right. The tab is available once a Research Lab has finished and stays so for
## the rest of the game. The D-pad moves along the tree; the gamepad shoulders switch sub-tabs
## (past the first or last they switch the main tabs); (A), Enter or the panel's button starts
## the focused project, or cancels it while it runs. Every action is a command; a refusal
## shows on the panel. The board rereads the state on every research, money, room and power
## and staff event, so it stays right while paused.
## Bible: docs/content/m25-lean-start.md section 3

var _simulation: Simulation = null
## Set once a lab has finished in this game; the tab never hides again.
var _available: bool = false
var _signature: int = 0

var _queue := ResearchQueueBox.new()

@onready var _board: ResearchBoard = %Board
@onready var _panel: ResearchPanel = %Panel


func _ready() -> void:
	_board.project_chosen.connect(_on_chosen)
	_board.project_activated.connect(act)
	_board.category_changed.connect(_on_category_changed)
	_panel.action_pressed.connect(act)
	_panel.get_parent().add_child(_queue)
	visibility_changed.connect(_on_visibility_changed)


func _enter_tree() -> void:
	_connect_events(true)


func _exit_tree() -> void:
	_connect_events(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_board.set_categories(categories())
		refresh()


## Reads [param simulation]'s research.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_available = false
	_board.set_categories(categories())
	_panel.show_notice("")
	_queue.setup(simulation)
	refresh()
	_check_available()


func get_default_focus() -> Control:
	var nodes: Array[ResearchNode] = _board.get_tree_view().nodes()
	return nodes[0] if not nodes.is_empty() else _board.get_tabs()


func get_title_key() -> StringName:
	return &"RESEARCH_TITLE"


## True once a Research Lab has finished in this game, or research has begun.
func is_available() -> bool:
	return _available


## Returns the board (header, sub-tabs and tree), for tests.
func get_board() -> ResearchBoard:
	return _board


## The research categories (sub-tabs) loaded by the Registry.
static func categories() -> Array[ResearchCategoryDef]:
	var found: Array[ResearchCategoryDef] = []
	for def: DefBase in Registry.get_all_of(ResearchCategoryDef):
		found.append(def as ResearchCategoryDef)
	return found


## Returns the SELECTED panel, for tests.
func get_panel() -> ResearchPanel:
	return _panel


## Returns the research queue box.
func get_queue() -> ResearchQueueBox:
	return _queue


## Starts [param project_id], or cancels it when it is the running project; shows a refusal.
func act(project_id: StringName) -> void:
	if _simulation == null or project_id.is_empty():
		return
	var command: Command = StartResearchCommand.create(project_id)
	if _simulation.state.research.active == project_id:
		command = CancelResearchCommand.new()
	var result: CommandResult = _simulation.submit(command)
	refresh()
	_panel.show_notice("" if result.is_ok else ResearchText.refusal(result, _simulation.state))


## Rereads the list and the panel from the simulation.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	_board.show_state(state)
	var shown: StringName = _panel.get_project()
	if _board.get_tree_view().node_of(shown) == null:
		shown = _first_project()
	var def: ResearchDef = state.research_defs.get(shown)
	_panel.show_project(state, def)
	_queue.select(&"" if def == null else def.id)
	_signature = _research_signature(state)


## True when [param state]'s base has a Research Lab that has finished building.
static func has_finished_lab(state: GameState) -> bool:
	for room: RoomState in state.base.rooms:
		if room.def_id == ResearchRules.LAB_DEF and room.build_ticks_left <= 0:
			return true
	return false


func _check_available() -> void:
	if _available or _simulation == null:
		return
	var state: GameState = _simulation.state
	if has_finished_lab(state) or state.research.is_running() or not state.research.done.is_empty():
		_available = true
		availability_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton or not is_visible_in_tree():
		return
	var offset: int = 0
	if InputActions.is_new_press(event, &"view_next"):
		offset = 1
	elif InputActions.is_new_press(event, &"view_previous"):
		offset = -1
	if offset != 0 and _board.step_category(offset):
		get_viewport().set_input_as_handled()
		get_default_focus().grab_focus()


func _first_project() -> StringName:
	var nodes: Array[ResearchNode] = _board.get_tree_view().nodes()
	return nodes[0].project_id if not nodes.is_empty() else &""


func _on_category_changed(_category: StringName) -> void:
	if _simulation != null:
		_panel.show_notice("")
		var def: ResearchDef = _simulation.state.research_defs.get(_first_project())
		_panel.show_project(_simulation.state, def)


func _on_chosen(project_id: StringName) -> void:
	if _simulation != null:
		var def: ResearchDef = _simulation.state.research_defs.get(project_id)
		_panel.show_project(_simulation.state, def)
		_queue.select(project_id)


func _connect_events(on: bool) -> void:
	var signals: Array[Signal] = [
		EventBus.research_started,
		EventBus.research_queue_changed,
		EventBus.research_cancelled,
		EventBus.research_done,
		EventBus.budget_changed,
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
		EventBus.staff_changed.connect(_on_staff_changed)
	else:
		EventBus.tick_advanced.disconnect(_on_tick)
		EventBus.staff_changed.disconnect(_on_staff_changed)


## Staffing changes every project's time, so the tree and panel reread it.
func _on_staff_changed(_reason: StringName, _room_def_id: StringName, _count: int) -> void:
	refresh()


func _on_event(_arg: Variant = null) -> void:
	_check_available()
	refresh()


## While shown, redraws when the time left changes by an hour or a lab goes on or off.
func _on_tick(_tick: int) -> void:
	if _simulation == null:
		return
	_check_available()
	if is_visible_in_tree() and _research_signature(_simulation.state) != _signature:
		refresh()


static func _research_signature(state: GameState) -> int:
	return hash(
		[
			state.research.active,
			ceili(ResearchRules.ticks_left(state) / 60.0),
			state.research.done.size(),
			ResearchRules.has_lab_on(state),
		]
	)


## Ticks are skipped while the tab is hidden, so showing it rereads everything.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
