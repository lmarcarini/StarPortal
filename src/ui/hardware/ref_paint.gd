class_name RefPaint
extends RefCounted
## The materials of the interface reference, drawn in code on any CanvasItem
## (interface-reference.md section 3): the steel plate (gradient, grain, dark edge, bevel
## line, bolts, soft shadow), the key in its five states, the lamp, the recess and the CRT
## glass. Matches tools/reference/render_ref.py. Pure drawing: no state.
## Bible: docs/content/interface-reference.md section 3

## Key styles.
enum KeyStyle { STEEL, AMBER, LIT, OFF, HAZARD }

const STEEL_TOP: Color = Color8(46, 47, 41)
const STEEL_BOTTOM: Color = Color8(30, 31, 27)
const STEEL_DARK_BOTTOM: Color = Color8(20, 21, 18)
const BEVEL: Color = Color8(98, 99, 86)
const EDGE: Color = Color8(13, 14, 13)
const TEXT: Color = Color8(233, 228, 208)
const DIM: Color = Color8(156, 154, 136)
const AMBER: Color = Color8(232, 163, 61)
const AMBER_HI: Color = Color8(255, 217, 143)
const GREEN: Color = Color8(127, 214, 138)
const CRT_BG: Color = Color8(10, 22, 14)
const RED: Color = Color8(229, 83, 61)
const HAZARD_YELLOW: Color = Color8(232, 178, 36)
const PAPER: Color = Color8(233, 228, 208)
const INK: Color = Color8(26, 26, 22)
const BLUE: Color = Color8(63, 169, 245)
## Ink of a key's label and icon, by style.
const INK_OF: Dictionary[KeyStyle, Color] = {
	KeyStyle.STEEL: TEXT,
	KeyStyle.AMBER: Color8(26, 20, 8),
	KeyStyle.LIT: AMBER,
	KeyStyle.OFF: Color8(110, 110, 98),
	KeyStyle.HAZARD: TEXT,
}

static var _grain: ImageTexture = null


## A steel plate over [param rect] on [param item]; [param dark] for the wire's darker
## steel; [param bolts] adds the corner bolts (radius 6, else 4).
static func steel_plate(item: CanvasItem, rect: Rect2, dark: bool, bolts: bool) -> void:
	var radius: float = 6.0 if bolts else 4.0
	var shadow: StyleBoxFlat = StyleBoxFlat.new()
	shadow.bg_color = EDGE
	shadow.set_corner_radius_all(int(radius))
	shadow.shadow_color = Color(0, 0, 0, 0.65)
	shadow.shadow_size = 7
	shadow.shadow_offset = Vector2(0, 4)
	shadow.anti_aliasing = true
	item.draw_style_box(shadow, rect)
	var inner: Rect2 = rect.grow(-2.0)
	var bottom: Color = STEEL_DARK_BOTTOM if dark else STEEL_BOTTOM
	gradient(item, inner, radius - 2.0, [STEEL_BOTTOM if dark else STEEL_TOP, bottom])
	grain(item, inner.grow(-2.0), 1.0)
	var y: float = rect.position.y + 2.5
	item.draw_line(
		Vector2(rect.position.x + radius, y), Vector2(rect.end.x - radius, y), BEVEL, 1.0
	)
	if bolts and rect.size.x > 40.0 and rect.size.y > 30.0:
		_bolts(item, rect)


