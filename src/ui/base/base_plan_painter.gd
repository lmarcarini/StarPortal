class_name BasePlanPainter
extends RefCounted
## Draws one level of the base plan, straight from above, as a clean schematic
## (docs/content/interface-pass.md section 5): flat room fills by state, a stencilled name, a
## room-type icon, thin furniture marks from a set zoom, and a soft inner glow on rooms that
## are on. Each state differs by a mark as well as by colour: on (glow), off (dim fill,
## dashed wall and the "no power" mark), site (hatching), coming down (hatching and a cross).
## Colours come from UiPalette. Only lines, rectangles, circles and text, so it stays cheap on
## the Compatibility renderer. Coordinates are plan pixels ([constant CELL] per cell); the
## caller sets the canvas transform for zoom and pan.
## Bible: docs/content/interface-pass.md section 5, docs/content/m2-base.md section 6

## Plan pixels per cell at 1× zoom.
const CELL: float = 24.0
## Room states the plan draws.
const ON: StringName = &"on"
const OFF: StringName = &"off"
const SITE: StringName = &"site"
const COMING_DOWN: StringName = &"coming_down"
## Schematic colours, all from UiPalette.
const ROCK: Color = UiPalette.GROUND
const GRID: Color = Color(UiPalette.RULE, 0.35)
const FLOOR: Color = Color("#232c2b")
const FLOOR_OFF: Color = Color("#191e20")
const CORRIDOR: Color = UiPalette.HEADER
const WALL: Color = UiPalette.RULE
const FURNITURE: Color = Color(UiPalette.TEXT_DIM, 0.45)
const GLOW: Color = UiPalette.GOOD
const SITE_LINE: Color = UiPalette.TEXT_DIM
const DEMOLISH: Color = UiPalette.ALARM
const LABEL: Color = UiPalette.TEXT
const SELECTED: Color = UiPalette.SELECT
const CURSOR: Color = UiPalette.TEXT
## Zoom (canvas scale) from which furniture marks are drawn.
const FURNITURE_ZOOM: float = 1.0
## Size of the "no power" mark on an off room, in plan pixels.
const NO_POWER_MARK: float = 14.0
## Size of the room-type icon, in plan pixels.
const ICON_SIZE: float = 10.0
const _WALL_WIDTH: float = 1.5
const _GLOW_STEPS: int = 4


## The plan state of [param room] of [param def]: site, coming down, on or off.
static func state_of(room: RoomState, def: RoomDef) -> StringName:
	if not room.is_built():
		return SITE
	if room.is_demolishing():
		return COMING_DOWN
	if def == null or PowerRules.is_running(room, def) or not PowerRules.has_switch(def):
		return ON
	return OFF


## Fills the rock and the faint cell grid of a [param grid_size] level.
static func draw_ground(canvas: CanvasItem, grid_size: Vector2i) -> void:
	var size := Vector2(grid_size) * CELL
	canvas.draw_rect(Rect2(Vector2.ZERO, size), ROCK)
	for column: int in range(1, grid_size.x):
		canvas.draw_line(Vector2(column * CELL, 0), Vector2(column * CELL, size.y), GRID)
	for row: int in range(1, grid_size.y):
		canvas.draw_line(Vector2(0, row * CELL), Vector2(size.x, row * CELL), GRID)


## Draws a blast door on its cell (M4c-04). Open: two jambs at the cell's sides with a gap.
## Sealed: a solid bar across the cell with a cross. Being built: the jambs dashed.
static func draw_door(canvas: CanvasItem, door: DoorState) -> void:
	var area: Rect2 = _pixels(Rect2i(door.cell, Vector2i.ONE))
	var ink: Color = UiPalette.TEXT if door.is_built() else UiPalette.TEXT_DIM
	var jamb: float = area.size.x * 0.18
	if door.mode == DoorState.Mode.SEALED:
		var bar := Rect2(
			area.position + Vector2(0, area.size.y * 0.3), Vector2(area.size.x, area.size.y * 0.4)
		)
		canvas.draw_rect(bar, UiPalette.ALARM)
		canvas.draw_line(bar.position, bar.end, ink, 2.0)
		canvas.draw_line(
			Vector2(bar.position.x, bar.end.y), Vector2(bar.end.x, bar.position.y), ink, 2.0
		)
		return
	canvas.draw_rect(Rect2(area.position, Vector2(jamb, area.size.y)), ink, door.is_built(), 2.0)
	var right := Vector2(area.end.x - jamb, area.position.y)
	canvas.draw_rect(Rect2(right, Vector2(jamb, area.size.y)), ink, door.is_built(), 2.0)


## Draws a small mark per installation at [param cells]' bottom-left (M4c-19): a filled
## square once built, a hollow one while it is being fitted.
static func draw_installations(
	canvas: CanvasItem, cells: Rect2i, items: Array[InstallationState]
) -> void:
	var area: Rect2 = _pixels(cells)
	for index: int in items.size():
		var mark := Rect2(area.position + Vector2(4 + index * 9, area.size.y - 11), Vector2(7, 7))
		canvas.draw_rect(mark, UiPalette.SELECT, items[index].is_built(), 1.5)


## Draws a corridor cell: a flat lighter strip.
static func draw_corridor(canvas: CanvasItem, cells: Rect2i) -> void:
	canvas.draw_rect(_pixels(cells), CORRIDOR)


