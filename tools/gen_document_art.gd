extends SceneTree
## Draws the placeholder images of the M1.5 documents into `art/documents/` from the glyph data
## in `data/gate/glyphs/`, so every carving is its palette picture: Pell's sill-stone sketch,
## the lintel rubbing (with the crack through the Flag and the Crown's broken middle point) and
## the two horizon-camera frames from LINTEL (the disc of seven recesses and the fallen
## Candle, upside down). Real art replaces them later.
##
## Run from the project root, then import:
## `godot --headless --path . --script tools/gen_document_art.gd`
## The output is the same on every run (seeded grain), so re-running it and checking
## `git diff --exit-code art/documents` proves the committed images are the tool's output.
## Tool code only: it is not part of the game and `tools/` is not exported.
## Bible: docs/content/m15-puzzles.md, art-and-audio.md

const Canvas := preload("res://tools/document_art/art_canvas.gd")
const FrameArt := preload("res://tools/document_art/frame_art.gd")

const GLYPH_DIR: String = "res://data/gate/glyphs"
const OUT_DIR: String = "res://art/documents"

const PAPER := Color(0.93, 0.91, 0.85)
const GRID := Color(0.55, 0.65, 0.8, 0.35)
const PENCIL := Color(0.28, 0.28, 0.3)
const GRAPHITE := Color(0.33, 0.33, 0.35)
const CRACK := Color(0.08, 0.08, 0.09)

## Sill stone, two rows of four, as the design's table lays them out.
const SILL_TOP: Array[int] = [35, 29, 19, 8]
const SILL_BOTTOM: Array[int] = [24, 10, 22, 2]
## Lintel pieces A to D as they lay on the bench, left to right.
const LINTEL_PIECES: Array[Array] = [[4, 5], [6], [35, 10], [15, 19]]
const CROWN: int = 5
const FLAG: int = 10
## Height, in the glyph's unit square, where the Crown's middle point is broken off.
const CROWN_BREAK_Y: float = 0.42


func _init() -> void:
	var glyphs: Dictionary[int, GlyphDef] = load_glyphs()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var images: Dictionary[String, Canvas] = {
		"sill_stone.png": sill_stone(glyphs),
		"lintel_rubbing.png": lintel_rubbing(glyphs),
		"lintel_frame_1.png": FrameArt.disc_frame(glyphs),
		"lintel_frame_2.png": FrameArt.fragment_frame(glyphs),
	}
	var failed: bool = glyphs.size() != GateAddress.GLYPH_COUNT
	for file_name: String in images:
		failed = images[file_name].save(OUT_DIR.path_join(file_name)) != OK or failed
	quit(1 if failed else 0)


## Every GlyphDef under data/gate/glyphs, keyed by index.
static func load_glyphs() -> Dictionary[int, GlyphDef]:
	var glyphs: Dictionary[int, GlyphDef] = {}
	for entry: String in ResourceLoader.list_directory(GLYPH_DIR):
		var path: String = GLYPH_DIR.path_join(entry.trim_suffix(".remap"))
		var def: GlyphDef = load(path) as GlyphDef if path.ends_with(".tres") else null
		if def != null:
			glyphs[def.index] = def
	return glyphs


## Pell's pencil sketch of the sill stone on squared paper.
static func sill_stone(glyphs: Dictionary[int, GlyphDef]) -> Canvas:
	var canvas := Canvas.new(Vector2i(1200, 720), PAPER, 1961)
	for step: int in range(0, 1200, 24):
		canvas.line(Vector2(step, 0), Vector2(step, 719), 1.0, GRID)
	for step: int in range(0, 720, 24):
		canvas.line(Vector2(0, step), Vector2(1199, step), 1.0, GRID)
	var slab := Rect2(100, 80, 1000, 500)
	canvas.fill_rect(slab, Color(0.6, 0.58, 0.55, 0.18))
	var corners := PackedVector2Array(
		[
			slab.position,
			Vector2(slab.end.x, slab.position.y),
			slab.end,
			Vector2(slab.position.x, slab.end.y),
			slab.position
		]
	)
	canvas.polyline(corners, 4.0, PENCIL)
	for column: int in 4:
		var x: float = slab.position.x + 60 + column * 230
		canvas.glyph(glyphs[SILL_TOP[column]], Rect2(x, 120, 180, 180), 6.0, PENCIL)
		canvas.glyph(glyphs[SILL_BOTTOM[column]], Rect2(x, 360, 180, 180), 6.0, PENCIL)
	canvas.text("SILL STONE, GALLOW, FROM ABOVE. T.P.", Vector2i(100, 630), 4, PENCIL)
	canvas.grain(0.03)
	return canvas


