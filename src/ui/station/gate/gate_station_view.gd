class_name GateStationView
extends GameView
## The Gate station: the Gate hall plate with the Ring's live layers, and the console along
## the bottom. Enter or (A) on the station (not on another control) presses the main key.
## The Gate tab's view. High on the left, the locker (holding, MOTH order).
## Bible: docs/content/interface-rethink.md section 4 (Gate)

## The console asked to build a capacitor bank (open the Base).
signal capacitor_bank_requested
## The team report opened by itself (show the Gate).
signal report_opened

## The station def shown.
const STATION_ID: StringName = &"station_gate"
const _TITLE_KEY: StringName = &"STATION_GATE_TITLE"

var _simulation: Simulation = null
var _ring: RingLayer = null
var _report: PaperCard = PaperCard.new()
var _report_panel: WorldReportPanel = WorldReportPanel.new()
var _rail: SendRail = SendRail.new()
var _moth: MothScreen = MothScreen.new()
var _floor: FloorActors = FloorActors.new()
var _sheet: MissionSheet = MissionSheet.new()
var _team: TeamCard = TeamCard.new()
var _report_screen: TeamReportScreen = TeamReportScreen.new()
var _locker: GateLocker = GateLocker.new()
var _note: LineEdit = LineEdit.new()
var _note_key: String = ""

@onready var _station: StationScene = %Station
@onready var _console: GateConsole = %GateConsole
@onready var _rack: DestinationRack = %DestinationRack
@onready var _panel: AlienPanel = %AlienPanel


func _enter_tree() -> void:
	EventBus.team_debrief.connect(_on_team_debrief)
	EventBus.team_rescued.connect(_on_team_rescued)
	EventBus.team_lost.connect(_on_team_lost)
	EventBus.wormhole_closed.connect(_on_wormhole_closed)


func _exit_tree() -> void:
	EventBus.team_debrief.disconnect(_on_team_debrief)
	EventBus.team_rescued.disconnect(_on_team_rescued)
	EventBus.team_lost.disconnect(_on_team_lost)
	EventBus.wormhole_closed.disconnect(_on_wormhole_closed)


func _ready() -> void:
	_station.setup(Registry.get_def(STATION_ID) as StationSceneDef)
	_console.build_bank_requested.connect(capacitor_bank_requested.emit)
	_rack.destination_selected.connect(_console.select_destination)
	_rack.report_requested.connect(_show_report)
	_rack.order_requested.connect(_open_order_sheet)
	_rack.new_address_requested.connect(open_alien_panel)
	_panel.dial_requested.connect(_on_panel_dial)
	_panel.closed.connect(func() -> void: _console.get_main_key().grab_focus())
	_panel.hide()
	_build_report()
	_rail.name = "SendRail"
	_rail.key_used.connect(_on_rail_used)
	visibility_changed.connect(_on_visibility)
	add_child(_rail)
	move_child(_rail, _station.get_index() + 1)
	add_child(_moth)
	_moth.z_index = 5
	_moth.changed.connect(_on_moth_changed)
	_rail.team_opens_sheet = true
	_rail.team_requested.connect(open_mission_sheet)
	_sheet.name = "MissionSheet"
	add_child(_sheet)
	_team.name = "TeamCard"
	add_child(_team)
	move_child(_team, _rail.get_index())
	_locker.name = "GateLocker"
	add_child(_locker)
	add_child(_locker.get_card())
	_rail.move_console_key(_locker)
	_team.pressed.connect(_open_team_report)
	_add_report_screen()
	resized.connect(_layout)
	_layout.call_deferred()


## Reads [param simulation]; the layers snap to its state.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	if _ring == null:
		_ring = RingLayer.install(_station, simulation)
		_floor.name = "FloorActors"
		_station.add_layer(_floor, 35)
		_floor.bind(_station)
		_console.set_close_busy_check(_floor.is_busy)
	else:
		_ring.bind(simulation, _station)
	_console.setup(simulation)
	_rack.setup(simulation)
	_panel.setup(simulation)
	_rail.setup(simulation)
	_moth.setup(simulation)
	_sheet.setup(simulation)
	_team.setup(simulation)
	_report_screen.setup(simulation)
	_locker.setup(simulation)
	_report.visible = false


