class_name RefText
extends RefCounted
## A text style of the interface reference (interface-reference.md section 3): a face, a
## size, a colour and the tracking, drawn on any CanvasItem with the reference's anchors
## ("la" left / ascender top, "lm" left / middle, "ls" left / baseline, "mm" centre / middle,
## "ms" centre / baseline, "ra" right / ascender top, "rm" right / middle).
## Bible: docs/content/interface-reference.md section 3

## Barlow Condensed SemiBold: titles and key labels.
const LABEL: Font = preload("res://art/fonts/barlow_condensed/BarlowCondensed-SemiBold.ttf")
## Barlow Condensed Medium: secondary lines.
const LABEL_MEDIUM: Font = preload("res://art/fonts/barlow_condensed/BarlowCondensed-Medium.ttf")
## IBM Plex Mono Bold: numbers.
const MONO_BOLD: Font = preload("res://art/fonts/ibm_plex_mono/IBMPlexMono-Bold.ttf")
## IBM Plex Mono Regular: deltas and units.
const MONO: Font = preload("res://art/fonts/ibm_plex_mono/IBMPlexMono-Regular.ttf")

static var _variations: Dictionary[String, Font] = {}

## The face (one of the constants).
var face: Font = LABEL
## Size in pixels.
var size: int = 22
## Colour.
var color: Color = Color.WHITE
## Extra pixels after every glyph.
var tracking: float = 0.0


## A style of [param base] at [param px] pixels in [param ink], tracked by [param spacing].
static func make(base: Font, px: int, ink: Color, spacing: float = 0.0) -> RefText:
	var style: RefText = RefText.new()
	style.face = base
	style.size = px
	style.color = ink
	style.tracking = spacing
	return style


## This style in [param ink].
func tinted(ink: Color) -> RefText:
	return make(face, size, ink, tracking)


## Width of [param text] (the tracking after the last glyph left out).
func width(text: String) -> float:
	if text.is_empty():
		return 0.0
	return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x - tracking


## Draws [param text] on [param item] at [param pos] by [param anchor].
func draw(item: CanvasItem, pos: Vector2, text: String, anchor: String = "la") -> void:
	if text.is_empty():
		return
	var font: Font = _font()
	var ascent: float = font.get_ascent(size)
	var descent: float = font.get_descent(size)
	var x: float = pos.x
	match anchor[0]:
		"m":
			x -= width(text) * 0.5
		"r":
			x -= width(text)
	var y: float = pos.y
	match anchor[1]:
		"a":
			y += ascent
		"m":
			y += (ascent - descent) * 0.5
	item.draw_string(
		font, Vector2(roundf(x), roundf(y)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color
	)


## The face with this style's tracking (for Labels and Buttons).
func get_font() -> Font:
	return _font()


func _font() -> Font:
	if is_zero_approx(tracking):
		return face
	var key: String = "%s:%s" % [face.resource_path, tracking]
	if not _variations.has(key):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = face
		variation.spacing_glyph = roundi(tracking)
		_variations[key] = variation
	return _variations[key]
