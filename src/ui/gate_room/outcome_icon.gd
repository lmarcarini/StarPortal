class_name OutcomeIcon
extends Control
## Draws the icon of one dial outcome. Each outcome has its own shape, so the result reads
## without colour: a cross (No gate), a filled square (Blocked), a hollow triangle (Origin
## rejected), a filled circle (Lock) and a filled diamond (Hostile lock). Colour comes from the
## theme's Label font colour only.
## Bible: game-design.md#difficulty-and-accessibility (status by shape as well as colour)

## Shape names, indexed by DialOutcome.Kind.
const SHAPES: Array[StringName] = [&"cross", &"square", &"triangle", &"circle", &"diamond"]
## Smallest size the control asks for, in pixels.
const MIN_SIZE: Vector2 = Vector2(32, 32)
## Share of the control's smaller side the shape fills.
const FILL_RATIO: float = 0.7
const _STROKE: float = 3.0

## The outcome to draw: a DialOutcome.Kind value, or -1 to draw nothing.
var kind: int = -1:
	set(value):
		kind = value
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return MIN_SIZE


func _draw() -> void:
	var shape: StringName = shape_of(kind)
	var side: float = minf(size.x, size.y) * FILL_RATIO
	var center: Vector2 = size / 2.0
	var half: float = side / 2.0
	var color: Color = get_theme_color(&"font_color", &"Label")
	match shape:
		&"cross":
			draw_line(center + Vector2(-half, -half), center + Vector2(half, half), color, _STROKE)
			draw_line(center + Vector2(-half, half), center + Vector2(half, -half), color, _STROKE)
		&"square":
			draw_rect(Rect2(center - Vector2(half, half), Vector2(side, side)), color)
		&"triangle":
			var corners: PackedVector2Array = _triangle(center, half)
			corners.append(corners[0])
			draw_polyline(corners, color, _STROKE)
		&"circle":
			draw_circle(center, half, color)
		&"diamond":
			draw_colored_polygon(_diamond(center, half), color)


## Returns the shape name of outcome [param outcome_kind]; empty for a value outside the enum.
static func shape_of(outcome_kind: int) -> StringName:
	if outcome_kind < 0 or outcome_kind >= SHAPES.size():
		return &""
	return SHAPES[outcome_kind]


static func _triangle(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array(
		[center + Vector2(0, -half), center + Vector2(half, half), center + Vector2(-half, half)]
	)


static func _diamond(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			center + Vector2(0, -half),
			center + Vector2(half, 0),
			center + Vector2(0, half),
			center + Vector2(-half, 0),
		]
	)