## Draws a built room of [param def_id] over [param cells] in [param state] (on or off) at
## canvas scale [param zoom]: fill, glow when on, furniture marks from
## [constant FURNITURE_ZOOM], the type icon and walls. An off room is dim with a dashed wall
## and the "no power" mark.
static func draw_room(
	canvas: CanvasItem, cells: Rect2i, def_id: StringName, state: StringName, zoom: float = 1.0
) -> void:
	var area: Rect2 = _pixels(cells)
	var on: bool = state == ON
	canvas.draw_rect(area, FLOOR if on else FLOOR_OFF)
	if on:
		_draw_glow(canvas, area)
	if zoom >= FURNITURE_ZOOM:
		BasePlanFurniture.draw(canvas, area, def_id)
	var ink: Color = UiPalette.TEXT_DIM if on else Color(UiPalette.TEXT_DIM, 0.5)
	RoomIcon.draw(canvas, icon_centre(cells), ICON_SIZE, def_id, ink)
	if on:
		canvas.draw_rect(area, WALL, false, _WALL_WIDTH)
		return
	_draw_dashed_rect(canvas, area, SITE_LINE)
	PowerMarks.draw_no_power(canvas, no_power_mark_centre(cells), NO_POWER_MARK)


## Where the type icon of a room over [param cells] sits: its top-right corner, clear of the
## label at the top-left.
static func icon_centre(cells: Rect2i) -> Vector2:
	var area: Rect2 = _pixels(cells)
	return Vector2(area.end.x - ICON_SIZE * 0.5 - 4.0, area.position.y + ICON_SIZE * 0.5 + 4.0)


## Where the "no power" mark of an off room over [param cells] sits: its bottom-right
## corner, clear of the label at the top-left.
static func no_power_mark_centre(cells: Rect2i) -> Vector2:
	return _pixels(cells).end - Vector2.ONE * (NO_POWER_MARK * 0.5 + 3.0)


## Draws a site over [param cells]: hatching and a thin outline. A room coming down also gets
## a cross in the alarm colour.
static func draw_site(canvas: CanvasItem, cells: Rect2i, coming_down: bool = false) -> void:
	var area: Rect2 = _pixels(cells)
	canvas.draw_rect(area, FLOOR_OFF)
	var step: float = CELL * 0.5
	var span: float = area.size.x + area.size.y
	var t: float = step
	while t < span:
		var top_x: float = minf(t, area.size.x)
		var left_y: float = minf(t, area.size.y)
		var from: Vector2 = area.position + Vector2(top_x, t - top_x)
		var to: Vector2 = area.position + Vector2(t - left_y, left_y)
		canvas.draw_line(from, to, Color(SITE_LINE, 0.3))
		t += step
	if coming_down:
		var ink := Color(DEMOLISH, 0.7)
		canvas.draw_line(area.position, area.end, ink, 2.0)
		canvas.draw_line(
			Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y), ink, 2.0
		)
	_draw_dashed_rect(canvas, area, DEMOLISH if coming_down else SITE_LINE)


## Writes [param text] at the top-left of [param cells], fitted by [PlanLabel] (wrapped or
## smaller when it is wider than the room), in the stencil font.
static func draw_label(canvas: CanvasItem, cells: Rect2i, text: String, font: Font) -> void:
	var area: Rect2 = _pixels(cells).grow(-PlanLabel.INSET)
	var fitted: Dictionary = PlanLabel.fit(text, _pixels(cells).size - Vector2(ICON_SIZE, 0), font)
	var size: int = fitted["size"]
	var lines: Array = fitted["lines"]
	var at := area.position + Vector2(0, size)
	for line: String in lines:
		canvas.draw_string(font, at, line, 0, -1, size, LABEL)
		at.y += PlanLabel.line_height(size)


## Outlines [param cells] as the selection, in orange.
static func draw_selection(canvas: CanvasItem, cells: Rect2i) -> void:
	var area: Rect2 = _pixels(cells).grow(2.0)
	canvas.draw_rect(area.grow(2.0), Color(SELECTED, 0.25), false, 3.0)
	canvas.draw_rect(area, SELECTED, false, 2.0)


## Outlines the one cell under the keyboard or gamepad cursor.
static func draw_cursor(canvas: CanvasItem, cell: Vector2i) -> void:
	canvas.draw_rect(_pixels(Rect2i(cell, Vector2i.ONE)).grow(-1.0), CURSOR, false, 1.5)


## Returns [param cells] in plan pixels.
static func _pixels(cells: Rect2i) -> Rect2:
	return Rect2(Vector2(cells.position) * CELL, Vector2(cells.size) * CELL)


## A soft inner glow along the walls of a room that is on.
static func _draw_glow(canvas: CanvasItem, area: Rect2) -> void:
	for step: int in _GLOW_STEPS:
		var inset: float = 1.5 + step * 2.0
		var alpha: float = 0.22 * (1.0 - float(step) / _GLOW_STEPS)
		canvas.draw_rect(area.grow(-inset), Color(GLOW, alpha), false, 2.0)


## A dashed outline of [param area].
static func _draw_dashed_rect(canvas: CanvasItem, area: Rect2, ink: Color) -> void:
	var corners: Array[Vector2] = [
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y),
	]
	for index: int in 4:
		canvas.draw_dashed_line(corners[index], corners[(index + 1) % 4], ink, 1.0, 4.0)
