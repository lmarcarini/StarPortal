class_name RoomIcon
extends RefCounted
## Small code-drawn room-type icons for the base plan: a few strokes each, in one colour,
## drawn at a centre and size in plan pixels. Unknown types get a plain square.
## Bible: docs/content/interface-pass.md section 5 (The plan)

## Every room type with its own icon.
const TYPES: Array[StringName] = [
	&"room_gate",
	&"room_control",
	&"room_quarters",
	&"room_research_lab",
	&"room_power_plant",
	&"room_capacitor_bank",
	&"room_workshop",
	&"room_infirmary",
	&"room_artefact_vault",
	&"room_containment",
	&"room_lift",
	&"room_stairs",
]
const _W: float = 1.5


## Draws the icon of [param def_id] centred on [param centre], [param size] plan pixels wide.
static func draw(
	canvas: CanvasItem, centre: Vector2, size: float, def_id: StringName, ink: Color
) -> void:
	var r: float = size * 0.5
	match def_id:
		&"room_gate":
			canvas.draw_arc(centre, r * 0.85, 0.0, TAU, 20, ink, _W, true)
			canvas.draw_circle(centre, r * 0.3, ink)
		&"room_control":
			canvas.draw_rect(
				Rect2(centre - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), ink, false, _W
			)
			canvas.draw_line(
				centre + Vector2(-r * 0.5, r * 0.2), centre + Vector2(r * 0.5, r * 0.2), ink, _W
			)
		&"room_quarters":
			canvas.draw_rect(
				Rect2(centre - Vector2(r, r * 0.4), Vector2(r * 2, r * 0.9)), ink, false, _W
			)
			canvas.draw_rect(Rect2(centre - Vector2(r, r * 0.4), Vector2(r * 0.6, r * 0.5)), ink)
		&"room_research_lab":
			_triangle(canvas, centre, r, ink)
		&"room_power_plant":
			_bolt(canvas, centre, r, ink)
		&"room_capacitor_bank":
			for index: int in 3:
				var x: float = -r + index * r * 0.8 + r * 0.2
				canvas.draw_rect(
					Rect2(centre + Vector2(x, -r * 0.8), Vector2(r * 0.4, r * 1.6)), ink
				)
		&"room_workshop":
			canvas.draw_line(
				centre + Vector2(-r, r), centre + Vector2(r * 0.4, -r * 0.4), ink, _W * 1.4
			)
			canvas.draw_circle(centre + Vector2(r * 0.5, -r * 0.5), r * 0.4, ink)
		&"room_infirmary":
			canvas.draw_rect(Rect2(centre - Vector2(r * 0.3, r), Vector2(r * 0.6, r * 2)), ink)
			canvas.draw_rect(Rect2(centre - Vector2(r, r * 0.3), Vector2(r * 2, r * 0.6)), ink)
		&"room_artefact_vault":
			canvas.draw_rect(Rect2(centre - Vector2(r, r), Vector2(r * 2, r * 2)), ink, false, _W)
			canvas.draw_arc(centre, r * 0.5, 0.0, TAU, 12, ink, _W, true)
		&"room_containment":
			for side: float in [-0.6, 0.0, 0.6]:
				canvas.draw_line(
					centre + Vector2(side * r, -r), centre + Vector2(side * r, r), ink, _W
				)
			canvas.draw_rect(Rect2(centre - Vector2(r, r), Vector2(r * 2, r * 2)), ink, false, _W)
		&"room_lift":
			_triangle(canvas, centre - Vector2(0, r * 0.45), r * 0.55, ink)
			_triangle(canvas, centre + Vector2(0, r * 0.45), -r * 0.55, ink)
		&"room_stairs":
			var points := PackedVector2Array()
			for step: int in 4:
				var x: float = -r + step * r * 0.5
				var y: float = r - step * r * 0.5
				points.append_array([centre + Vector2(x, y), centre + Vector2(x + r * 0.5, y)])
			canvas.draw_polyline(points, ink, _W)
		_:
			canvas.draw_rect(
				Rect2(centre - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), ink, false, _W
			)


## True when [param def_id] has its own icon (not the plain square).
static func has_icon(def_id: StringName) -> bool:
	return TYPES.has(def_id)


## A triangle pointing up (down when [param r] is negative).
static func _triangle(canvas: CanvasItem, centre: Vector2, r: float, ink: Color) -> void:
	var points := PackedVector2Array(
		[centre + Vector2(0, -r), centre + Vector2(absf(r), r), centre + Vector2(-absf(r), r)]
	)
	canvas.draw_colored_polygon(points, ink)


static func _bolt(canvas: CanvasItem, centre: Vector2, r: float, ink: Color) -> void:
	var points := PackedVector2Array(
		[
			centre + Vector2(r * 0.2, -r),
			centre + Vector2(-r * 0.6, r * 0.1),
			centre + Vector2(0, r * 0.1),
			centre + Vector2(-r * 0.2, r),
			centre + Vector2(r * 0.6, -r * 0.1),
			centre + Vector2(0, -r * 0.1),
		]
	)
	canvas.draw_colored_polygon(points, ink)
