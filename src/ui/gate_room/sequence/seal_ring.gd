class_name SealRing
extends Control
## The Ring's eight seal lamps, drawn on the outer edge of RingView's band: seal 1 at the top
## and the rest clockwise. A lit lamp is a filled chevron and an unlit one a hollow outline, so
## the state reads by shape as well as colour. Each lamp changes once, from hollow to filled,
## and stays: no blinking, no pulsing (reduced flashing). Draws only; the dialing sequence sets
## [member lit] through RingView.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## game-design.md#difficulty-and-accessibility

## Lamp colours: lit amber, and the outline of an unlit lamp.
const LIT_COLOR: Color = Color(1.0, 0.62, 0.18)
const UNLIT_COLOR: Color = Color(0.55, 0.42, 0.3)
const _LAMP_SHARE: float = 0.13
const _LINE_WIDTH: float = 2.0

## Seals lit, 0 to [constant GateAddress.SEAL_COUNT].
var lit: int = 0:
	set(value):
		lit = clampi(value, 0, GateAddress.SEAL_COUNT)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var outer: float = RingView.outer_radius(size)
	var lamp: float = outer * _LAMP_SHARE
	if lamp <= 1.0:
		return
	var center: Vector2 = size / 2.0
	for index: int in GateAddress.SEAL_COUNT:
		var points: PackedVector2Array = chevron(center, outer, lamp, seal_angle(index))
		if index < lit:
			draw_colored_polygon(points, LIT_COLOR)
		else:
			var loop: PackedVector2Array = points.duplicate()
			loop.append(points[0])
			draw_polyline(loop, UNLIT_COLOR, _LINE_WIDTH, true)


## Returns the angle in radians of seal [param index] (0 for seal 1, at the top), clockwise.
static func seal_angle(index: int) -> float:
	return -PI / 2.0 + TAU * float(index) / float(GateAddress.SEAL_COUNT)


## Returns the three corners of a chevron lamp [param lamp] pixels across, at [param angle]
## on a ring of [param outer] radius around [param center], pointing inwards.
static func chevron(center: Vector2, outer: float, lamp: float, angle: float) -> PackedVector2Array:
	var out: Vector2 = Vector2.from_angle(angle)
	var across: Vector2 = out.orthogonal()
	var base: Vector2 = center + out * (outer + lamp * 0.4)
	return PackedVector2Array(
		[base + across * lamp * 0.6, base - across * lamp * 0.6, base - out * lamp]
	)