func _open_team_report() -> void:
	_team.report_waiting = false
	_report_screen.open(_report_screen.get_debrief())


## Reopens the team report of the Log's return [param entry] (report_opened follows).
func show_log_report(entry: LogEntry) -> void:
	if _simulation != null:
		_show_team_report(DebriefRules.of_log(_simulation.state, entry), true)


## Shows [param debrief] on the team report: at once (with report_opened) when [param asked]
## (reopened from the Log) or the setting gameplay/auto_open_team_report is on, else it waits
## on the team card.
func _show_team_report(debrief: DebriefRules.Debrief, asked: bool = false) -> void:
	if not asked and not Settings.get_bool(&"gameplay", &"auto_open_team_report"):
		_report_screen.keep(debrief)
		_team.report_waiting = true
		return
	_report_screen.open(debrief)
	report_opened.emit()


## The main key.
func get_default_focus() -> Control:
	return _console.get_main_key()


## Returns [code]STATION_GATE_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY


## The station scene (plate and layers).
func get_station() -> StationScene:
	return _station


## The console.
func get_console() -> GateConsole:
	return _console


## The destination rack.
func get_rack() -> DestinationRack:
	return _rack


## Shows the World Report of [param world_id] on a paper card with the player's note on
## Address Book entry [param key] under it; a world never reached shows only the note, and
## nothing without a key.
func _show_report(world_id: StringName, key: String = "") -> void:
	if _simulation == null or (world_id.is_empty() and key.is_empty()):
		return
	_report_panel.visible = not world_id.is_empty()
	if _report_panel.visible:
		_report_panel.show_world(world_id, _simulation.state)
	_note_key = key
	var entry: AddressEntry = _simulation.state.address_book.find(key) if key != "" else null
	_note.visible = entry != null
	_note.text = entry.note if entry != null else ""
	_report.visible = true
	_report.reset_size()
	_report.position = (size - _report.size) * 0.5


## Opens the alien panel (+ NEW ADDRESS).
func open_alien_panel() -> void:
	_sheet.close()
	_panel.open()


## The alien panel.
func get_alien_panel() -> AlienPanel:
	return _panel


## The send rail.
func get_rail() -> SendRail:
	return _rail


## The MOTH scan screen.
func get_moth_screen() -> MothScreen:
	return _moth


## The floor actors layer.
func get_floor() -> FloorActors:
	return _floor


## Opens the mission sheet for the world the wormhole is open to.
func open_mission_sheet() -> void:
	if _simulation == null:
		return
	_sheet.open_for(_simulation.state.gate.connected_world_id)
	_place_sheet()


## Opens the mission sheet to order a mission to [param destination] from a closed gate.
func _open_order_sheet(destination: GateDestination) -> void:
	if _simulation == null or destination.world_id.is_empty():
		return
	_sheet.open_for(destination.world_id, destination.address)
	_place_sheet()


## Puts the mission sheet on its region, above the rail and clear of the Ring.
func _place_sheet() -> void:
	_sheet.reset_size()
	var region: Rect2 = GateLayout.REGIONS[&"mission_sheet"]
	_sheet.position = region.position + Vector2(GateLayout.centre_shift(size.x), 0)


## The mission sheet.
func get_mission_sheet() -> MissionSheet:
	return _sheet


## The team card.
func get_team_card() -> TeamCard:
	return _team


## The team report screen.
func get_team_report() -> TeamReportScreen:
	return _report_screen


## The locker (holding, MOTH order).
func get_locker() -> GateLocker:
	return _locker