## A vertical gradient [param colors] (top, bottom) in a rounded [param rect].
static func gradient(item: CanvasItem, rect: Rect2, radius: float, colors: Array[Color]) -> void:
	var points: PackedVector2Array = rounded(rect, radius)
	var fill: PackedColorArray = []
	for point: Vector2 in points:
		var t: float = clampf((point.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
		fill.append(colors[0].lerp(colors[1], t))
	item.draw_polygon(points, fill)


## The light grain of steel and paper over [param rect], at [param strength].
static func grain(item: CanvasItem, rect: Rect2, strength: float) -> void:
	if _grain == null:
		_grain = _make_grain()
	item.draw_texture_rect(_grain, rect, true, Color(1, 1, 1, strength))


## The points of a rounded [param rect] with corner [param radius].
static func rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	for i: int in 4:
		for step: int in 5:
			var angle: float = deg_to_rad(-90.0 + i * 90.0 + step * 22.5)
			points.append(corners[i] + Vector2(cos(angle), sin(angle)) * r)
	return points


## A 2 px (or [param width]) rounded outline of [param rect].
static func outline(item: CanvasItem, rect: Rect2, ink: Color, width: float = 2.0) -> void:
	var points: PackedVector2Array = rounded(rect.grow(-width * 0.5), 6.0 - width * 0.5)
	points.append(points[0])
	item.draw_polyline(points, ink, width, true)


## A key over [param rect] in [param style], raised on its 4 px dark base. Returns the ink
## of its label and icon.
static func key(item: CanvasItem, rect: Rect2, style: KeyStyle) -> Color:
	item.draw_polygon(
		rounded(Rect2(rect.position + Vector2(0, 4), rect.size), 6.0), [Color8(8, 8, 7)]
	)
	match style:
		KeyStyle.AMBER:
			_glow(item, rect, AMBER, 0.22)
			gradient(item, rect, 6.0, [Color8(240, 180, 85), Color8(185, 122, 30)])
		KeyStyle.LIT:
			gradient(item, rect, 6.0, [Color8(90, 70, 36), Color8(52, 40, 20)])
		KeyStyle.OFF:
			item.draw_polygon(rounded(rect, 6.0), [Color8(36, 37, 32)])
		KeyStyle.HAZARD:
			RefHazard.face(item, rect)
		_:
			gradient(item, rect, 6.0, [Color8(78, 79, 69), Color8(44, 45, 40)])
	var edges: Dictionary[KeyStyle, Color] = {
		KeyStyle.AMBER: Color8(90, 60, 12), KeyStyle.LIT: AMBER
	}
	var edge: Color = edges.get(style, EDGE)
	outline(item, rect, edge, 3.0 if style == KeyStyle.LIT else 2.0)
	if style == KeyStyle.STEEL or style == KeyStyle.AMBER:
		var hi: Color = Color8(255, 225, 160) if style == KeyStyle.AMBER else Color8(120, 121, 106)
		var y: float = rect.position.y + 3.0
		item.draw_line(Vector2(rect.position.x + 6, y), Vector2(rect.end.x - 6, y), hi, 2.0)
	return INK_OF[style]


## A lit lamp of radius [param r] at [param centre] in [param ink], glowing.
static func lamp_on(item: CanvasItem, centre: Vector2, r: float, ink: Color) -> void:
	for i: int in 6:
		var k: float = 1.0 - i / 6.0
		item.draw_circle(centre, r * (1.2 + 1.6 * k), Color(ink, 0.05))
	item.draw_circle(centre, r + 3.0, EDGE)
	item.draw_circle(centre, r, ink)
	var hi: Color = AMBER_HI if ink == AMBER else Color8(220, 255, 225)
	item.draw_circle(centre + Vector2(-r * 0.15, -r * 0.3), r * 0.28, hi)


## An unlit lamp of radius [param r] at [param centre]: amber glass, or green with
## [param green].
static func lamp_off(item: CanvasItem, centre: Vector2, r: float, green: bool) -> void:
	item.draw_circle(centre, r + 3.0, EDGE)
	item.draw_circle(centre, r, Color8(30, 44, 34) if green else Color8(58, 46, 26))
	item.draw_circle(centre + Vector2(-r * 0.2, -r * 0.3), r * 0.22, Color8(84, 70, 44))


## A paper sheet over [param rect] with a hard shadow; a [param strip] (alpha > 0) is the
## coloured strip on its left edge.
static func paper(item: CanvasItem, rect: Rect2, strip: Color) -> void:
	item.draw_rect(Rect2(rect.position + Vector2(6, 8), rect.size), Color(0, 0, 0, 0.85))
	gradient(item, rect, 0.0, [Color8(236, 231, 212), Color8(216, 210, 188)])
	grain(item, rect, 1.6)
	item.draw_rect(rect, Color8(120, 112, 90), false, 1.0)
	if strip.a > 0.0:
		item.draw_rect(Rect2(rect.position, Vector2(8, rect.size.y)), strip)


## A sunk well over [param rect] (the destination picture, the cards' wells).
static func recess(item: CanvasItem, rect: Rect2) -> void:
	item.draw_polygon(rounded(rect, 4.0), [Color8(16, 17, 15)])
	outline(item, rect, EDGE, 2.0)
	var y: float = rect.end.y - 2.0
	item.draw_line(Vector2(rect.position.x + 4, y), Vector2(rect.end.x - 4, y), Color8(70, 70, 62))


static func _glow(item: CanvasItem, rect: Rect2, ink: Color, strength: float) -> void:
	var halo: StyleBoxFlat = StyleBoxFlat.new()
	halo.bg_color = Color(ink, 0.0)
	halo.set_corner_radius_all(6)
	halo.shadow_color = Color(ink, strength)
	halo.shadow_size = 16
	item.draw_style_box(halo, rect)


static func _bolts(item: CanvasItem, rect: Rect2) -> void:
	var spots: Array[Vector2] = [
		rect.position + Vector2(9, 9),
		Vector2(rect.end.x - 10, rect.position.y + 9),
		Vector2(rect.position.x + 9, rect.end.y - 10),
		rect.end - Vector2(10, 10),
	]
	for spot: Vector2 in spots:
		item.draw_circle(spot, 3.0, Color8(18, 18, 16))
		item.draw_rect(Rect2(spot - Vector2(1, 1), Vector2(1, 1)), Color8(110, 110, 98))


static func _make_grain() -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var image: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y: int in 128:
		for x: int in 128:
			var v: float = rng.randf_range(-1.0, 1.0)
			var ink: float = 1.0 if v > 0.0 else 0.0
			image.set_pixel(x, y, Color(ink, ink, ink, absf(v) * 0.03))
	return ImageTexture.create_from_image(image)
