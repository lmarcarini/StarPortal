class_name RefPen
extends RefCounted
## A pen for one reference icon: the canvas, the icon's centre and half size, the ink, and
## line, ellipse and fill helpers in units of the half size.
## Bible: docs/content/interface-reference.md section 3 (Icons)

var item: CanvasItem = null
var c: Vector2 = Vector2.ZERO
var r: float = 1.0
var ink: Color = Color.WHITE
var width: float = RefIcons.STROKE


## The point at ([param x], [param y]) half sizes from the centre.
func at(x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * r


## A polyline through [param pts], each a pair of half-size units.
func line(pts: Array[Vector2]) -> void:
	var points: PackedVector2Array = []
	for p: Vector2 in pts:
		points.append(at(p.x, p.y))
	item.draw_polyline(points, ink, width, true)


## An ellipse outline in the box from ([param a]) to ([param b]), in half-size units.
func ellipse(a: Vector2, b: Vector2) -> void:
	arc(a, b, 0.0, 360.0)


## An elliptic arc in the box [param a]..[param b] from [param from] to [param to] degrees
## (clockwise from 3 o'clock, as PIL).
func arc(a: Vector2, b: Vector2, from: float, to: float) -> void:
	var centre: Vector2 = at((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
	var radii: Vector2 = Vector2(absf(b.x - a.x), absf(b.y - a.y)) * r * 0.5
	radii -= Vector2(width, width) * 0.5
	var points: PackedVector2Array = []
	var steps: int = maxi(8, int(absf(to - from) / 8.0))
	for i: int in steps + 1:
		var angle: float = deg_to_rad(lerpf(from, to, float(i) / steps))
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	item.draw_polyline(points, ink, width, true)


## A filled polygon through [param pts] (half-size units).
func fill(pts: Array[Vector2]) -> void:
	var points: PackedVector2Array = []
	for p: Vector2 in pts:
		points.append(at(p.x, p.y))
	item.draw_colored_polygon(points, ink)


## A polygon outline through [param pts], closed.
func shape(pts: Array[Vector2]) -> void:
	var closed: Array[Vector2] = pts.duplicate()
	closed.append(pts[0])
	line(closed)


## A rectangle outline from [param a] to [param b].
func box(a: Vector2, b: Vector2) -> void:
	shape([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


## A filled rectangle from [param a] to [param b].
func solid(a: Vector2, b: Vector2) -> void:
	fill([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
