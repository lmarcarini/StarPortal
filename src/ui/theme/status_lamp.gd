class_name StatusLamp
extends Control
## A status lamp: colour plus shape, so no status is told by colour alone.
## good: green disc; warn: amber triangle; alarm: red filled square; off: dim ring.
## Lit statuses glow softly. Presentation only.
## Bible: docs/content/interface-pass.md section 2

## Every status the lamp can show.
const STATUSES: Array[StringName] = [&"good", &"warn", &"alarm", &"off"]

var _status: StringName = &"off"


func _init() -> void:
	custom_minimum_size = Vector2(16, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param status], one of [constant STATUSES]. Anything else is ignored with a warning.
func set_status(status: StringName) -> void:
	if not STATUSES.has(status):
		push_warning("StatusLamp: unknown status '%s'" % status)
		return
	_status = status
	queue_redraw()


## The status shown now.
func get_status() -> StringName:
	return _status


## The colour of [param status].
static func color_of(status: StringName) -> Color:
	match status:
		&"good":
			return UiPalette.GOOD
		&"warn":
			return UiPalette.WARN
		&"alarm":
			return UiPalette.ALARM
	return UiPalette.TEXT_DIM


## The shape name of [param status]: disc, triangle, square or ring.
static func shape_of(status: StringName) -> StringName:
	match status:
		&"good":
			return &"disc"
		&"warn":
			return &"triangle"
		&"alarm":
			return &"square"
	return &"ring"


## A small texture of [param status]'s lamp, [param side] pixels square, for button icons.
static func icon(status: StringName, side: int) -> ImageTexture:
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var color: Color = color_of(status)
	var shape: StringName = shape_of(status)
	var r: float = side * 0.42
	for y: int in side:
		for x: int in side:
			var p := Vector2(x + 0.5 - side / 2.0, y + 0.5 - side / 2.0)
			if _covers(shape, p, r):
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _covers(shape: StringName, p: Vector2, r: float) -> bool:
	match shape:
		&"disc":
			return p.length() <= r
		&"square":
			return absf(p.x) <= r * 0.85 and absf(p.y) <= r * 0.85
		&"triangle":
			var depth: float = (p.y + r) / (2.0 * r)
			return depth >= 0.0 and depth <= 1.0 and absf(p.x) <= depth * r
	return p.length() <= r and p.length() >= r - 2.0


func _draw() -> void:
	var color: Color = color_of(_status)
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) * 0.35
	if _status != &"off":
		draw_circle(center, radius * 1.45, Color(color, 0.18))
	match shape_of(_status):
		&"disc":
			draw_circle(center, radius, color)
		&"triangle":
			var points := PackedVector2Array(
				[
					center + Vector2(0, -radius * 1.1),
					center + Vector2(radius * 1.1, radius * 0.85),
					center + Vector2(-radius * 1.1, radius * 0.85),
				]
			)
			draw_colored_polygon(points, color)
		&"square":
			var side: float = radius * 1.7
			draw_rect(Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), color)
		_:
			draw_arc(center, radius, 0.0, TAU, 24, color, 2.0, true)
