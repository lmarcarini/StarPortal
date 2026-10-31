class_name CameraCue
extends Control
## The short cue on the Ring when the pole camera goes out: a pale ring sweeps from the centre of
## the event horizon to its edge and fades (about a quarter of a second). With reduced flashing
## it is fainter and slower. Placeholder art drawn in code, over the Ring view; takes no input.
## Bible: game-design.md#base-building-and-power (pole camera),
## game-design.md#difficulty-and-accessibility (reduced flashing)

const SECONDS: float = 0.3
const SOFT_SECONDS: float = 0.7
const PEAK: float = 0.9
const SOFT_PEAK: float = 0.3
const _COLOR: Color = Color(0.95, 0.93, 0.85)
const _POINTS: int = 48

var _left: float = 0.0
var _seconds: float = SECONDS
var _peak: float = PEAK


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## Plays the cue from the start.
func play() -> void:
	var is_soft: bool = Settings.get_bool(&"accessibility", &"reduced_flashing")
	_seconds = SOFT_SECONDS if is_soft else SECONDS
	_peak = SOFT_PEAK if is_soft else PEAK
	_left = 1.0
	set_process(true)
	queue_redraw()


## Returns how much of the cue is left, 1 at the start and 0 when done.
func get_left() -> float:
	return _left


## Returns the cue's brightest alpha for the current setting.
func get_peak() -> float:
	return _peak


func _process(delta: float) -> void:
	_left = maxf(0.0, _left - delta / _seconds)
	set_process(_left > 0.0)
	queue_redraw()


func _draw() -> void:
	if _left <= 0.0:
		return
	var radius: float = RingView.horizon_radius(size) * (1.0 - _left * 0.8)
	draw_arc(size / 2.0, radius, 0.0, TAU, _POINTS, Color(_COLOR, _peak * _left), 4.0)
