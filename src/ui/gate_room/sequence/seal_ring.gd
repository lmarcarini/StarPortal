class_name SealRing
extends Control
## The Ring drawn as eight seal positions around a circle, seal 1 at the top and the rest
## clockwise. A lit seal is a filled disc and an unlit one a hollow ring, so the state reads by
## shape as well as colour. Each seal changes once, from hollow to filled, and stays: no
## blinking, no pulsing (reduced flashing). Draws only; the dialing sequence sets
## [member lit].
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## game-design.md#difficulty-and-accessibility

## Smallest size the control asks for, in pixels.
const MIN_SIZE: Vector2 = Vector2(200, 200)
const _SEAL_RADIUS: float = 12.0
const _RING_WIDTH: float = 2.0
const _MARGIN: float = 16.0
const _RING_ALPHA: float = 0.5
const _ARC_POINTS: int = 48

## Seals lit, 0 to [constant GateAddress.SEAL_COUNT].
var lit: int = 0:
	set(value):
		lit = clampi(value, 0, GateAddress.SEAL_COUNT)
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return MIN_SIZE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - _MARGIN
	if radius <= _SEAL_RADIUS:
		return
	var color: Color = get_theme_color(&"font_color", &"Label")
	draw_arc(center, radius, 0.0, TAU, _ARC_POINTS, Color(color, _RING_ALPHA), _RING_WIDTH)
	for index: int in GateAddress.SEAL_COUNT:
		var spot: Vector2 = center + Vector2.from_angle(seal_angle(index)) * radius
		if index < lit:
			draw_circle(spot, _SEAL_RADIUS, color)
		else:
			draw_arc(spot, _SEAL_RADIUS, 0.0, TAU, _ARC_POINTS, color, _RING_WIDTH)


## Returns the angle in radians of seal [param index] (0 for seal 1, at the top), clockwise.
static func seal_angle(index: int) -> float:
	return -PI / 2.0 + TAU * float(index) / float(GateAddress.SEAL_COUNT)
