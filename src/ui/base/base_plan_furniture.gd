class_name BasePlanFurniture
extends RefCounted
## Thin furniture marks seen from above, one small layout per room type, scaled to the
## room's floor: beds in Quarters, banks in a Capacitor Bank, benches in a lab, the Ring in the
## Gate Room, and so on. Outlines only, in one muted colour, so the plan reads as a schematic.
## The painter draws them from a set zoom up.
## Bible: docs/content/interface-pass.md section 5, docs/content/m2-base.md section 6

const _LINE: float = 1.0


## Draws the furniture of [param def_id] inside [param area] (plan pixels).
static func draw(canvas: CanvasItem, area: Rect2, def_id: StringName) -> void:
	var inner: Rect2 = area.grow(-area.size.length() * 0.06)
	var ink: Color = BasePlanPainter.FURNITURE
	match def_id:
		&"room_gate":
			_ring(canvas, area, ink)
		&"room_quarters":
			_columns(canvas, inner, 3, ink)
		&"room_capacitor_bank":
			_columns(canvas, inner, 3, ink)
		&"room_power_plant":
			_block(canvas, inner, Rect2(0.15, 0.2, 0.45, 0.6), ink)
			_block(canvas, inner, Rect2(0.7, 0.2, 0.15, 0.6), ink)
		&"room_lift":
			canvas.draw_line(inner.position, inner.end, ink, _LINE)
			canvas.draw_line(
				Vector2(inner.end.x, inner.position.y),
				Vector2(inner.position.x, inner.end.y),
				ink,
				_LINE
			)
		&"room_stairs":
			_rows(canvas, inner, 5, ink)
		_:
			_block(canvas, inner, Rect2(0.1, 0.35, 0.8, 0.15), ink)
			_block(canvas, inner, Rect2(0.1, 0.65, 0.35, 0.2), ink)


## The Ring, flat on the floor seen from above, and its ramp.
static func _ring(canvas: CanvasItem, area: Rect2, ink: Color) -> void:
	var radius: float = minf(area.size.x, area.size.y) * 0.32
	var centre: Vector2 = area.get_center() - Vector2(0, radius * 0.25)
	canvas.draw_arc(centre, radius, 0.0, TAU, 32, ink, _LINE, true)
	canvas.draw_arc(centre, radius * 0.78, 0.0, TAU, 32, ink, _LINE, true)
	var ramp := Rect2(centre + Vector2(-radius * 0.3, radius), Vector2(radius * 0.6, radius * 0.6))
	canvas.draw_rect(ramp, ink, false, _LINE)


## [param count] even upright blocks side by side across [param area].
static func _columns(canvas: CanvasItem, area: Rect2, count: int, ink: Color) -> void:
	for index: int in count:
		_block(canvas, area, Rect2((index + 0.15) / count, 0.35, 0.7 / count, 0.5), ink)


## [param count] even flat blocks stacked down [param area].
static func _rows(canvas: CanvasItem, area: Rect2, count: int, ink: Color) -> void:
	for index: int in count:
		_block(canvas, area, Rect2(0.1, (index + 0.15) / count, 0.8, 0.7 / count), ink)


## An outlined block over [param part] of [param area], as fractions of the area.
static func _block(canvas: CanvasItem, area: Rect2, part: Rect2, ink: Color) -> void:
	var rect := Rect2(area.position + area.size * part.position, area.size * part.size)
	canvas.draw_rect(rect, ink, false, _LINE)
