class_name GateStationView
extends GameView
## The Gate station: the Gate hall plate with the Ring's live layers, and the console along
## the bottom. Enter or (A) on the station (not on another control) presses the main key.
## The Gate tab's view. High on the left, the locker (holding, MOTH order).
## Bible: docs/content/interface-rethink.md section 4 (Gate)

## The console asked to build a capacitor bank (open the Base).
signal capacitor_bank_requested

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
var _orders: TeamOrders = TeamOrders.new()
var _sheet: MissionSheet = MissionSheet.new()
var _team: TeamCard = TeamCard.new()
var _debrief: DebriefCard = DebriefCard.new()
var _locker: GateLocker = GateLocker.new()
var _note: LineEdit = LineEdit.new()
var _note_key: String = ""

@onready var _station: StationScene = %Station
@onready var _console: GateConsole = %GateConsole
@onready var _rack: DestinationRack = %DestinationRack
@onready var _panel: AlienPanel = %AlienPanel


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
	_moth.changed.connect(_on_moth_changed)
	_orders.name = "TeamOrders"
	add_child(_orders)
	_rail.orders_requested.connect(_show_orders)
	_rail.team_opens_sheet = true
	_rail.team_requested.connect(open_mission_sheet)
	_sheet.name = "MissionSheet"
	add_child(_sheet)
	_team.name = "TeamCard"
	add_child(_team)
	move_child(_team, _rail.get_index())
	_debrief.name = "DebriefCard"
	add_child(_debrief)
	_locker.name = "GateLocker"
	_locker.position = Vector2(16, 16)
	add_child(_locker)
	add_child(_locker.get_card())
	_debrief.resized.connect(func() -> void: _debrief.position = (size - _debrief.size) * 0.5)
	resized.connect(_layout)
	_console.resized.connect(_layout)
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
	_orders.setup(simulation)
	_sheet.setup(simulation)
	_team.setup(simulation)
	_debrief.setup(simulation)
	_locker.setup(simulation)
	_report.visible = false


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
	_sheet.reset_size()
	_sheet.position = Vector2(_rail.position.x, maxf(12.0, _rail.position.y - _sheet.size.y - 12.0))


## Opens the mission sheet to order a mission to [param destination] from a closed gate.
func _open_order_sheet(destination: GateDestination) -> void:
	if _simulation == null or destination.world_id.is_empty():
		return
	_sheet.open_for(destination.world_id, destination.address)
	_sheet.reset_size()
	_sheet.position = Vector2(_rack.position.x - _sheet.size.x - 12.0, 12.0)


## The mission sheet.
func get_mission_sheet() -> MissionSheet:
	return _sheet


## The team card.
func get_team_card() -> TeamCard:
	return _team


## The debrief card.
func get_debrief() -> DebriefCard:
	return _debrief


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


## The team orders card.
func get_team_orders() -> TeamOrders:
	return _orders


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


func _show_orders() -> void:
	_orders.open()
	_orders.position = _rail.position + Vector2(0, -_orders.size.y - 12.0)


func _on_rail_used(id: StringName) -> void:
	if id == &"camera":
		_floor.play(ActorCues.Cue.CAMERA_PUSH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _floor.get_parent() == null:
		_floor.free()


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_floor.snap_all()


func _on_report_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		_report.visible = false


func _layout() -> void:
	var s: float = HwMetrics.scale_of(self)
	var width: float = DestinationCard.CARD_SIZE.x * s + 24.0
	_rack.position = Vector2(size.x - width - 12.0, 12.0)
	_rack.size = Vector2(width, maxf(0.0, size.y - _console.size.y - 24.0))
	_team.position = Vector2(16.0, size.y - _console.size.y - _team.size.y - 16.0)
	var rail_at: Vector2 = _station.anchor(&"rail")
	_rail.reset_size()
	_rail.position = Vector2(
		rail_at.x, minf(rail_at.y, size.y - _console.size.y - _rail.size.y - 8.0)
	)


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