## Pell's rubbing of the four lintel pieces as they lay on the bench, numbered 1 to 7.
static func lintel_rubbing(glyphs: Dictionary[int, GlyphDef]) -> Canvas:
	var canvas := Canvas.new(Vector2i(1600, 400), Color(0.62, 0.62, 0.63), 1958)
	canvas.grain(0.06)
	var left: float = 40.0
	var number: int = 1
	for piece: Array in LINTEL_PIECES:
		var width: float = 40.0 + piece.size() * 150.0
		canvas.fill_polygon(_ragged_rect(canvas, Rect2(left, 40, width, 300)), PAPER)
		for slot: int in piece.size():
			var index: int = piece[slot]
			var box := Rect2(left + 25 + slot * 150, 70, 140, 140)
			_draw_lintel_carving(canvas, glyphs[index], box)
			canvas.text(str(number), Vector2i(roundi(box.get_center().x) - 6, 260), 4, PENCIL)
			number += 1
		left += width + 50.0
	canvas.text("LINTEL, SHED, AS LAID. T.P.", Vector2i(1070, 362), 3, PENCIL)
	return canvas


## Draws one lintel carving: the Crown with its middle point broken off, the Flag with the
## crack running down through it, the rest whole.
static func _draw_lintel_carving(canvas: Canvas, glyph: GlyphDef, box: Rect2) -> void:
	if glyph.index == CROWN:
		var points: PackedVector2Array = broken_crown_points(glyph.points)
		canvas.glyph_points(points, glyph.lines, box, [6.0, GRAPHITE])
		var stub_y: float = box.position.y + CROWN_BREAK_Y * box.size.y
		var stub_left: float = box.position.x + 0.42 * box.size.x
		for step: int in 6:
			var x: float = stub_left + step * 0.032 * box.size.x
			canvas.dot(Vector2(x, stub_y + (step % 2) * 3.0), 3.0, GRAPHITE)
		return
	canvas.glyph(glyph, box, 6.0, GRAPHITE)
	if glyph.index == FLAG:
		var crack := PackedVector2Array(
			[
				Vector2(0.5, -0.15),
				Vector2(0.42, 0.1),
				Vector2(0.3, 0.35),
				Vector2(0.18, 0.56),
				Vector2(0.12, 0.8),
				Vector2(0.02, 1.15)
			]
		)
		var placed := PackedVector2Array()
		for point: Vector2 in crack:
			placed.append(box.position + point * box.size)
		canvas.polyline(placed, 3.0, CRACK)


## The Crown's stars with its middle point (the highest star) cut down to [member CROWN_BREAK_Y].
static func broken_crown_points(points: PackedVector2Array) -> PackedVector2Array:
	var broken: PackedVector2Array = points.duplicate()
	var top: int = 0
	for index: int in broken.size():
		if broken[index].y < broken[top].y:
			top = index
	broken[top] = Vector2(broken[top].x, CROWN_BREAK_Y)
	return broken


## The corners of [param rect] with jagged edges, as a broken piece of stone.
static func _ragged_rect(canvas: Canvas, rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var edges: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	for edge: int in 4:
		var from: Vector2 = edges[edge]
		var to: Vector2 = edges[(edge + 1) % 4]
		for step: int in 8:
			var jitter := Vector2(canvas.rng.randf_range(-9, 9), canvas.rng.randf_range(-9, 9))
			points.append(from.lerp(to, step / 8.0) + jitter)
	return points
