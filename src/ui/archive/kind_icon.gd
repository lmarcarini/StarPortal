class_name KindIcon
extends Control
## A small line drawing of a document's kind, so the kind reads by shape: a page of lines
## (note), a framed picture (image), a folder (dossier), a tape reel (log), a tied box (gift)
## or a carved diamond (artefact). Placeholder art drawn in the font colour.
## Bible: art-and-audio.md#ui-and-typography, game-design.md#difficulty-and-accessibility

## The DocumentDef.Kind drawn.
var kind: int = DocumentDef.Kind.NOTE:
	set(value):
		kind = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(22, 22)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, size).grow(-3.0)
	var color: Color = get_theme_color(&"font_color", &"Label")
	match kind:
		DocumentDef.Kind.IMAGE:
			_draw_image(box, color)
		DocumentDef.Kind.DOSSIER:
			_draw_dossier(box, color)
		DocumentDef.Kind.LOG:
			_draw_log(box, color)
		DocumentDef.Kind.GIFT:
			_draw_gift(box, color)
		DocumentDef.Kind.ARTEFACT:
			_draw_artefact(box, color)
		_:
			_draw_note(box, color)


func _draw_note(box: Rect2, color: Color) -> void:
	var page: Rect2 = box.grow_individual(-box.size.x * 0.15, 0.0, -box.size.x * 0.15, 0.0)
	draw_rect(page, color, false, 1.5)
	for row: int in 3:
		var y: float = page.position.y + page.size.y * (0.3 + 0.2 * row)
		draw_line(Vector2(page.position.x + 3.0, y), Vector2(page.end.x - 3.0, y), color, 1.0)


func _draw_image(box: Rect2, color: Color) -> void:
	draw_rect(box, color, false, 1.5)
	var base: float = box.end.y - 3.0
	var peak: Vector2 = Vector2(box.position.x + box.size.x * 0.4, box.position.y + 5.0)
	draw_polyline(
		[Vector2(box.position.x + 3.0, base), peak, Vector2(box.end.x - 3.0, base)], color, 1.5
	)


func _draw_dossier(box: Rect2, color: Color) -> void:
	var body: Rect2 = box.grow_individual(0.0, -box.size.y * 0.2, 0.0, 0.0)
	draw_rect(body, color, false, 1.5)
	var tab: Rect2 = Rect2(box.position, Vector2(box.size.x * 0.45, box.size.y * 0.2))
	draw_rect(tab, color, true)


func _draw_log(box: Rect2, color: Color) -> void:
	var radius: float = box.size.x * 0.22
	var left: Vector2 = Vector2(box.position.x + radius, box.get_center().y)
	var right: Vector2 = Vector2(box.end.x - radius, box.get_center().y)
	draw_arc(left, radius, 0.0, TAU, 16, color, 1.5)
	draw_arc(right, radius, 0.0, TAU, 16, color, 1.5)
	draw_line(left + Vector2(0, radius), right + Vector2(0, radius), color, 1.5)


func _draw_gift(box: Rect2, color: Color) -> void:
	draw_rect(box, color, false, 1.5)
	var center: Vector2 = box.get_center()
	draw_line(Vector2(center.x, box.position.y), Vector2(center.x, box.end.y), color, 1.5)
	draw_line(Vector2(box.position.x, center.y), Vector2(box.end.x, center.y), color, 1.5)


func _draw_artefact(box: Rect2, color: Color) -> void:
	var c: Vector2 = box.get_center()
	var half: Vector2 = box.size * 0.5
	var points: PackedVector2Array = [
		c + Vector2(0, -half.y),
		c + Vector2(half.x, 0),
		c + Vector2(0, half.y),
		c - Vector2(half.x, 0)
	]
	points.append(points[0])
	draw_polyline(points, color, 1.5)
