class_name LabLayout
extends RefCounted
## The Lab station's regions at 1920 x 1080 (docs/reference/layout.json lab_*,
## interface-reference.md section 9) and where the board puts its tiles. A wider window moves
## the panel right by the extra width and widens the tabs and the board; nothing else moves.
## Bible: docs/content/interface-reference.md sections 1 and 9

const REGIONS: Dictionary[StringName, Rect2] = {
	&"lab_tabs": Rect2(408, 96, 1112, 56),
	&"lab_board": Rect2(408, 160, 1112, 704),
	&"lab_panel": Rect2(1536, 92, 368, 772),
	&"lab_benches": Rect2(668, 908, 824, 144),
}
## A project tile's size.
const TILE: Vector2 = Vector2(260, 68)
## From one column of tiles to the next, and one row to the next.
const PITCH: Vector2 = Vector2(320, 100)
## The first tile's top left corner inside the board's glass.
const FIRST: Vector2 = Vector2(42, 20)
## The glass inside the board's steel plate.
const GLASS_INSET: float = 20.0


## Region [param id] for a view [param width] wide.
static func region(id: StringName, width: float) -> Rect2:
	var r: Rect2 = REGIONS[id]
	var extra: float = maxf(0.0, width - FrameLayout.WIDTH)
	if id == &"lab_panel":
		r.position.x += extra
	elif id == &"lab_tabs" or id == &"lab_board":
		r.size.x += extra
	return r


## Puts [param control] on region [param id] in a view [param width] wide.
static func place(control: Control, id: StringName, width: float) -> void:
	var r: Rect2 = region(id, width)
	control.position = r.position
	control.size = r.size


## The cell (column, row) of each of [param defs] (visible projects, in list order): a
## project's column is one past the furthest of its shown prerequisites (0 with none); its
## row is its first shown prerequisite's row when that is free, else the next free row of
## its column.
static func cells(defs: Array[ResearchDef]) -> Dictionary[StringName, Vector2i]:
	var found: Dictionary[StringName, Vector2i] = {}
	var used: Dictionary[Vector2i, bool] = {}
	var pending: Array[ResearchDef] = defs.duplicate()
	var guard: int = pending.size() + 1
	while not pending.is_empty() and guard > 0:
		guard -= 1
		var rest: Array[ResearchDef] = []
		for def: ResearchDef in pending:
			if not _place(def, defs, found, used):
				rest.append(def)
		pending = rest
	for def: ResearchDef in pending:
		_put(def.id, Vector2i(0, _free_row(used, 0, 0)), found, used)
	return found


## Top left of [param cell] on the board.
static func cell_position(cell: Vector2i) -> Vector2:
	return FIRST + Vector2(cell.x * PITCH.x, cell.y * PITCH.y)


static func _place(
	def: ResearchDef,
	defs: Array[ResearchDef],
	found: Dictionary[StringName, Vector2i],
	used: Dictionary[Vector2i, bool]
) -> bool:
	var column: int = 0
	var row: int = -1
	for need: StringName in def.needs:
		if not _shown(defs, need):
			continue
		if not found.has(need):
			return false
		column = maxi(column, found[need].x + 1)
		if row < 0:
			row = found[need].y
	_put(def.id, Vector2i(column, _free_row(used, column, maxi(row, 0))), found, used)
	return true


static func _put(
	id: StringName,
	cell: Vector2i,
	found: Dictionary[StringName, Vector2i],
	used: Dictionary[Vector2i, bool]
) -> void:
	found[id] = cell
	used[cell] = true


static func _free_row(used: Dictionary[Vector2i, bool], column: int, from: int) -> int:
	var row: int = from
	while used.has(Vector2i(column, row)):
		row += 1
	return row


static func _shown(defs: Array[ResearchDef], id: StringName) -> bool:
	for def: ResearchDef in defs:
		if def.id == id:
			return true
	return false
