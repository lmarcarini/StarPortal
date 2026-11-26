class_name ResearchView
extends GameView
## The Lab station (interface-reference.md section 9; docs/content/research-and-progression.md
## section 7): [LabTabs] (one per open discipline), the [LabBoard] of the shown discipline
## (only visible projects), the [LabPanel] of the selected project with START and ADD TO
## QUEUE, and one [LabBench] per research building in the console. Opening a NEW project
## records it as opened (OpenResearchCommand), so its lamp goes out. A bench pressed in the
## console is the target of START and ADD TO QUEUE for its discipline; otherwise the first
## idle building of the project's discipline is used. The gamepad shoulders step through the
## disciplines (past the ends, the main tabs). Every action is a command; a refusal shows on
## the panel.
## Bible: docs/content/interface-reference.md section 9

var _simulation: Simulation = null
## Set once research is possible in this game; the station never hides again.
var _available: bool = false
var _signature: int = 0
var _discipline: StringName = &""
var _selected: StringName = &""

var _tabs: LabTabs = LabTabs.new()
var _board: LabBoard = LabBoard.new()
var _panel: LabPanel = LabPanel.new()
var _benches: LabBenches = LabBenches.new()


func _ready() -> void:
	for part: Control in [_tabs, _board, _panel, _benches]:
		add_child(part)
	_tabs.discipline_chosen.connect(show_discipline)
	_board.project_chosen.connect(select_project)
	_board.project_activated.connect(start)
	_panel.start_pressed.connect(start)
	_panel.queue_pressed.connect(add_to_queue)
	resized.connect(_place)
	visibility_changed.connect(_on_visibility_changed)
	_place()


func _enter_tree() -> void:
	_connect_events(true)


