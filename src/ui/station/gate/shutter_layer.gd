class_name ShutterLayer
extends Control
## The Shutter seen over the Ring's hole: eight steel iris blades that close from the rim to
## the centre as the [RingLayer]'s shutter amount rises.
## Bible: docs/content/interface-rethink.md section 4 (Gate, the Shutter)

const _BLADES: int = 12
const _STEEL: Color = Color("#5a5750")
const _EDGE: Color = Color("#24221f")

var _ring: RingLayer = null
var _station: StationScene = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Follows [param ring] over [param station].
func bind(ring: RingLayer, station: StationScene) -> void:
	_ring = ring
	_station = station


func _process(_delta: float) -> void:
	visible = _ring != null and _ring.shutter_amount > 0.0
	queue_redraw()


func _draw() -> void:
	if _ring == null or _station == null:
		return
	var k: float = _ring.shutter_amount
	var c: Vector2 = _station.anchor(&"ring_inner")
	var r: float = _station.radius(&"ring_inner") + 2.0
	var hole: float = r * (1.0 - k)
	for i: int in _BLADES:
		var a0: float = TAU * i / _BLADES
		var a1: float = a0 + TAU / _BLADES
		var twist: float = 0.6 * (1.0 - k)
		var pts: PackedVector2Array = PackedVector2Array()
		for step: int in 5:
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, step / 4.0)) * r)
		pts.append(c + Vector2.from_angle((a0 + a1) * 0.5 + twist) * hole)
		draw_colored_polygon(pts, _STEEL.darkened(0.05 * (i % 2)))
		draw_polyline(pts, _EDGE, 2.0)
