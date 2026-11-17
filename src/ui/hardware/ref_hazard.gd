class_name RefHazard
extends RefCounted
## The hazard key face of the interface reference: yellow-black stripes round a dark face
## (CLOSE, GO), and the hazard lip of the bottom bar.
## Bible: docs/content/interface-reference.md section 3

const _BASE: Color = Color8(30, 28, 22)
const _FACE: Color = Color8(54, 50, 42)
const _FACE_EDGE: Color = Color8(10, 10, 9)
## Stripe period and width, in pixels.
const PERIOD: float = 34.0
const STRIPE: float = 17.0


## The striped face over [param rect], with the dark inner face 14 px in.
static func face(item: CanvasItem, rect: Rect2) -> void:
	var shape: PackedVector2Array = RefPaint.rounded(rect, 6.0)
	item.draw_polygon(shape, [_BASE])
	var h: float = rect.size.y
	var k: float = -h
	while k < rect.size.x + h:
		var stripe: PackedVector2Array = [
			rect.position + Vector2(k, 0),
			rect.position + Vector2(k + STRIPE, 0),
			rect.position + Vector2(k + STRIPE + h, h),
			rect.position + Vector2(k + h, h),
		]
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(stripe, shape):
			item.draw_colored_polygon(piece, RefPaint.HAZARD_YELLOW)
		k += PERIOD
	var inner: Rect2 = rect.grow(-14.0)
	item.draw_polygon(RefPaint.rounded(inner, 4.0), [_FACE])
	RefPaint.outline(item, inner, _FACE_EDGE, 2.0)
