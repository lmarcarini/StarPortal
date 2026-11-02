class_name PowerMarks
extends RefCounted
## The "no power" mark: a lightning bolt in a ring, struck through. A shape, not only a
## colour, so a room or base without power reads at a glance (bible accessibility rule). Drawn
## on an unlit room on the plan, on an OFF tag of the energy layer and on the power bar.
## Bible: docs/content/m2-base.md sections 3 and 6, game-design.md#difficulty-and-accessibility

## Colour of the mark and its dark backing.
const INK := Color("#e5534b")
const BACKING := Color("#15171a")
## Darkening laid over an unlit room on the plan.
const OFF_SHADE := Color(0.04, 0.05, 0.06, 0.45)


## Draws the mark centred on [param centre], [param size] across.
static func draw_no_power(canvas: CanvasItem, centre: Vector2, size: float) -> void:
	var radius: float = size * 0.5
	var width: float = maxf(1.0, size / 9.0)
	canvas.draw_circle(centre, radius, BACKING)
	canvas.draw_arc(centre, radius - width * 0.5, 0.0, TAU, 20, INK, width)
	var unit: float = radius * 0.6
	var bolt := PackedVector2Array(
		[
			centre + Vector2(0.25, -1.0) * unit,
			centre + Vector2(-0.35, 0.1) * unit,
			centre + Vector2(0.1, 0.1) * unit,
			centre + Vector2(-0.25, 1.0) * unit,
		]
	)
	canvas.draw_polyline(bolt, INK, width)
	var slash: float = (radius - width) * 0.72
	canvas.draw_line(centre + Vector2(-slash, -slash), centre + Vector2(slash, slash), INK, width)
