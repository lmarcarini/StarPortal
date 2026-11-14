class_name BasePaths
extends RefCounted
## Walking paths over the base, pure (M4c-03; moved from the plan's staff tokens). Cells are
## walkable when a built room stands on them, damaged or not. A step inside one room is free;
## a step between two rooms needs one of them to be a corridor, lift or stairs (doors open
## onto those), so paths never cross a wall between two rooms. Lifts and stairs join the same
## cell on the levels above and below. A sealed blast door's cell cannot be entered unless
## doors are ignored. Neighbours are tried in a fixed order, so results are deterministic.
## Points are Vector3(cell x + 0.5, cell y + 0.5, level): cell centres, with the level.
## Bible: docs/content/m4c-incursions.md sections 3 and 4,
## docs/content/interface-pass.md section 5 (Staff walk)

## Room types a door opens onto, and that join levels.
const HALLS: Array[StringName] = [&"room_corridor", &"room_lift", &"room_stairs"]
const SHAFTS: Array[StringName] = [&"room_lift", &"room_stairs"]
## No door, as returned by first_sealed_door().
const NO_DOOR: Vector3i = Vector3i(-1, -1, -1)
const _STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

# Occupancy cache: rebuilt when the base, its room count or RoomState.revision changes.
static var _cached_base_id: int = 0
static var _cached_key: Vector2i = Vector2i(-1, -1)
static var _cached_cells: Dictionary[Vector3i, RoomState] = {}


## The path of cell centres from [param from] to [param to] (Vector3i: cell x, cell y,
## level) over [param base] with RoomDefs [param defs]; empty when there is none. With
## [param ignore_doors], sealed doors do not block.
static func find(
	base: BaseState, from: Vector3i, to: Vector3i, defs: Dictionary, ignore_doors: bool = false
) -> PackedVector3Array:
	var cells: Array[Vector3i] = _search(base, from, to, defs, ignore_doors)
	var points := PackedVector3Array()
	for step: Vector3i in cells:
		points.append(Vector3(step.x + 0.5, step.y + 0.5, step.z))
	return points


## The first sealed door on the shortest path from [param from] to [param to] if doors were
## ignored, or NO_DOOR when that path has none or there is no path at all.
static func first_sealed_door(
	base: BaseState, from: Vector3i, to: Vector3i, defs: Dictionary
) -> Vector3i:
	var sealed: Dictionary[Vector3i, bool] = sealed_cells(base)
	for cell: Vector3i in _search(base, from, to, defs, true):
		if sealed.has(cell):
			return cell
	return NO_DOOR


## Steps along the path from [param from] to [param to], or −1 when there is none.
static func walking_distance(
	base: BaseState, from: Vector3i, to: Vector3i, defs: Dictionary, ignore_doors: bool = false
) -> int:
	var cells: Array[Vector3i] = _search(base, from, to, defs, ignore_doors)
	return cells.size() - 1


## The cells of [param base]'s sealed blast doors.
static func sealed_cells(base: BaseState) -> Dictionary[Vector3i, bool]:
	var found: Dictionary[Vector3i, bool] = {}
	for door: DoorState in base.doors:
		if door.mode == DoorState.Mode.SEALED:
			found[Vector3i(door.cell.x, door.cell.y, door.level)] = true
	return found


## Every walkable cell (x, y, level) with the room on it; cached per base change.
static func occupancy(base: BaseState, defs: Dictionary) -> Dictionary[Vector3i, RoomState]:
	var key := Vector2i(RoomState.revision, base.rooms.size())
	if base.get_instance_id() == _cached_base_id and key == _cached_key:
		return _cached_cells
	var cells: Dictionary[Vector3i, RoomState] = {}
	for room: RoomState in base.rooms:
		var def: RoomDef = defs.get(room.def_id)
		if def == null or not room.is_built():
			continue
		var area: Rect2i = BaseRules.footprint(room, def)
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				cells[Vector3i(x, y, room.level)] = room
	_cached_base_id = base.get_instance_id()
	_cached_key = key
	_cached_cells = cells
	return cells


static func _search(
	base: BaseState, from: Vector3i, to: Vector3i, defs: Dictionary, ignore_doors: bool
) -> Array[Vector3i]:
	var cells: Dictionary[Vector3i, RoomState] = occupancy(base, defs)
	var blocked: Dictionary[Vector3i, bool] = {}
	if not ignore_doors:
		blocked = sealed_cells(base)
	if not cells.has(from) or not cells.has(to) or blocked.has(to):
		return []
	var came: Dictionary[Vector3i, Vector3i] = {from: from}
	var frontier: Array[Vector3i] = [from]
	var head: int = 0
	while head < frontier.size():
		var cell: Vector3i = frontier[head]
		head += 1
		if cell == to:
			return _trace(came, from, to)
		for next: Vector3i in _neighbours(cells, cell):
			if not came.has(next) and not blocked.has(next):
				came[next] = cell
				frontier.append(next)
	return []


static func _neighbours(cells: Dictionary[Vector3i, RoomState], cell: Vector3i) -> Array[Vector3i]:
	var found: Array[Vector3i] = []
	var room: RoomState = cells[cell]
	for step: Vector2i in _STEPS:
		var next := Vector3i(cell.x + step.x, cell.y + step.y, cell.z)
		var other: RoomState = cells.get(next)
		if other == null:
			continue
		if other == room or HALLS.has(room.def_id) or HALLS.has(other.def_id):
			found.append(next)
	if SHAFTS.has(room.def_id):
		for dz: int in [-1, 1]:
			var next := Vector3i(cell.x, cell.y, cell.z + dz)
			var other: RoomState = cells.get(next)
			if other != null and SHAFTS.has(other.def_id):
				found.append(next)
	return found


static func _trace(
	came: Dictionary[Vector3i, Vector3i], from: Vector3i, to: Vector3i
) -> Array[Vector3i]:
	var cells: Array[Vector3i] = [to]
	var cell: Vector3i = to
	while cell != from:
		cell = came[cell]
		cells.append(cell)
	cells.reverse()
	return cells
