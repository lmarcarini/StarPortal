class_name SecurityMarks
extends RefCounted
## The shapes of the security layer (M4c-11): a squad's numbered square tag, an intruder
## group's red diamond with its count, a fading hollow diamond where a group was last seen,
## and the objective's target mark. Every mark has a shape as well as a colour.
## Bible: docs/content/m4c-incursions.md section 7

const _SIZE: float = 9.0


## A squad tag: a filled square with [param number] in it.
static func square(canvas: CanvasItem, at: Vector2, number: int, font: Font, ink: Color) -> void:
	var box := Rect2(at - Vector2(_SIZE, _SIZE), Vector2(_SIZE, _SIZE) * 2.0)
	canvas.draw_rect(box, ink)
	canvas.draw_rect(box, UiPalette.GROUND, false, 1.5)
	_text(canvas, at, str(number), font, UiPalette.GROUND)


## An intruder group: a red diamond with [param count].
static func diamond(canvas: CanvasItem, at: Vector2, count: int, font: Font, filled: bool) -> void:
	var points: PackedVector2Array = _diamond_points(at)
	if filled:
		canvas.draw_colored_polygon(points, UiPalette.ALARM)
		_text(canvas, at, str(count), font, UiPalette.TEXT)
	points.append(points[0])
	canvas.draw_polyline(points, UiPalette.TEXT, 1.5)


## Where a group was last seen: a hollow red diamond at [param alpha].
static func faded(canvas: CanvasItem, at: Vector2, alpha: float) -> void:
	var points: PackedVector2Array = _diamond_points(at)
	points.append(points[0])
	canvas.draw_polyline(points, Color(UiPalette.ALARM, alpha), 2.0)


## The objective room: corner brackets in red round [param cells].
static func target(canvas: CanvasItem, cells: Rect2i) -> void:
	var cell: float = BasePlanPainter.CELL
	var area := Rect2(Vector2(cells.position) * cell, Vector2(cells.size) * cell).grow(-2.0)
	var arm: float = cell * 0.6
	for corner: Vector2 in [
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y)
	]:
		var dx: float = arm if corner.x == area.position.x else -arm
		var dy: float = arm if corner.y == area.position.y else -arm
		canvas.draw_line(corner, corner + Vector2(dx, 0), UiPalette.ALARM, 3.0)
		canvas.draw_line(corner, corner + Vector2(0, dy), UiPalette.ALARM, 3.0)


static func _diamond_points(at: Vector2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			at + Vector2(0, -_SIZE),
			at + Vector2(_SIZE, 0),
			at + Vector2(0, _SIZE),
			at + Vector2(-_SIZE, 0)
		]
	)


static func _text(canvas: CanvasItem, at: Vector2, text: String, font: Font, ink: Color) -> void:
	var font_size: int = 11
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(
		font, at + Vector2(-width * 0.5, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink
	)
