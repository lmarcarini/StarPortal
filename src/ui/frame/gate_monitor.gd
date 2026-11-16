class_name GateMonitor
extends Button
## The gate monitor, bottom right on every station but the Gate (interface-rethink.md
## section 3): a small CRT showing a live picture of the Ring, drawn by the Gate station's own
## plate and ring layers in a SubViewport, while dialling, open, incoming or a team coming
## home; dark with IDLE otherwise. The Shutter, the hostile tint and an incursion's red show
## as on the Gate. It renders only while shown and something happens: idle it costs nothing.
## A click goes to the Gate.
## Bible: docs/content/interface-rethink.md section 3

## Pixel size of the picture rendered, and of the screen shown.
const RENDER_SIZE: Vector2i = Vector2i(560, 315)
const SCREEN_SIZE: Vector2 = Vector2(224, 126)
## The Gate station def whose plate and layers are drawn.
const STATION_ID: StringName = &"station_gate"
## How much larger than the screen the plate is drawn, so the Ring fills it.
const ZOOM: float = 2.2

## True on every station but the Gate (the shell sets it).
var wanted: bool = true:
	set(value):
		wanted = value
		_update()

var _simulation: Simulation = null
var _crt: CrtMonitor = CrtMonitor.new()
var _viewport: SubViewport = SubViewport.new()
var _picture: TextureRect = TextureRect.new()
var _idle: Label = Label.new()
var _alarm: ColorRect = ColorRect.new()
var _station: StationScene = null
var _active: bool = false


func _init() -> void:
	name = &"GateMonitor"
	flat = true
	custom_minimum_size = SCREEN_SIZE + Vector2(16, 16)
	add_child(_crt)
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.size = RENDER_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.transparent_bg = false
	add_child(_viewport)
	_picture.texture = _viewport.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt.add_child(_picture)
	_alarm.color = Color(UiPalette.ALARM, 0.25)
	_alarm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.add_child(_alarm)
	_alarm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_idle.text = &"FRAME_MONITOR_IDLE"
	_idle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crt.add_child(_idle)


func _ready() -> void:
	HoverCard.attach(self, "FRAME_MONITOR_HINT")
	_station = (load("res://src/ui/station/station_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_station)
	_station.size = Vector2(RENDER_SIZE)
	_station.setup(Registry.get_def(STATION_ID) as StationSceneDef)
	_station.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_station.size = Vector2(RENDER_SIZE) * ZOOM
	_centre_ring.call_deferred()


## Zoomed on the Ring: the plate drawn larger than the screen, the Ring centred.
func _centre_ring() -> void:
	_station.size = Vector2(RENDER_SIZE) * ZOOM
	_station.position = Vector2(RENDER_SIZE) * 0.5 - _station.anchor(&"ring_outer")


## Watches [param simulation]'s Gate (after a start or a load).
func bind(simulation: Simulation) -> void:
	_simulation = simulation
	if _station == null:
		return
	var ring: RingLayer = _station.find_child("RingLayer", true, false) as RingLayer
	if ring == null:
		RingLayer.install(_station, simulation)
	else:
		ring.bind(simulation, _station)
	_update()


## True while the monitor shows a live picture.
func is_live() -> bool:
	return visible and _active


## True while the SubViewport renders.
func is_rendering() -> bool:
	return _viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED


## The look shown now (for tests).
func current_look() -> RingLook:
	if _simulation == null:
		return RingLook.new()
	var state: GameState = _simulation.state
	return RingLook.of(state.gate, state.clock.tick, state.balance.dial_duration_ticks)


func _process(_delta: float) -> void:
	_update()


## Shows, renders and tints from the state.
func _update() -> void:
	visible = wanted
	_active = _simulation != null and is_active(_simulation.state)
	var live: bool = visible and _active
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	)
	if _station != null:
		_station.process_mode = Node.PROCESS_MODE_INHERIT if live else Node.PROCESS_MODE_DISABLED
	_picture.visible = live
	_idle.visible = not live
	_alarm.visible = live and _simulation.state.incursion.is_active()


## True when the Ring of [param state] is doing something worth showing: dialling, open,
## an incoming wormhole waiting, or an incursion.
static func is_active(state: GameState) -> bool:
	var gate: GateState = state.gate
	if gate.mode != GateState.RingMode.IDLE or gate.has_incoming():
		return true
	return state.incursion.is_active()
