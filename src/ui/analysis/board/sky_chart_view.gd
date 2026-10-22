class_name SkyChartView
extends Control
## The image of a clue: the constellations of its glyphs scattered over a dark field, each
## turned by an angle that comes from a hash of the clue id and the glyph, so it is the same
## every time and uses no random numbers. Recognising the turned shapes is part of the puzzle.
##
## Colours come from the theme only: the items `star_color` and `line_color` and the style
## `field` of theme type `SkyChartView` (the scene supplies a dark field and light stars).
## Bible: gate-and-address-spec.md#clue-types-and-reliability, art-and-audio.md

## Theme type of this control's items.
const THEME_TYPE: StringName = &"SkyChartView"
## Most glyphs in one row.
const MAX_COLUMNS: int = 4
## Share of a cell a glyph fills.
const FILL: float = 0.9
## How far a glyph may sit off its cell centre, as a share of the cell.
const JITTER: float = 0.12
## Whole degrees a hash is reduced to.
const DEGREES: int = 360
## Distinguishes the position hash from the angle hash.
const JITTER_SALT: String = "@"

var _clue_id: StringName = &""
var _glyphs: Array[int] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var field: StyleBox = get_theme_stylebox(&"field", THEME_TYPE)
	draw_style_box(field, Rect2(Vector2.ZERO, size))
	if _glyphs.is_empty():
		return
	var columns: int = mini(_glyphs.size(), MAX_COLUMNS)
	var rows: int = ceili(float(_glyphs.size()) / columns)
	var cell: Vector2 = Vector2(size.x / columns, size.y / rows)
	for slot: int in _glyphs.size():
		var centre: Vector2 = (
			Vector2(slot % columns + 0.5, floorf(float(slot) / columns) + 0.5) * cell
		)
		_draw_glyph(_glyphs[slot], centre, cell)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Shows [param glyphs] (glyph indices) as the picture of clue [param clue_id].
func setup(clue_id: StringName, glyphs: Array[int]) -> void:
	_clue_id = clue_id
	_glyphs = glyphs.duplicate()
	queue_redraw()


## Returns the glyph indices being drawn.
func get_glyphs() -> Array[int]:
	return _glyphs


## Returns the angle in radians, 0 up to a full turn, that clue [param clue_id] turns
## [param glyph] by. The same inputs always give the same angle.
static func angle_for(clue_id: StringName, glyph: int) -> float:
	return deg_to_rad(float(posmod(hash(String(clue_id) + str(glyph)), DEGREES)))


## Returns how far clue [param clue_id] moves [param glyph] off its cell centre, each axis
## from -[constant JITTER] to [constant JITTER] of the cell. Stable like [method angle_for].
static func offset_for(clue_id: StringName, glyph: int) -> Vector2:
	var code: int = hash(String(clue_id) + JITTER_SALT + str(glyph))
	var x: float = float(posmod(code, DEGREES)) / DEGREES - 0.5
	var y: float = float(posmod(code >> 9, DEGREES)) / DEGREES - 0.5
	return Vector2(x, y) * 2.0 * JITTER


func _draw_glyph(index: int, centre: Vector2, cell: Vector2) -> void:
	var glyph: GlyphDef = (
		Registry.get_def(StringName(GlyphIcon.GLYPH_ID_FORMAT % index)) as GlyphDef
	)
	if glyph == null:
		return
	var side: float = minf(cell.x, cell.y) * FILL
	var area: Rect2 = GlyphIcon.art_rect(Vector2(side, side), 0.0)
	area.position -= Vector2(side, side) / 2.0
	var stars: PackedVector2Array = GlyphIcon.star_positions(glyph.points, area)
	draw_set_transform(
		centre + offset_for(_clue_id, index) * cell, angle_for(_clue_id, index), Vector2.ONE
	)
	var line_color: Color = get_theme_color(&"line_color", THEME_TYPE)
	for pair: int in range(0, glyph.lines.size() - 1, 2):
		var from: int = glyph.lines[pair]
		var to: int = glyph.lines[pair + 1]
		if from < stars.size() and to < stars.size():
			draw_line(stars[from], stars[to], line_color, GlyphIcon.line_width(side), true)
	var star_color: Color = get_theme_color(&"star_color", THEME_TYPE)
	for star: Vector2 in stars:
		draw_circle(star, GlyphIcon.star_radius(side), star_color)
