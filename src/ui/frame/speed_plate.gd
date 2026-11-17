class_name SpeedPlate
extends Control
## The top bar's speed plate (interface-reference.md section 4, top_speed): four 44 px keys,
## pause, play, fast and settings; the current speed's key is amber. Play resumes a paused
## clock and otherwise steps the speed down; fast steps it up (or overrides a slow).
## Bible: docs/content/interface-reference.md section 4

## The settings key was pressed.
signal settings_requested

## Key side and gap, in pixels.
const KEY: float = 44.0
const GAP: float = 4.0

var pause_key: RefKey = RefKey.new()
var play_key: RefKey = RefKey.new()
var fast_key: RefKey = RefKey.new()
var settings_key: RefKey = RefKey.new()

var _time_bar: TimeBar = null


func _init() -> void:
	name = &"SpeedPlate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keys: Dictionary[RefKey, StringName] = {
		pause_key: &"pause", play_key: &"play", fast_key: &"fast", settings_key: &"gear"
	}
	var x: float = 8.0
	for key: RefKey in keys:
		key.icon_id = keys[key]
		key.name = String(keys[key]).capitalize() + "Key"
		key.position = Vector2(x, 8)
		key.size = Vector2(KEY, KEY)
		add_child(key)
		x += KEY + GAP
	pause_key.pressed.connect(SimClock.pause)
	play_key.pressed.connect(play)
	fast_key.pressed.connect(fast)
	settings_key.pressed.connect(settings_requested.emit)


func _ready() -> void:
	pause_key.set_help("FRAME_PAUSE")
	play_key.set_help("FRAME_PLAY")
	fast_key.set_help("FRAME_FAST")
	settings_key.set_help("FRAME_SETTINGS")


## Uses [param bar] for fast (it knows the slow overrides).
func setup(bar: TimeBar) -> void:
	_time_bar = bar


## Play: resumes a paused clock; while running, one speed step slower.
func play() -> void:
	if SimClock.simulation == null:
		return
	if SimClock.simulation.state.clock.is_paused:
		SimClock.resume()
	else:
		SimClock.slower()


## Fast: one speed faster, or overrides a slow (through the time bar).
func fast() -> void:
	if _time_bar != null:
		_time_bar.faster()
	else:
		SimClock.faster()


## Lights the key of the current speed: pause while paused, play at normal speed or slower,
## fast above it.
func refresh() -> void:
	if SimClock.simulation == null:
		return
	var clock: ClockState = SimClock.simulation.state.clock
	var current: RefKey = pause_key
	if not clock.is_paused:
		current = fast_key if clock.speed_index > ClockState.NORMAL_SPEED_INDEX else play_key
	for key: RefKey in [pause_key, play_key, fast_key]:
		key.style = RefPaint.KeyStyle.AMBER if key == current else RefPaint.KeyStyle.STEEL


## The keys in focus order.
func get_buttons() -> Array[Button]:
	return [pause_key, play_key, fast_key, settings_key]


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
