class_name BasePlanFurniture
extends RefCounted
## Simple furniture blocks seen from above, one small layout per room type, scaled to the
## room's floor: beds in Quarters, shelves in the Archive, benches in a lab, the Ring in the
## Gate Room, and so on. Placeholder art drawn in code.
## Bible: docs/content/m2-base.md section 6

const _RING := Color("#7b6a55")
const _RING_INNER := Color("#2b2b25")
const _SHEET := Color("#d9d0b8")
const _BANK := Color("#3e6d4c")
const _ENGINE := Color("#6e5c45")


## Draws the furniture of [param def_id] inside [param area] (plan pixels).
static func draw(canvas: CanvasItem, area: Rect2, def_id: StringName) -> void:
	var inner: Rect2 = area.grow(-area.size.length() * 0.06)
	match def_id:
		&"room_gate":
			_ring(canvas, area)
		&"room_quarters":
			_columns(canvas, inner, 3, _SHEET)
		&"room_capacitor_bank":
			_columns(canvas, inner, 3, _BANK)
		&"room_power_plant":
			_block(canvas, inner, Rect2(0.15, 0.2, 0.45, 0.6), _ENGINE)
			_block(canvas, inner, Rect2(0.7, 0.2, 0.15, 0.6), BasePlanPainter.FURNITURE)
		&"room_lift":
			canvas.draw_line(inner.position, inner.end, BasePlanPainter.WALL, 2.0)
			canvas.draw_line(
				Vector2(inner.end.x, inner.position.y),
				Vector2(inner.position.x, inner.end.y),
				BasePlanPainter.WALL,
				2.0
			)
		&"room_stairs":
			_columns(canvas, inner, 5, BasePlanPainter.CORRIDOR)
		_:
			_block(canvas, inner, Rect2(0.1, 0.1, 0.8, 0.2), BasePlanPainter.FURNITURE)
			_block(canvas, inner, Rect2(0.1, 0.6, 0.35, 0.25), BasePlanPainter.FURNITURE)


## The Ring, flat on the floor seen from above, and its ramp.
static func _ring(canvas: CanvasItem, area: Rect2) -> void:
	var radius: float = minf(area.size.x, area.size.y) * 0.32
	var centre: Vector2 = area.get_center() - Vector2(0, radius * 0.25)
	canvas.draw_circle(centre, radius, _RING)
	canvas.draw_circle(centre, radius * 0.78, _RING_INNER)
	var ramp := Rect2(centre + Vector2(-radius * 0.3, radius), Vector2(radius * 0.6, radius * 0.6))
	canvas.draw_rect(ramp, BasePlanPainter.CORRIDOR)


## [param count] even upright blocks side by side across [param area].
static func _columns(canvas: CanvasItem, area: Rect2, count: int, color: Color) -> void:
	for index: int in count:
		_block(canvas, area, Rect2((index + 0.15) / count, 0.1, 0.7 / count, 0.5), color)


## [param count] even flat blocks stacked down [param area].
static func _rows(canvas: CanvasItem, area: Rect2, count: int, color: Color) -> void:
	for index: int in count:
		_block(canvas, area, Rect2(0.1, (index + 0.15) / count, 0.8, 0.7 / count), color)


## A block over [param part] of [param area], its position and size fractions of the area.
static func _block(canvas: CanvasItem, area: Rect2, part: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(area.position + area.size * part.position, area.size * part.size), color)
