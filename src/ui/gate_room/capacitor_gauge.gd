class_name CapacitorGauge
extends VBoxContainer
## The capacitor bank: a bar of the stored energy against the capacity, the two numbers, and a
## marker at the lock energy of the dial console's address, so the player sees at a glance
## whether the bank holds enough. The marker is a vertical line with a triangular head, never
## colour alone; the console's charge line says the energy in words.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#the-dial-console, game-design.md#core-loop

const _MARKER_WIDTH: float = 3.0
const _HEAD_SIZE: float = 7.0

var _simulation: Simulation = null
var _address: GateAddress = null

@onready var _bar: ProgressBar = %Bar
@onready var _marker: Control = %Marker
@onready var _values: Label = %Values


func _ready() -> void:
	_marker.draw.connect(_draw_marker)
	_marker.resized.connect(_marker.queue_redraw)
	_refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Connects the gauge to [param simulation]; no marker is shown.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_address = null
	if is_node_ready():
		_refresh()


## Puts the marker at the lock energy of [param address]; null hides it.
func set_marker_address(address: GateAddress) -> void:
	_address = address
	if is_node_ready():
		_refresh()


## Returns the energy the marker stands for in MWh, or -1.0 when there is no marker.
func get_marker_mwh() -> float:
	if _simulation == null or _address == null or not _address.is_well_formed():
		return -1.0
	return GateQueries.lock_energy_mwh(_simulation.state, _address)


## Returns the bar's current value in MWh.
func get_bar_value() -> float:
	return _bar.value


## Returns the "stored / capacity" text.
func get_values_text() -> String:
	return _values.text


## Returns the marker's x position in a bar [param width] pixels wide for [param needed_mwh]
## of [param capacity_mwh]: proportional, and stopped at the right edge when the energy is
## more than the bank can hold. Zero when there is no capacity.
static func marker_x(width: float, needed_mwh: float, capacity_mwh: float) -> float:
	if capacity_mwh <= 0.0:
		return 0.0
	return width * clampf(needed_mwh / capacity_mwh, 0.0, 1.0)


func _refresh() -> void:
	if _simulation == null:
		_bar.value = 0.0
		_values.text = ""
		_marker.queue_redraw()
		return
	var power: PowerState = _simulation.state.power
	_bar.max_value = maxf(power.capacity_mwh, 1.0)
	_bar.value = power.stored_mwh
	_values.text = (
		tr("GATE_GAUGE_VALUES")
		. format(
			{
				"stored": GateRoomFormat.energy(power.stored_mwh),
				"capacity": GateRoomFormat.energy(power.capacity_mwh),
			}
		)
	)
	_marker.queue_redraw()


func _draw_marker() -> void:
	var needed: float = get_marker_mwh()
	if needed < 0.0 or _simulation == null:
		return
	var x: float = marker_x(_marker.size.x, needed, _simulation.state.power.capacity_mwh)
	var color: Color = get_theme_color(&"font_color", &"Label")
	_marker.draw_line(Vector2(x, 0.0), Vector2(x, _marker.size.y), color, _MARKER_WIDTH)
	var head := PackedVector2Array(
		[Vector2(x - _HEAD_SIZE, 0.0), Vector2(x + _HEAD_SIZE, 0.0), Vector2(x, _HEAD_SIZE * 1.5)]
	)
	_marker.draw_colored_polygon(head, color)


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_refresh()
