class_name Frame
extends Control
## The frame bolted round every station (interface-rethink.md section 3): thin steel plates
## over the scene, which shows between them. Top left the clock plate (date flap, pause /
## play / fast, the slow lamp and the call lamp) and a status plate (the gate chip and the
## rescue entry); top centre the alarm strip during an incursion; top right the gauge plate
## (funds, power, charge, Confidence). Under the left plates runs the wire, the event cards
## with their action keys (M4.10-02); bottom left the four station keys (M4.10-03). Save,
## Load and the debug button left the screen: they
## are in the pause menu and on F12. Redraws on
## EventBus signals and on [method bind]. Reads state only.
## Bible: docs/content/interface-rethink.md section 3

## Asks the shell to show [param view_id], on [param sub_tab] when not empty.
signal open_view(view_id: StringName, sub_tab: StringName)
## The player chose [param entry] in the alert list (the shell selects its target).
signal alert_chosen(entry: AlertEntry)
## The band the top plates take changed height.
signal band_changed
## The wire asks the shell to run [param step] (&"rescue", &"report") for [param card].
signal wire_step(step: StringName, card: WireCardData)
## The wire's stack was pressed: open the full log.
signal log_requested

## Gap between the plates and the screen edge, in pixels.
const EDGE: float = 8.0

## The plates.
var clock_plate := ClockPlate.new()
var status_plate := SteelPanel.new()
var gauge_plate := GaugePlate.new()
## Clock, speed, slow lamp and call lamp.
var time_bar: TimeBar = clock_plate.time_bar
## Funds, Confidence and power numbers (on the gauge plate).
var money_label: MoneyLabel = gauge_plate.money_label
var confidence_readout: ConfidenceReadout = gauge_plate.confidence_readout
var power_readout: PowerReadout = gauge_plate.power_readout
## The gate's state.
var gate_chip := GateChip.new()
## The alerts the wire reads (a model: never shown).
var alert_list := AlertList.new()
## The wire: event cards with their action keys, under the left plates.
var wire := Wire.new()
## The four station keys, bottom left.
var station_keys := StationKeys.new()
## The incursion strip and alarm look.
var alarm_strip := AlarmStrip.new()

## Extra gap above the wire, below the band (the shell's tab bar until the station keys).
var wire_gap: float = 0.0:
	set(value):
		wire_gap = value
		_layout()

var _state: GameState = null
var _band: float = 0.0
var _left: HFlowContainer = HFlowContainer.new()
var _status_row: HBoxContainer = HBoxContainer.new()


func _init() -> void:
	name = &"Frame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_left.add_theme_constant_override(&"h_separation", 6)
	_left.add_theme_constant_override(&"v_separation", 6)
	_left.position = Vector2(EDGE, EDGE)
	add_child(_left)
	_left.add_child(clock_plate)
	_left.add_child(status_plate)
	status_plate.name = &"StatusPlate"
	status_plate.add_child(_status_row)
	_status_row.add_theme_constant_override(&"separation", 6)
	_status_row.add_child(gate_chip)
	gate_chip.pressed.connect(open_view.emit.bind(ViewSwitcher.GATE_ROOM, &""))
	add_child(gauge_plate)
	gauge_plate.open_view.connect(open_view.emit)
	add_child(alarm_strip)
	alert_list.visible = false
	add_child(alert_list)
	wire.position = Vector2(EDGE, EDGE)
	add_child(wire)
	add_child(station_keys)
	station_keys.resized.connect(_layout)
	wire.open_view.connect(open_view.emit)
	wire.entry_chosen.connect(_on_alert_chosen)
	wire.step_requested.connect(wire_step.emit)
	wire.log_requested.connect(log_requested.emit)


func _ready() -> void:
	resized.connect(_layout)
	gauge_plate.resized.connect(_layout)
	_left.resized.connect(_layout)
	_layout.call_deferred()


func _enter_tree() -> void:
	for signal_name: StringName in _redraw_signals():
		EventBus.connect(signal_name, _on_event)
	EventBus.tick_advanced.connect(_on_tick)


