class_name AnchorOverlay
extends Control
## Debug only: draws every anchor of a station def over its plate (circles, points with their
## names, paths, polygons and rects), to calibrate a plate's data file by eye.
## Bible: docs/content/interface-rethink.md section 7 (plate plus live layers)

const _COLOUR: Color = Color(1.0, 0.2, 0.8, 0.9)

var _def: StationSceneDef = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Draws [param def]'s anchors.
func setup(def: StationSceneDef) -> void:
	_def = def
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _def == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	for c: Vector3 in _def.circles.values():
		var centre: Vector2 = PlateSpace.to_screen(_def, rect, Vector2(c.x, c.y))
		draw_arc(centre, PlateSpace.to_screen_length(_def, rect, c.z), 0, TAU, 128, _COLOUR, 1.0)
	for key: StringName in _def.points:
		var p: Vector2 = PlateSpace.to_screen(_def, rect, _def.points[key])
		draw_circle(p, 4.0, _COLOUR)
		draw_string(get_theme_default_font(), p + Vector2(6, -6), String(key))
	for line: PackedVector2Array in _def.paths.values():
		draw_polyline(PlateSpace.to_screen_all(_def, rect, line), _COLOUR, 2.0)
	for poly: PackedVector2Array in _def.polygons.values():
		var pts: PackedVector2Array = PlateSpace.to_screen_all(_def, rect, poly)
		pts.append(pts[0])
		draw_polyline(pts, _COLOUR, 1.0)
	for r: Rect2 in _def.rects.values():
		var a: Vector2 = PlateSpace.to_screen(_def, rect, r.position)
		draw_rect(Rect2(a, PlateSpace.to_screen(_def, rect, r.end) - a), _COLOUR, false, 1.0)
