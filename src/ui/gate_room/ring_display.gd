class_name RingDisplay
extends Control
## The Ring as eight seal positions around a circle. While the Ring is DIALING the seals light
## one by one, spread over the dial's in-game duration at the current speed; they hold while
## the clock is paused or held. Lit seals are filled and unlit ones hollow, and an open
## wormhole adds a disc in the middle, so the state reads by shape as well as colour. A
## status line gives the same in words. Reads state only.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#time-real-time-with-pause, game-design.md#difficulty-and-accessibility

## Smallest size the control asks for, in pixels.
const MIN_SIZE: Vector2 = Vector2(240, 250)
## Height kept at the bottom for the status line.
const STATUS_HEIGHT: float = 44.0
const _SEAL_RADIUS: float = 12.0
const _RING_WIDTH: float = 2.0
const _MARGIN: float = 20.0
const _RING_ALPHA: float = 0.5
## Share of a tick the animation may fill before the next tick actually arrives.
const _MAX_FRACTION: float = 0.999
const _ARC_POINTS: int = 48

var _simulation: Simulation = null
var _fraction: float = 0.0
var _lit: int = 0

@onready var _status: Label = %Status


func _ready() -> void:
	_refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.dial_started.connect(_on_dial_started)
	EventBus.dial_resolved.connect(_on_dial_resolved)
	EventBus.wormhole_closed.connect(_on_wormhole_closed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.dial_started.disconnect(_on_dial_started)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)
	EventBus.wormhole_closed.disconnect(_on_wormhole_closed)


func _get_minimum_size() -> Vector2:
	return MIN_SIZE


func _process(delta: float) -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var is_dialing: bool = state.gate.mode == GateState.RingMode.DIALING
	if not is_dialing or state.clock.mode != ClockState.Mode.RUNNING:
		return
	var speed: float = SimClock.SPEEDS[clampi(state.clock.speed_index, 0, 3)]
	_fraction = minf(_fraction + delta * speed, _MAX_FRACTION)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var area := Rect2(0.0, 0.0, size.x, maxf(size.y - STATUS_HEIGHT, 0.0))
	var center: Vector2 = area.get_center()
	var radius: float = minf(area.size.x, area.size.y) / 2.0 - _MARGIN
	if radius <= _SEAL_RADIUS:
		return
	var color: Color = get_theme_color(&"font_color", &"Label")
	var faint: Color = Color(color, _RING_ALPHA)
	draw_arc(center, radius, 0.0, TAU, _ARC_POINTS, faint, _RING_WIDTH)
	for index: int in GateAddress.SEAL_COUNT:
		var angle: float = -PI / 2.0 + TAU * float(index) / float(GateAddress.SEAL_COUNT)
		var spot: Vector2 = center + Vector2.from_angle(angle) * radius
		if index < _lit:
			draw_circle(spot, _SEAL_RADIUS, color)
		else:
			draw_arc(spot, _SEAL_RADIUS, 0.0, TAU, _ARC_POINTS, color, _RING_WIDTH)
	if _is_locked():
		draw_circle(center, radius * 0.5, color)


## Connects the display to [param simulation] and shows its Ring.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_fraction = 0.0
	if is_node_ready():
		_refresh()


## Returns how many seals are lit right now.
func get_lit_seals() -> int:
	return _lit


## Returns the status line's text.
func get_status_text() -> String:
	return _status.text


## Returns how many of the [constant GateAddress.SEAL_COUNT] seals are lit after
## [param elapsed_ticks] of a dial lasting [param duration_ticks]. All of them when the
## duration is not positive.
static func lit_seals(elapsed_ticks: float, duration_ticks: int) -> int:
	if duration_ticks <= 0:
		return GateAddress.SEAL_COUNT
	var progress: float = clampf(elapsed_ticks / float(duration_ticks), 0.0, 1.0)
	return floori(progress * GateAddress.SEAL_COUNT)


func _refresh() -> void:
	var lit: int = _compute_lit()
	_lit = lit
	_status.text = _status_text()
	queue_redraw()


func _compute_lit() -> int:
	if _simulation == null:
		return 0
	var state: GameState = _simulation.state
	match state.gate.mode:
		GateState.RingMode.DIALING:
			var elapsed: float = float(state.clock.tick - state.gate.dial_started_tick) + _fraction
			return lit_seals(elapsed, state.balance.dial_duration_ticks)
		GateState.RingMode.LOCKED:
			return GateAddress.SEAL_COUNT
	return 0


func _status_text() -> String:
	var mode: GateState.RingMode = GateState.RingMode.IDLE
	if _simulation != null:
		mode = _simulation.state.gate.mode
	match mode:
		GateState.RingMode.DIALING:
			var text: String = tr("GATE_RING_DIALING")
			return text.format({"lit": _lit, "total": GateAddress.SEAL_COUNT})
		GateState.RingMode.LOCKED:
			return tr("GATE_RING_LOCKED")
	return tr("GATE_RING_IDLE")


func _is_locked() -> bool:
	return _simulation != null and _simulation.state.gate.mode == GateState.RingMode.LOCKED


func _on_tick_advanced(_tick: int) -> void:
	_fraction = 0.0
	_refresh()


func _on_dial_started(_address_key: String) -> void:
	_fraction = 0.0
	_refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_fraction = 0.0
	_refresh()


func _on_wormhole_closed(_reason: StringName) -> void:
	_fraction = 0.0
	_refresh()
