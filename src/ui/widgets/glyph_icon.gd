class_name GlyphIcon
extends Control
## Draws one glyph's constellation: its stars as dots and its lines as strokes, scaled to the
## control's size and centred in it. Set [member glyph_index] to read the glyph from the
## [Registry], or call [method setup] with a [GlyphDef] the caller already holds. With
## [member show_name] the translated name is drawn under the stars.
##
## Colours come from the theme only, so colour-blind and high-contrast themes apply: the items
## `star_color`, `line_color` and `name_color` of theme type `GlyphIcon`, each falling back to
## the Label's `font_color` when the theme does not define it. Stars stay visible at 24 x 24 px.
## Bible: art-and-audio.md (Glyphs are clean vector icons),
## gate-and-address-spec.md#glyphs-and-the-hidden-address-math

## Theme type of this widget's colour items.
const THEME_TYPE: StringName = &"GlyphIcon"
## Smallest size the control asks for, in pixels, before the name line is added.
const MIN_SIZE: Vector2 = Vector2(24, 24)
## Format of a glyph id built from its index.
const GLYPH_ID_FORMAT: String = "glyph_%02d"
## Radius of a star as a share of the drawing's side, and the smallest radius in pixels.
const STAR_RADIUS_RATIO: float = 0.035
const MIN_STAR_RADIUS: float = 2.0
## Stroke width as a share of the drawing's side, and the smallest width in pixels.
const LINE_WIDTH_RATIO: float = 0.015
const MIN_LINE_WIDTH: float = 1.0
## Opacity of the lines when the theme gives no `line_color` and the label colour stands in.
const FALLBACK_LINE_ALPHA: float = 0.7
## Space kept between the stars and the name line, in pixels.
const NAME_GAP: float = 2.0

## Index of the glyph to draw, 0..35; -1 (or any index without a glyph) draws nothing.
@export var glyph_index: int = -1:
	set(value):
		glyph_index = value
		_apply_glyph(_lookup(value))
## True to draw the translated name under the stars.
@export var show_name: bool = false:
	set(value):
		show_name = value
		update_minimum_size()
		queue_redraw()

var _glyph: GlyphDef


func _get_minimum_size() -> Vector2:
	return Vector2(MIN_SIZE.x, MIN_SIZE.y + _name_height())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED, NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()
		NOTIFICATION_THEME_CHANGED:
			update_minimum_size()
			queue_redraw()


func _draw() -> void:
	if _glyph == null:
		return
	var reserved: float = _name_height()
	var area: Rect2 = art_rect(size, reserved)
	if area.size.x <= 0.0:
		return
	var stars: PackedVector2Array = star_positions(_glyph.points, area)
	var line_color: Color = _theme_color(&"line_color", FALLBACK_LINE_ALPHA)
	for pair: int in range(0, _glyph.lines.size() - 1, 2):
		var from: int = _glyph.lines[pair]
		var to: int = _glyph.lines[pair + 1]
		if from < stars.size() and to < stars.size():
			draw_line(stars[from], stars[to], line_color, line_width(area.size.x), true)
	var star_color: Color = _theme_color(&"star_color")
	for star: Vector2 in stars:
		draw_circle(star, star_radius(area.size.x), star_color)
	if show_name:
		_draw_name()


## Draws [param glyph] (null draws nothing), for views and tests that already hold the
## definition. A later change of [member glyph_index] replaces it.
func setup(glyph: GlyphDef) -> void:
	glyph_index = glyph.index if glyph != null else -1
	_apply_glyph(glyph)


## Returns the glyph being drawn, or null when none is set.
func get_glyph() -> GlyphDef:
	return _glyph


## Returns the square the stars are drawn in: the largest square that fits in [param
## control_size] under [param reserved_height] of space kept for the name, centred
## horizontally and inset so a star on the unit square's edge still fits inside the control.
## Its size is zero when there is no room.
static func art_rect(control_size: Vector2, reserved_height: float) -> Rect2:
	var side: float = minf(control_size.x, control_size.y - reserved_height)
	if side <= 0.0:
		return Rect2()
	var inset: float = ceilf(star_radius(side)) + 1.0
	var inner: float = side - 2.0 * inset
	if inner <= 0.0:
		return Rect2()
	var origin: Vector2 = Vector2((control_size.x - inner) / 2.0, inset)
	return Rect2(origin, Vector2(inner, inner))


## Maps unit-square [param points] into [param area].
static func star_positions(points: PackedVector2Array, area: Rect2) -> PackedVector2Array:
	var mapped: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		mapped.append(area.position + point * area.size)
	return mapped


## Radius in pixels of a star in a drawing [param side] pixels wide.
static func star_radius(side: float) -> float:
	return maxf(MIN_STAR_RADIUS, side * STAR_RADIUS_RATIO)


## Width in pixels of a constellation line in a drawing [param side] pixels wide.
static func line_width(side: float) -> float:
	return maxf(MIN_LINE_WIDTH, side * LINE_WIDTH_RATIO)


func _apply_glyph(glyph: GlyphDef) -> void:
	_glyph = glyph
	queue_redraw()


func _lookup(index: int) -> GlyphDef:
	if index < 0 or index >= GateAddress.GLYPH_COUNT:
		return null
	return Registry.get_def(StringName(GLYPH_ID_FORMAT % index)) as GlyphDef


func _theme_color(item: StringName, fallback_alpha: float = 1.0) -> Color:
	if has_theme_color(item, THEME_TYPE):
		return get_theme_color(item, THEME_TYPE)
	var color: Color = get_theme_color(&"font_color", &"Label")
	return Color(color, color.a * fallback_alpha)


func _name_height() -> float:
	if not show_name:
		return 0.0
	var font: Font = get_theme_font(&"font", &"Label")
	var font_size: int = get_theme_font_size(&"font_size", &"Label")
	return font.get_height(font_size) + NAME_GAP


func _draw_name() -> void:
	if _glyph.name_key.is_empty():
		return
	var font: Font = get_theme_font(&"font", &"Label")
	var font_size: int = get_theme_font_size(&"font_size", &"Label")
	var baseline: float = size.y - font.get_descent(font_size)
	var color: Color = _theme_color(&"name_color")
	draw_string(
		font,
		Vector2(0.0, baseline),
		tr(_glyph.name_key),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		font_size,
		color
	)