func _exit_tree() -> void:
	_connect_events(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads [param simulation]'s research; shows the first open discipline.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_available = false
	_discipline = &""
	_selected = &""
	_panel.show_notice("")
	refresh()
	_check_available()


func get_default_focus() -> Control:
	var tile: LabTile = _board.first_tile()
	if tile != null:
		return tile
	var keys: Array[LabTabKey] = _tabs.keys()
	return keys[0] if not keys.is_empty() else self


func get_title_key() -> StringName:
	return &"RESEARCH_TITLE"


## True once research is possible in this game (a research building stands, or research
## has begun).
func is_available() -> bool:
	return _available


## The station's lamp: a visible project not yet opened.
func needs_attention() -> bool:
	if _simulation == null:
		return false
	for discipline: StringName in ResearchRules.open_disciplines(_simulation.state):
		if LabTabs.has_new(_simulation.state, discipline):
			return true
	return false


## The research categories loaded by the Registry (content checks).
static func categories() -> Array[ResearchCategoryDef]:
	var found: Array[ResearchCategoryDef] = []
	for def: DefBase in Registry.get_all_of(ResearchCategoryDef):
		found.append(def as ResearchCategoryDef)
	return found


## The discipline tabs.
func get_tabs() -> LabTabs:
	return _tabs


## The board.
func get_board() -> LabBoard:
	return _board


## The selected project's panel.
func get_panel() -> LabPanel:
	return _panel


## The console's benches.
func get_benches() -> LabBenches:
	return _benches


## The discipline shown.
func get_discipline() -> StringName:
	return _discipline


## Shows [param discipline]'s board (when it is open) and selects its first project.
func show_discipline(discipline: StringName) -> void:
	if _simulation == null:
		return
	if not discipline in ResearchRules.open_disciplines(_simulation.state):
		return
	_discipline = discipline
	_selected = &""
	_panel.show_notice("")
	refresh()


## Selects [param project_id] (showing its discipline): the panel shows it and, when it is
## NEW, it is recorded as opened.
func select_project(project_id: StringName) -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var def: ResearchDef = state.research_defs.get(project_id)
	if def == null or not ResearchRules.visible(state, def):
		return
	_selected = project_id
	if def.discipline != _discipline and def.discipline in ResearchRules.open_disciplines(state):
		_discipline = def.discipline
	if state.research.is_new(project_id):
		_simulation.submit(OpenResearchCommand.new(project_id))
	refresh()


## START: starts [param project_id] at the target bench (or the first idle one of its
## discipline); cancels it while it runs.
func start(project_id: StringName) -> void:
	if _simulation == null or project_id.is_empty():
		return
	select_project(project_id)
	var state: GameState = _simulation.state
	var running_at: StringName = state.research.room_running(project_id)
	var command: Command = StartResearchCommand.create(project_id, _target_for(project_id))
	if not running_at.is_empty():
		command = CancelResearchCommand.new(running_at)
	_submit(command)


## ADD TO QUEUE: queues [param project_id] at the target bench, or the first idle (else
## first) building of its discipline.
func add_to_queue(project_id: StringName) -> void:
	if _simulation == null or project_id.is_empty():
		return
	var state: GameState = _simulation.state
	var def: ResearchDef = state.research_defs.get(project_id)
	if def == null:
		return
	var room: StringName = _target_for(project_id)
	if room.is_empty():
		room = ResearchRules.pick_room(state, def)
	_submit(QueueResearchCommand.new(project_id, room))


## Rereads the tabs, board, panel and benches from the simulation.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var open: Array[StringName] = ResearchRules.open_disciplines(state)
	if not _discipline in open:
		_discipline = &"" if open.is_empty() else open[0]
	_tabs.show_state(state)
	_tabs.mark(_discipline)
	_board.show_discipline(state, _discipline)
	if _board.tile_of(_selected) == null:
		var first: LabTile = _board.first_tile()
		_selected = &"" if first == null else first.project_id
	_board.select(_selected)
	var shown: ResearchDef = state.research_defs.get(_selected)
	_panel.show_project(state, shown)
	_benches.show_state(state)
	_signature = _research_signature(state)


func _target_for(project_id: StringName) -> StringName:
	var state: GameState = _simulation.state
	var def: ResearchDef = state.research_defs.get(project_id)
	var target: StringName = _benches.get_target()
	if def == null or target.is_empty():
		return &""
	var room: RoomState = state.base.find_room(target)
	var room_def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if room_def == null or room_def.research_discipline != def.discipline:
		return &""
	return target


func _submit(command: Command) -> void:
	var result: CommandResult = _simulation.submit(command)
	refresh()
	_panel.show_notice("" if result.is_ok else LabText.refusal(result, _simulation.state))


func _place() -> void:
	LabLayout.place(_tabs, &"lab_tabs", size.x)
	LabLayout.place(_board, &"lab_board", size.x)
	LabLayout.place(_panel, &"lab_panel", size.x)
	LabLayout.place(_benches, &"lab_benches", size.x)


func _check_available() -> void:
	if _available or _simulation == null:
		return
	var state: GameState = _simulation.state
	if state.research.is_running() or not state.research.done.is_empty() or _has_building(state):
		_available = true
		availability_changed.emit()


static func _has_building(state: GameState) -> bool:
	for room: RoomState in LabBenches.buildings(state):
		if room.build_ticks_left <= 0:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton or not is_visible_in_tree() or _simulation == null:
		return
	var offset: int = 0
	if InputActions.is_new_press(event, &"view_next"):
		offset = 1
	elif InputActions.is_new_press(event, &"view_previous"):
		offset = -1
	if offset != 0 and step_discipline(offset):
		get_viewport().set_input_as_handled()
		get_default_focus().grab_focus()


## Shows the discipline [param offset] tabs away; false past either end (the shoulder is then
## left to the main tabs).
func step_discipline(offset: int) -> bool:
	if _simulation == null:
		return false
	var open: Array[StringName] = ResearchRules.open_disciplines(_simulation.state)
	var index: int = open.find(_discipline) + offset
	if index < 0 or index >= open.size():
		return false
	show_discipline(open[index])
	return true


func _connect_events(on: bool) -> void:
	var signals: Array[Signal] = [
		EventBus.research_started,
		EventBus.research_queue_changed,
		EventBus.research_cancelled,
		EventBus.research_done,
		EventBus.research_revealed,
		EventBus.research_opened,
		EventBus.budget_changed,
		EventBus.room_built,
		EventBus.room_demolished,
		EventBus.power_allocation_changed,
		EventBus.staff_changed,
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
	_check_available()
	refresh()


## While shown, redraws when an hour of time left passes or the research moves.
func _on_tick(_tick: int) -> void:
	if _simulation == null:
		return
	_check_available()
	if is_visible_in_tree() and _research_signature(_simulation.state) != _signature:
		refresh()


static func _research_signature(state: GameState) -> int:
	return hash([state.research.to_dict(), state.clock.tick / 60])


## Ticks are skipped while the station is hidden, so showing it rereads everything.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
