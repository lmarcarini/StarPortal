extends RefCounted
## The two horizon-camera frames from LINTEL's first lock, as grainy black-and-white stills:
## frame 1, the standing disc with seven recesses read from the climbing mark at the bottom,
## the lower-left recess empty; frame 2, the long-lens view of the fallen tablet below it,
## its Candle upside down. Tool code only, used by tools/gen_document_art.gd.
## Bible: docs/content/m15-puzzles.md (Puzzle 3), art-and-audio.md

const Canvas := preload("res://tools/document_art/art_canvas.gd")

const SKY := Color(0.04, 0.04, 0.05)
const GRIT := Color(0.42, 0.42, 0.41)
const STONE := Color(0.74, 0.74, 0.72)
const RECESS := Color(0.5, 0.5, 0.49)
const CUT := Color(0.16, 0.16, 0.17)
const STAMP := Color(0.92, 0.92, 0.9)
const SIZE := Vector2i(1000, 750)
const HORIZON_Y: int = 300

## The rim's carvings from the bottom recess round toward the lower right (anticlockwise as
## seen); -1 is the empty recess.
const RIM: Array[int] = [35, 22, 19, 3, 24, 29, -1]
const CANDLE: int = 34


## Frame 1: the disc straight on, about thirty metres away.
static func disc_frame(glyphs: Dictionary[int, GlyphDef]) -> Canvas:
	var canvas: Canvas = _scene(58)
	var center := Vector2(500, 380)
	canvas.fill_rect(Rect2(center.x - 120, center.y + 230, 240, 50), STONE.darkened(0.15))
	canvas.dot(center, 260.0, STONE)
	canvas.dot(center, 40.0, STONE.darkened(0.2))
	canvas.dot(center, 30.0, STONE.lightened(0.1))
	for place: int in RIM.size():
		var angle: float = TAU * place / RIM.size()
		var spot: Vector2 = center + Vector2(sin(angle), cos(angle)) * 185.0
		if RIM[place] < 0:
			_empty_recess(canvas, spot)
			canvas.fill_rect(Rect2(spot.x - 12, center.y + 300, 24, 14), STONE)
			continue
		canvas.dot(spot, 58.0, RECESS)
		canvas.glyph(glyphs[RIM[place]], Rect2(spot - Vector2(40, 40), Vector2(80, 80)), 5.0, CUT)
	return _finish(canvas, "FR 1  01:10")


## Frame 2: long lens on the foot of the disc and the broken tablet on the grit.
static func fragment_frame(glyphs: Dictionary[int, GlyphDef]) -> Canvas:
	var canvas := Canvas.new(SIZE, GRIT, 59)
	canvas.dot(Vector2(820, -520), 900.0, STONE)
	_empty_recess(canvas, Vector2(560, 210))
	var tablet := PackedVector2Array(
		[
			Vector2(380, 420),
			Vector2(560, 420),
			Vector2(620, 470),
			Vector2(620, 700),
			Vector2(380, 700)
		]
	)
	canvas.fill_polygon(tablet, STONE)
	var candle: GlyphDef = glyphs[CANDLE]
	var turned := PackedVector2Array()
	for point: Vector2 in candle.points:
		turned.append(Vector2.ONE - point)
	canvas.glyph_points(turned, candle.lines, Rect2(420, 470, 160, 200), [7.0, CUT])
	return _finish(canvas, "FR 2  02:40")


## Black sky over the grey grit plain.
static func _scene(art_seed: int) -> Canvas:
	var canvas := Canvas.new(SIZE, GRIT, art_seed)
	canvas.fill_rect(Rect2(0, 0, SIZE.x, HORIZON_Y), SKY)
	return canvas


## A clean-edged hollow shaped like a tall rectangle, with a rough floor.
static func _empty_recess(canvas: Canvas, spot: Vector2) -> void:
	canvas.fill_rect(Rect2(spot - Vector2(28, 42), Vector2(56, 84)), CUT.lightened(0.15))
	for step: int in 40:
		var speck := (
			spot + Vector2(canvas.rng.randf_range(-24, 24), canvas.rng.randf_range(-38, 38))
		)
		canvas.dot(speck, 2.0, RECESS.darkened(0.3))


## Grain, vignette and the frame stamp in the lower left corner.
static func _finish(canvas: Canvas, stamp: String) -> Canvas:
	canvas.grain(0.09)
	canvas.vignette(0.55)
	canvas.text(stamp, Vector2i(24, SIZE.y - 50), 4, STAMP)
	return canvas
