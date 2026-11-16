class_name TabIcon
extends RefCounted
## Code-drawn tab icons, one per view, as small textures: no imported art. Each is a few
## strokes of plain geometry so it reads at 80% UI scale.
## Gate Room: the Ring. Base: a floor plan. Research: a flask. Personnel: a person.
## Archive: stacked papers. Command: a chevron over a bar.
## Bible: docs/content/interface-pass.md sections 2 and 4

## Icon side at 100% UI scale, in pixels.
const BASE_SIZE: int = 26

static var _cache: Dictionary[String, ImageTexture] = {}


## The icon of [param view_id] at UI scale [param scale] in [param color]; null for an
## unknown view.
static func texture(view_id: StringName, scale: float, color: Color) -> ImageTexture:
	var size: int = maxi(roundi(BASE_SIZE * scale), 12)
	var key: String = "%s/%d/%s" % [view_id, size, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	if not has_icon(view_id):
		return null
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size)
			var cover: float = clampf(_coverage(view_id, p, 1.0 / size), 0.0, 1.0)
			if cover > 0.0:
				image.set_pixel(x, y, Color(color, cover))
	var made: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = made
	return made


## True when [param view_id] has an icon.
static func has_icon(view_id: StringName) -> bool:
	return (
		view_id
		in [
			&"gate_room",
			&"base",
			&"research",
			&"personnel",
			&"archive",
			&"command",
		]
	)


## How much of the pixel at [param p] (0..1 square) the icon covers; [param px] is a pixel.
static func _coverage(view_id: StringName, p: Vector2, px: float) -> float:
	var d: float = _distance(view_id, p)
	return 0.5 - d / px


## Signed distance from [param p] to the icon's strokes and fills (negative inside).
static func _distance(view_id: StringName, p: Vector2) -> float:
	var line: float = 0.045
	match view_id:
		&"gate_room":
			var ring: float = absf(p.distance_to(Vector2(0.5, 0.5)) - 0.36) - line * 1.6
			return minf(ring, p.distance_to(Vector2(0.5, 0.14)) - 0.07)
		&"base":
			var outer: float = absf(_box(p, Vector2(0.5, 0.5), Vector2(0.4, 0.34))) - line
			var wall: float = _segment(p, Vector2(0.45, 0.16), Vector2(0.45, 0.84)) - line
			var floor: float = _segment(p, Vector2(0.45, 0.5), Vector2(0.9, 0.5)) - line
			return minf(outer, minf(wall, floor))
		&"research":
			var neck: float = _box(p, Vector2(0.5, 0.22), Vector2(0.09, 0.12))
			var body: float = p.distance_to(Vector2(0.5, 0.64)) - 0.28
			return minf(absf(minf(neck, body)) - line, maxf(body, 0.62 - p.y))
		&"personnel":
			var head: float = p.distance_to(Vector2(0.5, 0.3)) - 0.15
			var torso: float = maxf(p.distance_to(Vector2(0.5, 0.92)) - 0.38, 0.55 - p.y)
			return minf(head, torso)
		&"archive":
			var back: float = absf(_box(p, Vector2(0.58, 0.42), Vector2(0.26, 0.3))) - line
			var front: float = _box(p, Vector2(0.44, 0.58), Vector2(0.26, 0.3))
			return minf(maxf(back, -front - line), absf(front) - line)
		&"command":
			var left: float = _segment(p, Vector2(0.18, 0.5), Vector2(0.5, 0.2)) - line * 1.4
			var right: float = _segment(p, Vector2(0.5, 0.2), Vector2(0.82, 0.5)) - line * 1.4
			var bar: float = _box(p, Vector2(0.5, 0.75), Vector2(0.32, 0.06))
			return minf(minf(left, right), bar)
	return 1.0


static func _box(p: Vector2, centre: Vector2, half: Vector2) -> float:
	var q: Vector2 = (p - centre).abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


static func _segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return p.distance_to(a + ab * t)