func _exit_tree() -> void:
	for signal_name: StringName in _redraw_signals():
		EventBus.disconnect(signal_name, _on_event)
	EventBus.tick_advanced.disconnect(_on_tick)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads [param simulation]'s state (after a start or a load) and redraws every plate.
func bind(simulation: Simulation) -> void:
	_state = simulation.state
	gauge_plate.bind(_state)
	alert_list.bind(_state)
	wire.bind(simulation, alert_list)
	refresh()


## Redraws every plate from the bound state.
func refresh() -> void:
	if _state == null:
		return
	gauge_plate.show_state(_state)
	_refresh_live()


## Height of the bottom band the station keys take, in pixels.
func bottom_height() -> float:
	return station_keys.size.y + EDGE * 2.0


## Height of the top plates' band, in pixels (the scene shows below and between).
func band_height() -> float:
	return maxf(_left.size.y, gauge_plate.size.y) + EDGE * 2.0


## Puts [param control] on the status plate (the shell's rescue entries).
func add_after_clock(control: Control) -> void:
	_status_row.add_child(control)


## The buttons in focus order: the clock keys, [param extra], the gate chip, the gauge
## numbers, then the wire's keys.
func get_focus_buttons(extra: Array[Button]) -> Array[Button]:
	var buttons: Array[Button] = clock_plate.get_buttons()
	buttons.append_array(extra)
	buttons.append(gate_chip)
	buttons.append_array(gauge_plate.get_buttons())
	buttons.append_array(wire.get_keys())
	buttons.append_array(station_keys.get_buttons())
	return buttons.filter(func(b: Button) -> bool: return b.visible)


## The used width of the left plates' widest row.
func _left_width() -> float:
	var right: float = 0.0
	for plate: Control in _left.get_children():
		right = maxf(right, plate.position.x + plate.size.x)
	return right


## The left plates and the gauge plate, in screen space (for tests).
func get_plates() -> Array[Control]:
	return [clock_plate, status_plate, gauge_plate]


func _layout() -> void:
	gauge_plate.reset_size()
	gauge_plate.position = Vector2(size.x - gauge_plate.size.x - EDGE, EDGE)
	# The left plates wrap to a second row rather than run under the gauges.
	_left.size = Vector2(maxf(0.0, gauge_plate.position.x - EDGE * 2.0), 0.0)
	alarm_strip.reset_size()
	var gap_left: float = _left.position.x + _left_width()
	var centre: float = (gap_left + gauge_plate.position.x) * 0.5
	alarm_strip.position = Vector2(centre - alarm_strip.size.x * 0.5, EDGE)
	wire.position = Vector2(EDGE, band_height() + wire_gap)
	station_keys.reset_size()
	station_keys.position = Vector2(EDGE, size.y - station_keys.size.y - EDGE)
	var bands: float = band_height() + bottom_height() * 1000.0
	if not is_equal_approx(bands, _band):
		_band = bands
		band_changed.emit()


func _on_alert_chosen(entry: AlertEntry) -> void:
	open_view.emit(entry.view_id, entry.sub_tab)
	alert_chosen.emit(entry)


func _refresh_live() -> void:
	gauge_plate.show_power(_state)
	gate_chip.show_state(_state)
	alarm_strip.show_state(_state)
	_layout()


static func _redraw_signals() -> Array[StringName]:
	return [
		&"budget_changed",
		&"day_started",
		&"confidence_changed",
		&"room_built",
		&"room_demolished",
		&"staff_changed",
		&"power_allocation_changed",
		&"dial_started",
		&"dial_resolved",
		&"wormhole_closed",
		&"incoming_wormhole",
		&"incoming_answered",
		&"incoming_ignored",
		&"game_loaded",
		&"incursion_warning",
		&"incursion_breached",
		&"incursion_ended",
	]


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh()


func _on_tick(_tick: int) -> void:
	if _state != null:
		_refresh_live()
