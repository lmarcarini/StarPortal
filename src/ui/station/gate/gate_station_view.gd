class_name GateStationView
extends GameView
## The Gate station: the Gate hall plate with the Ring's live layers, and the console along
## the bottom. Enter or (A) on the station (not on another control) presses the main key.
## Becomes the Gate tab's view when the old Gate Room retires (M4.9-14).
## Bible: docs/content/interface-rethink.md section 4 (Gate)

## The console asked to build a capacitor bank (open the Base).
signal capacitor_bank_requested

## The station def shown.
const STATION_ID: StringName = &"station_gate"
const _TITLE_KEY: StringName = &"STATION_GATE_TITLE"

var _simulation: Simulation = null
var _ring: RingLayer = null

@onready var _station: StationScene = %Station
@onready var _console: GateConsole = %GateConsole


func _ready() -> void:
	_station.setup(Registry.get_def(STATION_ID) as StationSceneDef)
	_console.build_bank_requested.connect(capacitor_bank_requested.emit)


## Reads [param simulation]; the layers snap to its state.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	if _ring == null:
		_ring = RingLayer.install(_station, simulation)
	else:
		_ring.bind(simulation, _station)
	_console.setup(simulation)


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


## The Ring's layer.
func get_ring_layer() -> RingLayer:
	return _ring


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed(&"ui_accept"):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is BaseButton:
		return
	_console.press_main_key()
	get_viewport().set_input_as_handled()
