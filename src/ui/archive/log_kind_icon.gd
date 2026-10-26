class_name LogKindIcon
extends Control
## A small line drawing of an operations log entry's kind, so the kind reads by shape: a dial
## ring (dial), a filled ring (lock), a crossed ring (close), a page (document), a screen
## (console), a horizon line under a sun (horizon) or a lightning bolt (power). Placeholder art
## drawn in the font colour.
## Bible: game-design.md#core-loop, game-design.md#difficulty-and-accessibility

## The LogEntry kind drawn.
var kind: StringName = &"dial":
	set(value):
		kind = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(22, 22)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, size).grow(-3.0)
	var color: Color = get_theme_color(&"font_color", &"Label")
	var center: Vector2 = box.get_center()
	var radius: float = minf(box.size.x, box.size.y) * 0.5
	match kind:
		&"lock":
			draw_arc(center, radius, 0.0, TAU, 20, color, 1.5)
			draw_circle(center, radius * 0.55, color)
		&"close":
			draw_arc(center, radius, 0.0, TAU, 20, color, 1.5)
			var half: Vector2 = Vector2(radius, radius) * 0.5
			draw_line(center - half, center + half, color, 1.5)
			draw_line(
				center + Vector2(half.x, -half.y), center - Vector2(half.x, -half.y), color, 1.5
			)
		&"document":
			_draw_page(box, color)
		&"console":
			_draw_screen(box, color)
		&"horizon":
			draw_line(Vector2(box.position.x, center.y), Vector2(box.end.x, center.y), color, 1.5)
			draw_arc(center, radius * 0.5, PI, TAU, 10, color, 1.5)
		&"power":
			_draw_bolt(box, color)
		_:
			draw_arc(center, radius, 0.0, TAU, 20, color, 1.5)
			draw_arc(center, radius * 0.55, 0.0, TAU, 16, color, 1.0)


func _draw_page(box: Rect2, color: Color) -> void:
	var page: Rect2 = box.grow_individual(-box.size.x * 0.15, 0.0, -box.size.x * 0.15, 0.0)
	draw_rect(page, color, false, 1.5)
	for row: int in 3:
		var y: float = page.position.y + page.size.y * (0.3 + 0.2 * row)
		draw_line(Vector2(page.position.x + 3.0, y), Vector2(page.end.x - 3.0, y), color, 1.0)


func _draw_screen(box: Rect2, color: Color) -> void:
	var screen: Rect2 = box.grow_individual(0.0, 0.0, 0.0, -box.size.y * 0.25)
	draw_rect(screen, color, false, 1.5)
	var foot: float = box.end.y - 1.0
	draw_line(Vector2(box.position.x + 4.0, foot), Vector2(box.end.x - 4.0, foot), color, 1.5)


func _draw_bolt(box: Rect2, color: Color) -> void:
	var w: float = box.size.x
	var h: float = box.size.y
	var o: Vector2 = box.position
	var points: PackedVector2Array = [
		o + Vector2(w * 0.6, 0.0),
		o + Vector2(w * 0.25, h * 0.55),
		o + Vector2(w * 0.55, h * 0.55),
		o + Vector2(w * 0.4, h),
	]
	draw_polyline(points, color, 1.5)
