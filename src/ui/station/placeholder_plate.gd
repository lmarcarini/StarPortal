class_name PlaceholderPlate
extends Control
## A code-drawn stand-in plate for a station def with no picture: a dark hall with a floor
## line and the def's circles and rects drawn as plain shapes, so layers still line up.
## Bible: docs/content/interface-rethink.md section 7 (plate plus live layers)

const _WALL: Color = Color("#1c1d1b")
const _FLOOR: Color = Color("#262521")
const _SHAPE: Color = Color("#4a4a44")

var _def: StationSceneDef = null


## Draws [param def]'s shapes; queues a redraw.
func setup(def: StationSceneDef) -> void:
	_def = def
	queue_redraw()


func _draw() -> void:
	if _def == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, _WALL)
	var floor_y: float = PlateSpace.to_screen(_def, rect, Vector2(0, _def.plate_size.y * 0.66)).y
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), _FLOOR)
	for c: Vector3 in _def.circles.values():
		var centre: Vector2 = PlateSpace.to_screen(_def, rect, Vector2(c.x, c.y))
		var r: float = PlateSpace.to_screen_length(_def, rect, c.z)
		draw_arc(centre, r, 0.0, TAU, 96, _SHAPE, 3.0)
	for r2: Rect2 in _def.rects.values():
		var a: Vector2 = PlateSpace.to_screen(_def, rect, r2.position)
		var b: Vector2 = PlateSpace.to_screen(_def, rect, r2.end)
		draw_rect(Rect2(a, b - a), _SHAPE, false, 2.0)
