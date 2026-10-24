class_name DocumentArtCanvas
extends RefCounted
## A CPU drawing surface for the placeholder document art: an Image with lines, dots, filled
## polygons, grain, a vignette, glyphs drawn from their GlyphDef stars and lines, and capital
## text in a small pixel font. Works headless (no renderer). Every random draw comes from the
## canvas's own seeded generator, so the same calls give the same pixels.
## Tool code only: used by tools/gen_document_art.gd, never by the game.
## Bible: art-and-audio.md, gate-and-address-spec.md#the-opening-puzzle

const PixelFont := preload("res://tools/document_art/pixel_font.gd")

## The image drawn on.
var image: Image
## The canvas's random source.
var rng := RandomNumberGenerator.new()


## Creates a [param size] canvas filled with [param color], its generator seeded with
## [param art_seed].
func _init(size: Vector2i, color: Color, art_seed: int) -> void:
	image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(color)
	rng.seed = art_seed


## Blends [param color] over the pixel at [param x], [param y] with its alpha; off-canvas
## pixels are skipped.
func blend(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, image.get_pixel(x, y).lerp(Color(color, 1.0), color.a))


## Fills a disc of [param radius] pixels at [param center].
func dot(center: Vector2, radius: float, color: Color) -> void:
	var reach: int = ceili(radius)
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			if Vector2(dx, dy).length() <= radius:
				blend(roundi(center.x) + dx, roundi(center.y) + dy, color)


## Draws a line [param width] pixels wide from [param from] to [param to].
func line(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var steps: int = maxi(1, ceili(from.distance_to(to) * 2.0))
	for step: int in steps + 1:
		dot(from.lerp(to, float(step) / steps), width * 0.5, color)


## Draws a line through every point of [param points] in turn.
func polyline(points: PackedVector2Array, width: float, color: Color) -> void:
	for index: int in range(1, points.size()):
		line(points[index - 1], points[index], width, color)


## Fills the polygon [param points] (even-odd rule) with [param color].
func fill_polygon(points: PackedVector2Array, color: Color) -> void:
	var top: int = floori(points[0].y)
	var bottom: int = ceili(points[0].y)
	for point: Vector2 in points:
		top = mini(top, floori(point.y))
		bottom = maxi(bottom, ceili(point.y))
	for y: int in range(top, bottom + 1):
		var crossings: Array[float] = _crossings(points, y + 0.5)
		for pair: int in range(0, crossings.size() - 1, 2):
			for x: int in range(roundi(crossings[pair]), roundi(crossings[pair + 1])):
				blend(x, y, color)


## Fills the axis-aligned [param rect] with [param color].
func fill_rect(rect: Rect2, color: Color) -> void:
	var corners := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	fill_polygon(corners, color)


## Adds grain: every pixel moves toward black or white by up to [param amount].
func grain(amount: float) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var shift: float = rng.randf_range(-amount, amount)
			var pixel: Color = image.get_pixel(x, y)
			image.set_pixel(
				x, y, pixel.lerp(Color.WHITE if shift > 0.0 else Color.BLACK, absf(shift))
			)


## Darkens the corners: up to [param strength] at the far corner, nothing at the centre.
func vignette(strength: float) -> void:
	var center: Vector2 = Vector2(image.get_size()) * 0.5
	var reach: float = center.length()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var fall: float = pow(Vector2(x, y).distance_to(center) / reach, 2.0) * strength
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(Color.BLACK, fall))


## Draws [param glyph]'s lines and stars in [param box]. [param points] replaces the glyph's own
## stars when not empty (a damaged or turned carving); [param width] is the stroke in pixels.
func glyph(glyph_def: GlyphDef, box: Rect2, width: float, color: Color) -> void:
	glyph_points(glyph_def.points, glyph_def.lines, box, [width, color])


## Draws the stars [param points] (unit square) joined by [param lines] in [param box];
## [param style] is [width, color].
func glyph_points(
	points: PackedVector2Array, lines: PackedInt32Array, box: Rect2, style: Array
) -> void:
	var width: float = style[0]
	var color: Color = style[1]
	var placed := PackedVector2Array()
	for point: Vector2 in points:
		placed.append(box.position + point * box.size)
	for pair: int in range(0, lines.size() - 1, 2):
		line(placed[lines[pair]], placed[lines[pair + 1]], width, color)
	for star: Vector2 in placed:
		dot(star, width * 0.9, color)


## Writes [param text] in capitals with its top left at [param origin], each font pixel
## [param scale] pixels wide.
func text(words: String, origin: Vector2i, scale: int, color: Color) -> void:
	var cursor: int = origin.x
	for character: String in words.to_upper():
		var rows: PackedStringArray = PixelFont.rows_of(character)
		for row: int in rows.size():
			for column: int in rows[row].length():
				if rows[row][column] == "#":
					var corner := Vector2(cursor + column * scale, origin.y + row * scale)
					fill_rect(Rect2(corner, Vector2.ONE * scale), color)
		cursor += (PixelFont.WIDTH + 1) * scale


## Width in pixels of [param words] written at [param scale].
static func text_width(words: String, scale: int) -> int:
	return words.length() * (PixelFont.WIDTH + 1) * scale


## Saves the canvas as a PNG at [param path]; returns the error code.
func save(path: String) -> Error:
	return image.save_png(path)


## The sorted x positions where the polygon's edges cross the row at [param y].
static func _crossings(points: PackedVector2Array, y: float) -> Array[float]:
	var found: Array[float] = []
	for index: int in points.size():
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		if (a.y <= y) == (b.y <= y):
			continue
		found.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
	found.sort()
	return found
