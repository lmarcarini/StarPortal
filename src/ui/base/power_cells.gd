class_name PowerCells
extends RefCounted
## The POWER view's battery marks on a room tile (owner request 2026-11-27, in place of the
## MW number that overlapped the name at some zooms): one battery per 5 MW, the last one
## filled by the remainder, in a row along the tile's bottom edge (wrapping upward when the
## row is full). Green for a room that makes power, amber for one that draws it.
## Bible: docs/content/interface-reference.md section 8

## MW one battery stands for.
const MW_PER_CELL: float = 5.0
## One battery's body, its terminal nub, and the gap between batteries, in screen pixels.
const BODY: Vector2 = Vector2(18, 10)
const NUB: Vector2 = Vector2(2, 4)
const GAP: float = 5.0
## Distance from the tile's left and bottom edges.
const MARGIN: float = 10.0


## How many batteries [param mw] shows (0 for no power role).
static func count(mw: float) -> int:
	return ceili(mw / MW_PER_CELL - 0.001) if mw > 0.0 else 0


## The fill (0..1) of battery [param index] of the [param mw] row.
static func fill(mw: float, index: int) -> float:
	return clampf(mw / MW_PER_CELL - index, 0.0, 1.0)


## Draws the batteries for [param mw] on [param canvas], bottom left of [param area].
static func draw(canvas: CanvasItem, area: Rect2, mw: float, produces: bool) -> void:
	var total: int = count(mw)
	if total == 0:
		return
	var ink: Color = RefPaint.GREEN if produces else RefPaint.AMBER
	var pitch: float = BODY.x + NUB.x + GAP
	var per_row: int = maxi(1, floori((area.size.x - MARGIN * 2.0 + GAP) / pitch))
	for k: int in total:
		var row: int = floori(float(k) / per_row)
		var col: int = k % per_row
		var at: Vector2 = Vector2(
			area.position.x + MARGIN + col * pitch,
			area.end.y - MARGIN - BODY.y - row * (BODY.y + GAP)
		)
		_battery(canvas, Rect2(at, BODY), fill(mw, k), ink)


static func _battery(canvas: CanvasItem, body: Rect2, amount: float, ink: Color) -> void:
	canvas.draw_rect(body, Color8(20, 21, 18))
	var inner: Rect2 = body.grow(-2.0)
	canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x * amount, inner.size.y)), ink)
	canvas.draw_rect(body, ink, false, 1.5)
	var nub: Vector2 = Vector2(body.end.x, body.get_center().y - NUB.y * 0.5)
	canvas.draw_rect(Rect2(nub, NUB), ink)