## Opens the mission sheet for [param world_id] (a World Report's plan request): through the
## wormhole open to it, else as a mission order from its Address Book entry.
func plan_world(world_id: StringName) -> void:
	if _simulation == null:
		return
	var gate: GateState = _simulation.state.gate
	if gate.mode == GateState.RingMode.LOCKED and gate.connected_world_id == world_id:
		open_mission_sheet()
		return
	for entry: AddressEntry in _simulation.state.address_book.entries:
		if entry.world_id == world_id:
			_open_order_sheet(DestinationRack.destination_of(entry, _simulation.state))
			return
	var galaxy: GalaxyCatalogue = _simulation.state.galaxy
	if galaxy != null and galaxy.get_world(world_id) != null:
		var address: GateAddress = galaxy.address_of(world_id, galaxy.home().origin_glyph)
		_open_order_sheet(GateDestination.of(address, "", world_id))


## The World Report card.
func get_report_card() -> PaperCard:
	return _report


## The Ring's layer.
func get_ring_layer() -> RingLayer:
	return _ring


func _on_panel_dial(address: GateAddress) -> void:
	_console.select_composing(address)
	_console.press_main_key()
	if _simulation.state.gate.mode == GateState.RingMode.IDLE:
		_panel.show_refusal(_console.get_key_reason())
		return
	_panel.close()


func _build_report() -> void:
	_report.name = "WorldReportCard"
	_report.z_index = 6
	_report.visible = false
	_report_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var sheet: VBoxContainer = VBoxContainer.new()
	sheet.add_child(_report_panel)
	_note.name = "Note"
	_note.max_length = AddressEntry.MAX_NOTE_LENGTH
	_note.text_submitted.connect(func(_t: String) -> void: _save_note())
	_note.focus_exited.connect(_save_note)
	HoverCard.attach(_note, "HW_ICON_PENCIL")
	sheet.add_child(_note)
	_report.add_child(sheet)
	_report.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_report_panel.plan_requested.connect(plan_world)
	_report.gui_input.connect(_on_report_input)
	add_child(_report)


func _save_note() -> void:
	if _simulation == null or _note_key.is_empty() or not _note.visible:
		return
	var entry: AddressEntry = _simulation.state.address_book.find(_note_key)
	if entry != null and entry.note != _note.text:
		_simulation.submit(NoteAddressCommand.create(_note_key, _note.text))


func _on_moth_changed() -> void:
	if _moth.is_open() and is_visible_in_tree():
		_moth.get_default_focus().grab_focus.call_deferred()


func _add_report_screen() -> void:
	add_child(_report_screen)
	_report_screen.world_requested.connect(_show_report)
	_report_screen.holding_requested.connect(_locker.toggle_holding)


func _on_team_debrief(world: StringName, summary: Dictionary) -> void:
	if _simulation != null:
		_show_team_report(DebriefRules.of_return(_simulation.state, world, summary))


func _on_team_rescued(world: StringName, _survivors: int) -> void:
	if _simulation != null:
		_show_team_report(DebriefRules.of_end(world, false))


func _on_team_lost(world: StringName, _reason: StringName) -> void:
	if _simulation != null:
		_show_team_report(DebriefRules.of_end(world, true))


func _on_rail_used(id: StringName) -> void:
	if id == &"camera":
		_floor.play(ActorCues.Cue.CAMERA_PUSH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _floor.get_parent() == null:
		_floor.free()


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_floor.snap_all()
		_sheet.close()


func _on_wormhole_closed(_reason: StringName) -> void:
	if not _sheet.is_order():
		_sheet.close()


func _on_report_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		_report.visible = false


func _layout() -> void:
	GateLayout.place(self, _rack, _console)
	GateLayout.put(_team, &"team_card", 0.0)
	var centre: float = GateLayout.centre_shift(size.x)
	_rail.reset_size()
	_rail.position = GateLayout.REGIONS[&"send_rail"].position + Vector2(centre, 0)
	_locker.reset_size()
	_locker.position = _rack.position + Vector2(_rack.size.x - _locker.size.x - 14.0, 8.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _panel.visible:
		return
	if _report.visible and event.is_action_pressed(&"ui_cancel"):
		_report.visible = false
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_accept"):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is BaseButton:
		return
	_console.press_main_key()
	get_viewport().set_input_as_handled()
