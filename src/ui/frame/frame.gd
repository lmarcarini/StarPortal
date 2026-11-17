class_name Frame
extends Control
## The frame bolted round every station, laid out exactly as the interface reference
## (interface-reference.md sections 2 and 4; regions at 1920 x 1080). The top bar: a dark
## band with five steel plates (site, clock, resources, call, speed). The wire on the left
## under it. The bottom bar, full width, with the four station keys; on every station but the
## Gate the station console and the gate monitor (the Gate draws its own console there). The
## scene shows full bleed behind. Wider windows add space between the left group and the
## right group; nothing stretches. Redraws on EventBus signals and on [method bind]. Reads
## state only.
## Bible: docs/content/interface-reference.md sections 2 and 4

## Asks the shell to show [param view_id], on [param sub_tab] when not empty.
signal open_view(view_id: StringName, sub_tab: StringName)
## The player chose [param entry] in the alert list (the shell selects its target).
signal alert_chosen(entry: AlertEntry)
## The wire asks the shell to run [param step] (&"rescue", &"report") for [param card].
signal wire_step(step: StringName, card: WireCardData)
## The wire's stack was pressed: open the full log.
signal log_requested
## The settings key was pressed.
signal settings_requested

## The bands behind the plates.
var band := FrameBand.new()
## The top plates.
var site_plate := SitePlate.new()
var clock_plate := ClockPlate.new()
var resources_plate := ResourcesPlate.new()
var call_plate := CallPlate.new()
var speed_plate := SpeedPlate.new()
## Clock and call logic (hidden, on the clock plate).
var time_bar: TimeBar = clock_plate.time_bar
## The resource cells (the old readouts, drawn by the resources plate).
var money_label: MoneyLabel = resources_plate.money_label
var confidence_readout: ConfidenceReadout = resources_plate.confidence_readout
var power_readout: PowerReadout = resources_plate.power_readout
## The gate's state (hidden: the gate monitor and the Gate station show it).
var gate_chip := GateChip.new()
## The alerts the wire reads (a model: never shown).
var alert_list := AlertList.new()
## The wire: event cards with their action keys.
var wire := Wire.new()
## The four station keys, bottom left.
var station_keys := StationKeys.new()
## The console plate and the gate monitor, bottom right (not on the Gate).
var station_console := StationConsole.new()
var gate_monitor := GateMonitor.new()
## The incursion strip and alarm look.
var alarm_strip := AlarmStrip.new()

var _state: GameState = null
var _extras: VBoxContainer = VBoxContainer.new()


func _init() -> void:
	name = &"Frame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child: Control in [band, site_plate, clock_plate, resources_plate, call_plate, speed_plate]:
		add_child(child)
	gate_chip.visible = false
	add_child(gate_chip)
	gate_chip.pressed.connect(open_view.emit.bind(ViewSwitcher.GATE_ROOM, &""))
	resources_plate.open_view.connect(open_view.emit)
	call_plate.setup(time_bar.get_call_button())
	speed_plate.setup(time_bar)
	speed_plate.settings_requested.connect(settings_requested.emit)
	add_child(alarm_strip)
	alert_list.visible = false
	add_child(alert_list)
	for child: Control in [wire, _extras, station_keys, station_console, gate_monitor]:
		add_child(child)
	gate_monitor.pressed.connect(open_view.emit.bind(ViewSwitcher.GATE_ROOM, &""))
	wire.open_view.connect(open_view.emit)
	wire.entry_chosen.connect(_on_alert_chosen)
	wire.step_requested.connect(wire_step.emit)
	wire.log_requested.connect(log_requested.emit)


func _ready() -> void:
	resized.connect(_layout)
	_layout()


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
	resources_plate.bind(_state)
	alert_list.bind(_state)
	wire.bind(simulation, alert_list)
	gate_monitor.bind(simulation)
	refresh()


## Redraws every plate from the bound state.
func refresh() -> void:
	if _state == null:
		return
	resources_plate.show_state(_state)
	_refresh_live()


## Shows the station console and the gate monitor ([param on]: every station but the Gate).
func show_station_console(on: bool) -> void:
	station_console.visible = on
	gate_monitor.wanted = on


## Puts [param control] under the wire's +N key (the shell's rescue entries).
func add_after_clock(control: Control) -> void:
	_extras.add_child(control)


## The buttons in focus order: the speed keys, [param extra], the call plate, the resource
## cells, the wire's keys, then the station keys.
func get_focus_buttons(extra: Array[Button]) -> Array[Button]:
	var buttons: Array[Button] = speed_plate.get_buttons()
	buttons.append_array(extra)
	if call_plate.is_waiting():
		buttons.append(call_plate)
	buttons.append_array(resources_plate.get_buttons())
	buttons.append_array(wire.get_keys())
	buttons.append_array(station_keys.get_buttons())
	return buttons.filter(func(b: Button) -> bool: return b.visible)


## The top plates (for tests).
func get_plates() -> Array[Control]:
	return [site_plate, clock_plate, resources_plate, call_plate, speed_plate]


func _layout() -> void:
	var right: float = size.x - FrameLayout.WIDTH
	var left_group: Dictionary[Control, StringName] = {
		site_plate: &"top_site",
		clock_plate: &"top_clock",
		resources_plate: &"top_resources",
		wire: &"wire",
		station_keys: &"station_keys",
		station_console: &"station_console",
	}
	for control: Control in left_group:
		FrameLayout.place(control, left_group[control], 0.0)
	var right_group: Dictionary[Control, StringName] = {
		call_plate: &"top_call", speed_plate: &"top_speed", gate_monitor: &"gate_monitor"
	}
	for control: Control in right_group:
		FrameLayout.place(control, right_group[control], right)
	_extras.position = (
		wire.position + Vector2(Wire.STACK_SIZE.x + 10.0, wire.size.y - Wire.STACK_SIZE.y)
	)
	alarm_strip.reset_size()
	alarm_strip.position = Vector2((size.x - alarm_strip.size.x) * 0.5, FrameBand.TOP + 8.0)


func _on_alert_chosen(entry: AlertEntry) -> void:
	open_view.emit(entry.view_id, entry.sub_tab)
	alert_chosen.emit(entry)


func _refresh_live() -> void:
	resources_plate.show_power(_state)
	gate_chip.show_state(_state)
	alarm_strip.show_state(_state)
	call_plate.refresh()
	speed_plate.refresh()
	clock_plate.queue_redraw()


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
		&"speed_changed",
		&"paused_changed",
		&"slow_changed",
		&"contact_pending",
		&"call_missed",
		&"conversation_started",
		&"conversation_ended",
	]


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh()


func _on_tick(_tick: int) -> void:
	if _state != null:
		_refresh_live()
