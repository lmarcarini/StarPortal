class_name PlanTiles
extends RefCounted
## Draws the Base plan's rooms in screen space on the lit plan table (interface-reference.md
## section 8): tiles inset 4 px from their cells, filled by state (on dark green with a soft
## glow and a green rim, off dark grey, site dark ochre with a progress bar and what is being
## built), a 24 px type icon and the name (18) top left, a green lamp top right when on, staff
## slots along the bottom (filled discs with the role letter, rings for free slots), the
## Ring on the Gate Room, corridors as darker strips inset 8 px, and the amber selection.
## Bible: docs/content/interface-reference.md section 8

const ON_FILL: Color = Color8(38, 64, 54)
const OFF_FILL: Color = Color8(28, 32, 34)
const SITE_FILL: Color = Color8(52, 46, 26)
const OFF_RIM: Color = Color8(90, 92, 86)
const SITE_RIM: Color = Color8(180, 140, 60)
const CORRIDOR: Color = Color8(38, 46, 44)
const POWER_FILL: Color = Color8(60, 52, 26)
const SLOT_PITCH: float = 30.0


## The screen rect of [param cells] in [param plan], inset by [param inset].
static func rect_of(plan: BasePlan, cells: Rect2i, inset: float) -> Rect2:
	var cell: float = BasePlanPainter.CELL * plan.view.scale()
	var at: Vector2 = plan.view.offset + Vector2(cells.position) * cell
	return Rect2(at, Vector2(cells.size) * cell).grow(-inset)


## A corridor cell; [param open] (left, right, up, down) joins it to its corridor neighbours.
static func corridor(canvas: CanvasItem, area: Rect2, open: Array[bool]) -> void:
	var r: Rect2 = area.grow(-8.0)
	if open[0]:
		r = r.grow_side(SIDE_LEFT, 8.0)
	if open[1]:
		r = r.grow_side(SIDE_RIGHT, 8.0)
	if open[2]:
		r = r.grow_side(SIDE_TOP, 8.0)
	if open[3]:
		r = r.grow_side(SIDE_BOTTOM, 8.0)
	canvas.draw_rect(r, CORRIDOR)


## A room tile over [param area] (cells inset 4) for [param tile].
static func room(canvas: CanvasItem, area: Rect2, tile: PlanTile) -> void:
	var fill: Color = {&"on": ON_FILL, &"site": SITE_FILL}.get(tile.state, OFF_FILL)
	var rim: Color = {&"on": RefPaint.GREEN, &"site": SITE_RIM}.get(tile.state, OFF_RIM)
	if tile.power_view:
		fill = POWER_FILL if tile.state == &"on" else Color8(28, 30, 32)
		rim = RefPaint.AMBER if tile.state == &"on" else OFF_RIM
	if tile.state == &"on" and not tile.power_view:
		for k: int in 4:
			canvas.draw_rect(area.grow(2.0 + k * 3.0), Color(RefPaint.GREEN, 0.05), false, 3.0)
	canvas.draw_rect(area, fill)
	canvas.draw_rect(area, rim, false, 2.0)
	if tile.gate:
		var c: Vector2 = area.get_center() + Vector2(0, 8)
		var r: float = minf(area.size.x, area.size.y) * 0.3
		canvas.draw_arc(c, r, 0.0, TAU, 48, Color8(150, 156, 150), 10.0, true)
	RoomIcon.draw(canvas, area.position + Vector2(24, 24), 24.0, tile.def_id, RefPaint.TEXT)
	var name_style: RefText = RefText.make(RefText.LABEL, 18, RefPaint.TEXT, 2.0)
	name_style.draw(canvas, area.position + Vector2(44, 24), tile.name, "lm")
	if tile.power_view:
		PowerCells.draw(canvas, area, tile.mw_value, tile.produces)
		return
	if tile.state == &"on":
		RefPaint.lamp_on(
			canvas, Vector2(area.end.x - 18, area.position.y + 22), 6.0, RefPaint.GREEN
		)
	if tile.state == &"site":
		_site(canvas, area, tile)
	_slots(canvas, area, tile)
	if tile.assign == &"no":
		canvas.draw_rect(area.grow(2.0), Color(0.04, 0.045, 0.04, 0.6))
	elif tile.assign == &"ok":
		canvas.draw_rect(area, Color(RefPaint.GREEN, 0.12))
		for k: int in 5:
			canvas.draw_rect(
				area.grow(2.0 + k * 3.0), Color(RefPaint.GREEN, 0.4 - k * 0.07), false, 3.0
			)


## The amber selection round [param area].
static func selection(canvas: CanvasItem, area: Rect2) -> void:
	canvas.draw_rect(area.grow(3.0), RefPaint.AMBER, false, 4.0)


static func _site(canvas: CanvasItem, area: Rect2, tile: PlanTile) -> void:
	var bar: Rect2 = Rect2(area.position.x + 14, area.end.y - 26, area.size.x - 28, 10)
	canvas.draw_rect(bar, Color8(20, 20, 18))
	canvas.draw_rect(
		Rect2(bar.position, Vector2(bar.size.x * tile.progress, bar.size.y)), RefPaint.AMBER
	)
	canvas.draw_rect(bar, RefPaint.EDGE, false, 1.0)
	var caption: RefText = RefText.make(RefText.MONO, 15, RefPaint.DIM)
	caption.draw(canvas, Vector2(bar.position.x, bar.position.y - 14), tile.caption, "lm")


static func _slots(canvas: CanvasItem, area: Rect2, tile: PlanTile) -> void:
	if tile.state == &"site":
		return
	var letter: RefText = RefText.make(RefText.LABEL, 15, RefPaint.INK)
	for k: int in tile.slots:
		var c: Vector2 = Vector2(area.position.x + 24 + k * SLOT_PITCH, area.end.y - 22)
		if k < tile.letters.size():
			canvas.draw_circle(c, 13.0, RefPaint.EDGE)
			canvas.draw_circle(c, 11.0, RefPaint.TEXT)
			letter.draw(canvas, c, tile.letters[k], "mm")
		else:
			canvas.draw_arc(c, 10.0, 0.0, TAU, 24, RefPaint.DIM, 2.0, true)
