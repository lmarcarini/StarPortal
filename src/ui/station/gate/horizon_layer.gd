class_name HorizonLayer
extends ColorRect
## The event horizon in the Ring's hole, drawn by a shader clipped to the `ring_inner`
## circle, so it fits the hole exactly at every resolution. Reads its amount, shimmer and tint
## from the [RingLayer]; still when motion is reduced. When the horizon starts to open it
## plays the kawoosh: a burst that overshoots outward over about a second, then settles.
## Bible: docs/content/interface-rethink.md section 7; docs/content/presentation-and-systems.md
## section 2

## Seconds the kawoosh lasts.
const BURST_SECONDS: float = 1.1

var _ring: RingLayer = null
## Seconds since the kawoosh began; negative when none plays.
var _burst_age: float = -1.0
var _was_open: float = 0.0
var _station: StationScene = null
var _material: ShaderMaterial = ShaderMaterial.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_material.shader = preload("res://src/ui/station/gate/horizon.gdshader")
	material = _material


## Follows [param ring] over [param station].
func bind(ring: RingLayer, station: StationScene) -> void:
	_ring = ring
	_station = station


## The shader's material (for tests).
func get_shader_material() -> ShaderMaterial:
	return _material


## The kawoosh strength now, 0 to 1: a fast rise and a slower settle.
func burst() -> float:
	return burst_at(_burst_age)


## The kawoosh strength [param age] seconds after it began; 0 outside it.
static func burst_at(age: float) -> float:
	if age < 0.0 or age >= BURST_SECONDS:
		return 0.0
	var t: float = age / BURST_SECONDS
	return sin(PI * sqrt(t)) * (1.0 - t * 0.3)


func _process(delta: float) -> void:
	if _ring == null or _station == null:
		return
	_step_burst(delta)
	visible = _ring.open_amount > 0.0
	_material.set_shader_parameter(&"centre", _station.anchor(&"ring_inner"))
	_material.set_shader_parameter(&"radius", _station.radius(&"ring_inner"))
	_material.set_shader_parameter(&"amount", _ring.open_amount)
	_material.set_shader_parameter(&"time", _ring.shimmer)
	_material.set_shader_parameter(&"burst", burst())
	_material.set_shader_parameter(&"hostile", 1.0 if _ring.look.hostile else 0.0)


## Starts the kawoosh as the horizon begins to open (not with reduced motion) and ages it.
func _step_burst(delta: float) -> void:
	var opening: bool = _was_open <= 0.0 and _ring.open_amount > 0.0
	_was_open = _ring.open_amount
	if opening and Settings.get_bool(&"display", &"ambient_movement"):
		_burst_age = 0.0
	elif _burst_age >= 0.0:
		_burst_age += delta
		if _burst_age >= BURST_SECONDS:
			_burst_age = -1.0
