class_name SiteBar
extends RefCounted
## Draws a [SiteProgress] on the base plan: a thin bar along the bottom edge of the room, 0 to
## 100%, with the time left above it ("3 h", "1 d 4 h", "Queued") when the room is big enough.
## Status uses shape as well as colour (art-and-audio.md): a building bar is one solid fill, a
## demolition bar is cut into blocks in rust, and a queued site shows only the empty outline.
## Plan pixels, like [BasePlanPainter]; the caller sets the zoom and pan.
## Bible: docs/content/m2-base.md section 6, docs/bible/art-and-audio.md

## Bar height and inset from the room's edges, in plan pixels.
const HEIGHT: float = 4.0
const INSET: float = 3.0
## Font size of the time left.
const FONT_SIZE: int = 10
const TRACK := Color("#1c1915")
const BUILD := Color("#f5c27a")
const DEMOLISH := Color("#c8643c")
const OUTLINE := Color("#efe6d2")
## Width of a demolition block and the gap after it.
const BLOCK: float = 5.0
const GAP: float = 2.0


## Draws [param progress] at the bottom of [param area] (plan pixels); [param text] is the
## caption, written only when it fits.
static func draw(
	canvas: CanvasItem, area: Rect2, progress: SiteProgress, text: String, font: Font
) -> void:
	var bar := bar_rect(area)
	if bar.size.x <= 0.0:
		return
	canvas.draw_rect(bar, TRACK)
	var filled := Rect2(bar.position, Vector2(bar.size.x * progress.fraction, bar.size.y))
	if progress.kind == SiteProgress.Kind.DEMOLISHING:
		_draw_blocks(canvas, filled)
	elif progress.kind != SiteProgress.Kind.QUEUED:
		canvas.draw_rect(filled, BUILD)
	canvas.draw_rect(bar, OUTLINE, false, 1.0)
	if fits(area, text, font):
		var at := Vector2(bar.position.x, bar.position.y - 3.0)
		canvas.draw_string(font, at + Vector2.ONE, text, 0, -1, FONT_SIZE, Color(TRACK, 0.8))
		canvas.draw_string(font, at, text, 0, -1, FONT_SIZE, OUTLINE)


## The bar inside [param area]: along its bottom edge, inset on three sides.
static func bar_rect(area: Rect2) -> Rect2:
	var width: float = area.size.x - INSET * 2.0
	return Rect2(area.end.x - INSET - width, area.end.y - INSET - HEIGHT, width, HEIGHT)


## True when [param text] fits above the bar in [param area]: two cells high at least and
## wide enough. A small site shows only the bar.
static func fits(area: Rect2, text: String, font: Font) -> bool:
	if text.is_empty() or area.size.y < BasePlanPainter.CELL * 2.0:
		return false
	var width: float = font.get_string_size(text, 0, -1, FONT_SIZE).x
	return width <= area.size.x - INSET * 2.0


static func _draw_blocks(canvas: CanvasItem, filled: Rect2) -> void:
	var x: float = filled.position.x
	while x < filled.end.x:
		var width: float = minf(BLOCK, filled.end.x - x)
		canvas.draw_rect(Rect2(x, filled.position.y, width, filled.size.y), DEMOLISH)
		x += BLOCK + GAP
