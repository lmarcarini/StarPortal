class_name RingLayer
extends Control
## The Ring's live layer over the Gate plate: a seal lamp on each clamp, lit as its seal locks
## (a failed dial flashes them and goes dark), and the shared animation the horizon, light
## and Shutter layers read: [member open_amount] grows from the centre over about a second on
## a lock and shrinks on a close. Reads the simulation's state only.
## Bible: docs/content/interface-rethink.md sections 4 (Gate) and 7

## Seconds the horizon takes to grow or shrink.
const OPEN_SECONDS: float = 1.0
## Seconds a failed dial's lamps flash.
const FAIL_SECONDS: float = 0.8
## Lamp colours: lit amber, the Ring's blue once open.
const LAMP_LIT: Color = Color("#ffb347")
const LAMP_OFF: Color = Color("#3a3128")

## How open the horizon is, 0 to 1.
var open_amount: float = 0.0
## Seconds of shimmer so far (frozen when motion is reduced).
var shimmer: float = 0.0
## The look being animated towards.
var look: RingLook = RingLook.new()
## How closed the Shutter is, 0 to 1.
var shutter_amount: float = 0.0

var _simulation: Simulation = null
var _station: StationScene = null
var _fail_left: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


## Follows [param simulation]'s Gate, drawn over [param station]. Snaps to the state.
func bind(simulation: Simulation, station: StationScene) -> void:
	_simulation = simulation
	_station = station
	_read()
	open_amount = 1.0 if look.phase == RingLook.Phase.OPEN else 0.0
	shutter_amount = 1.0 if look.shutter_closed else 0.0
	queue_redraw()


## Moves the animation on by [param delta] real seconds.
func advance(delta: float) -> void:
	_read()
	var target: float = 1.0 if look.phase == RingLook.Phase.OPEN else 0.0
	open_amount = move_toward(open_amount, target, delta / OPEN_SECONDS)
	shutter_amount = move_toward(shutter_amount, 1.0 if look.shutter_closed else 0.0, delta)
	if Settings.get_bool(&"display", &"ambient_movement"):
		shimmer += delta
	_fail_left = maxf(0.0, _fail_left - delta)
	queue_redraw()


## True while a failed dial's lamps flash.
func is_flashing_failure() -> bool:
	return _fail_left > 0.0


func _process(delta: float) -> void:
	advance(delta)


func _read() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var ticks: int = state.balance.dial_duration_ticks if state.balance != null else 1
	look = RingLook.of(state.gate, state.clock.tick, ticks)


func _on_dial_resolved(outcome: int, _key: String) -> void:
	if not DialOutcome.is_lock(outcome as DialOutcome.Kind):
		_fail_left = FAIL_SECONDS


func _draw() -> void:
	if _station == null:
		return
	var r: float = maxf(4.0, _station.radius(&"ring_outer") * 0.05)
	for i: int in RingLook.SEALS:
		var at: Vector2 = _station.anchor(StringName("clamp_%d" % i))
		var lit: bool = i < look.seals
		if look.phase == RingLook.Phase.INCOMING:
			lit = int(shimmer * 6.0) % RingLook.SEALS == i or i == 0
		if _fail_left > 0.0:
			lit = int(_fail_left * 8.0) % 2 == 0
		draw_circle(at, r * 1.3, Color(0, 0, 0, 0.6))
		draw_circle(at, r, LAMP_LIT if lit else LAMP_OFF)
		if lit:
			draw_circle(at, r * 2.4, Color(LAMP_LIT, 0.22))


## Adds the Ring's layers to [param station] for [param simulation]: the hall light, the
## horizon, the Shutter and the seal lamps, in that order. Returns the ring layer.
static func install(station: StationScene, simulation: Simulation) -> RingLayer:
	var ring: RingLayer = RingLayer.new()
	ring.name = "RingLayer"
	var light: GateLightLayer = GateLightLayer.new()
	light.name = "GateLight"
	var horizon: HorizonLayer = HorizonLayer.new()
	horizon.name = "Horizon"
	var shutter: ShutterLayer = ShutterLayer.new()
	shutter.name = "Shutter"
	station.add_layer(light, 10)
	station.add_layer(horizon, 20)
	station.add_layer(shutter, 30)
	station.add_layer(ring, 40)
	ring.bind(simulation, station)
	light.bind(ring, station)
	horizon.bind(ring, station)
	shutter.bind(ring, station)
	return ring
