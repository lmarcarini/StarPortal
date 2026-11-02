class_name BasePlanPainter
extends RefCounted
## Draws one level of the base plan, straight from above, in the lit-diorama placeholder look:
## dark rock, concrete floors, a wall outline, a few furniture blocks, a warm light pool where a
## built room is on, darker corridors, hatched sites and a label. A room without power is
## dimmed, its light out, and carries the "no power" mark. Only rectangles, circles and
## text, so it stays cheap on the Compatibility renderer. Coordinates are plan pixels
## ([constant CELL] per cell); the caller sets the canvas transform for zoom and pan.
## Bible: docs/content/m2-base.md section 6

## Plan pixels per cell at 1× zoom.
const CELL: float = 24.0
## Palette of the chosen mock-up (concept B).
const ROCK := Color("#1c1915")
const GRID := Color("#23261d")
const FLOOR := Color("#a9a793")
const FLOOR_OFF := Color("#6e6c5e")
const CORRIDOR := Color("#5b5e51")
const WALL := Color("#3b4031")
const FURNITURE := Color("#3b4031")
const LIGHT := Color("#f59e3b")
const SITE := Color("#4d5560")
const SITE_LINE := Color("#b9b29c")
const LABEL := Color("#efe6d2")
const SELECTED := Color("#f5c27a")
const CURSOR := Color("#ffe1b0")
const _WALL_WIDTH: float = 2.0
## Size of the "no power" mark on an unlit room, in plan pixels.
const NO_POWER_MARK: float = 14.0


## Fills the rock and the faint cell grid of a [param grid_size] level.
static func draw_ground(canvas: CanvasItem, grid_size: Vector2i) -> void:
	var size := Vector2(grid_size) * CELL
	canvas.draw_rect(Rect2(Vector2.ZERO, size), ROCK)
	for column: int in range(1, grid_size.x):
		canvas.draw_line(Vector2(column * CELL, 0), Vector2(column * CELL, size.y), GRID)
	for row: int in range(1, grid_size.y):
		canvas.draw_line(Vector2(0, row * CELL), Vector2(size.x, row * CELL), GRID)


## Draws a corridor cell: darker concrete, no light.
static func draw_corridor(canvas: CanvasItem, cells: Rect2i) -> void:
	canvas.draw_rect(_pixels(cells), CORRIDOR)


## Draws a built room of [param def_id] over [param cells]: floor, light pool when
## [param lit], furniture and walls. An unlit room is shaded and gets the "no power" mark.
static func draw_room(canvas: CanvasItem, cells: Rect2i, def_id: StringName, lit: bool) -> void:
	var area: Rect2 = _pixels(cells)
	canvas.draw_rect(area, FLOOR if lit else FLOOR_OFF)
	if lit:
		_draw_light(canvas, area)
	BasePlanFurniture.draw(canvas, area, def_id)
	if not lit:
		canvas.draw_rect(area, PowerMarks.OFF_SHADE)
		PowerMarks.draw_no_power(canvas, no_power_mark_centre(cells), NO_POWER_MARK)
	canvas.draw_rect(area, WALL, false, _WALL_WIDTH)


## Where the "no power" mark of an unlit room over [param cells] sits: its bottom-right
## corner, clear of the label at the top-left.
static func no_power_mark_centre(cells: Rect2i) -> Vector2:
	return _pixels(cells).end - Vector2.ONE * (NO_POWER_MARK * 0.5 + 3.0)


## Draws a site over [param cells]: blueprint hatching and a dashed-looking outline. Used for
## rooms under construction.
static func draw_site(canvas: CanvasItem, cells: Rect2i) -> void:
	var area: Rect2 = _pixels(cells)
	canvas.draw_rect(area, SITE)
	var step: float = CELL * 0.5
	var span: float = area.size.x + area.size.y
	var t: float = step
	while t < span:
		var top_x: float = minf(t, area.size.x)
		var left_y: float = minf(t, area.size.y)
		var from: Vector2 = area.position + Vector2(top_x, t - top_x)
		var to: Vector2 = area.position + Vector2(t - left_y, left_y)
		canvas.draw_line(from, to, Color(SITE_LINE, 0.35))
		t += step
	canvas.draw_rect(area, SITE_LINE, false, 1.0)


## Writes [param text] at the top-left of [param cells], fitted by [PlanLabel] (wrapped or
## smaller when it is wider than the room).
static func draw_label(canvas: CanvasItem, cells: Rect2i, text: String, font: Font) -> void:
	var area: Rect2 = _pixels(cells).grow(-PlanLabel.INSET)
	var fitted: Dictionary = PlanLabel.fit(text, _pixels(cells).size, font)
	var size: int = fitted["size"]
	var lines: Array = fitted["lines"]
	var at := area.position + Vector2(0, size)
	for line: String in lines:
		canvas.draw_string(font, at + Vector2.ONE, line, 0, -1, size, Color(ROCK, 0.8))
		canvas.draw_string(font, at, line, 0, -1, size, LABEL)
		at.y += PlanLabel.line_height(size)


## Outlines [param cells] as the selection.
static func draw_selection(canvas: CanvasItem, cells: Rect2i) -> void:
	canvas.draw_rect(_pixels(cells).grow(2.0), SELECTED, false, 3.0)


## Outlines the one cell under the keyboard or gamepad cursor.
static func draw_cursor(canvas: CanvasItem, cell: Vector2i) -> void:
	canvas.draw_rect(_pixels(Rect2i(cell, Vector2i.ONE)).grow(-1.0), CURSOR, false, 1.5)


## Returns [param cells] in plan pixels.
static func _pixels(cells: Rect2i) -> Rect2:
	return Rect2(Vector2(cells.position) * CELL, Vector2(cells.size) * CELL)


## A warm sodium pool from the ceiling fitting: a few stacked translucent circles.
static func _draw_light(canvas: CanvasItem, area: Rect2) -> void:
	var radius: float = minf(area.size.x, area.size.y) * 0.48
	for step: int in 4:
		var scale: float = 1.0 - step * 0.22
		canvas.draw_circle(area.get_center(), radius * scale, Color(LIGHT, 0.10))
	canvas.draw_circle(area.get_center(), 2.5, Color(CURSOR, 0.9))
