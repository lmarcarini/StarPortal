class_name ContentCheckGlyphs
extends RefCounted
## Content check 2: the 36 glyphs. Pure functions that return one line per problem, so a test can
## feed them bad data.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math

const MIN_STARS: int = 3
const MAX_STARS: int = 9


## Returns the problems of [param glyphs]: not exactly 36, an index outside 0..35 or used twice,
## a translation key missing from [param keys] (keys of glyphs.csv), a malformed constellation,
## or two glyphs with the same constellation.
static func check(glyphs: Array[GlyphDef], keys: Dictionary[String, bool]) -> Array[String]:
	var errors: Array[String] = []
	if glyphs.size() != GateAddress.GLYPH_COUNT:
		errors.append("glyphs: found %d, expected %d" % [glyphs.size(), GateAddress.GLYPH_COUNT])
	var seen: Dictionary[int, StringName] = {}
	var shapes: Dictionary[String, StringName] = {}
	for glyph: GlyphDef in glyphs:
		errors.append_array(_check_index(glyph, seen))
		errors.append_array(_check_keys(glyph, keys))
		errors.append_array(check_constellation(glyph))
		var shape: String = _shape_of(glyph)
		if shapes.has(shape):
			errors.append("glyph %s has the same constellation as %s" % [glyph.id, shapes[shape]])
		shapes[shape] = glyph.id
	for index: int in GateAddress.GLYPH_COUNT:
		if glyphs.size() == GateAddress.GLYPH_COUNT and not seen.has(index):
			errors.append("glyphs: no glyph has index %d" % index)
	return errors


## Returns the problems of one glyph's stars and lines: 3..9 stars inside the unit square, lines
## in pairs joining two different existing stars, no line twice.
static func check_constellation(glyph: GlyphDef) -> Array[String]:
	var errors: Array[String] = []
	var count: int = glyph.points.size()
	if count < MIN_STARS or count > MAX_STARS:
		errors.append("glyph %s has %d stars, expected %d..%d" % [glyph.id, count, 3, 9])
	for point: Vector2 in glyph.points:
		if not Rect2(0.0, 0.0, 1.0, 1.0).has_point(point):
			errors.append("glyph %s has a star outside the unit square: %s" % [glyph.id, point])
	if glyph.lines.size() % 2 != 0:
		errors.append("glyph %s has an odd number of line ends" % glyph.id)
		return errors
	var drawn: Dictionary[Vector2i, bool] = {}
	for pair: int in range(0, glyph.lines.size() - 1, 2):
		var from: int = glyph.lines[pair]
		var to: int = glyph.lines[pair + 1]
		if from == to or from < 0 or to < 0 or maxi(from, to) >= count:
			errors.append("glyph %s has a bad line %d-%d" % [glyph.id, from, to])
			continue
		var edge := Vector2i(mini(from, to), maxi(from, to))
		if drawn.has(edge):
			errors.append("glyph %s draws line %d-%d twice" % [glyph.id, edge.x, edge.y])
		drawn[edge] = true
	return errors


static func _check_index(glyph: GlyphDef, seen: Dictionary[int, StringName]) -> Array[String]:
	if glyph.index < 0 or glyph.index >= GateAddress.GLYPH_COUNT:
		return ["glyph %s has index %d, expected 0..35" % [glyph.id, glyph.index]]
	if seen.has(glyph.index):
		return ["glyph %s repeats index %d of %s" % [glyph.id, glyph.index, seen[glyph.index]]]
	seen[glyph.index] = glyph.id
	return []


static func _check_keys(glyph: GlyphDef, keys: Dictionary[String, bool]) -> Array[String]:
	var errors: Array[String] = []
	for key: StringName in [glyph.name_key, glyph.picture_key]:
		if not keys.has(String(key)):
			errors.append("glyph %s: key '%s' is not in %s" % [glyph.id, key, "glyphs.csv"])
	return errors


## The stars of [param glyph] as one sortable text, so equal constellations compare equal.
static func _shape_of(glyph: GlyphDef) -> String:
	var stars: Array[String] = []
	for point: Vector2 in glyph.points:
		stars.append("%.3f,%.3f" % [point.x, point.y])
	stars.sort()
	return "|".join(stars)
