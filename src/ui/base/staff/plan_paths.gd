class_name PlanPaths
extends RefCounted
## Walking paths for staff tokens over the base plan, pure. Cells are walkable when a built
## room stands on them. A step inside one room is free; a step between two rooms needs one of
## them to be a corridor, lift or stairs (doors open onto those), so paths never cross a wall
## between two rooms. Lifts and stairs join the same cell on the levels above and below.
## Points are Vector3(cell x + 0.5, cell y + 0.5, level): cell centres, with the level.
## Bible: docs/content/interface-pass.md section 5 (Staff walk)

## Room types a door opens onto, and that join levels.
const HALLS: Array[StringName] = [&"room_corridor", &"room_lift", &"room_stairs"]
const SHAFTS: Array[StringName] = [&"room_lift", &"room_stairs"]
const _STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## The path of cell centres from [param from] to [param to] (Vector3i: cell x, cell y,
## level) over [param base] with RoomDefs [param defs]; empty when there is none.
static func find(
	base: BaseState, from: Vector3i, to: Vector3i, defs: Dictionary
) -> PackedVector3Array:
	var cells: Dictionary[Vector3i, RoomState] = occupancy(base, defs)
	if not cells.has(from) or not cells.has(to):
		return PackedVector3Array()
	var came: Dictionary[Vector3i, Vector3i] = {from: from}
	var frontier: Array[Vector3i] = [from]
	var head: int = 0
	while head < frontier.size():
		var cell: Vector3i = frontier[head]
		head += 1
		if cell == to:
			return _trace(came, from, to)
		for next: Vector3i in _neighbours(cells, cell):
			if not came.has(next):
				came[next] = cell
				frontier.append(next)
	return PackedVector3Array()


## Every walkable cell (x, y, level) with the room on it.
static func occupancy(base: BaseState, defs: Dictionary) -> Dictionary[Vector3i, RoomState]:
	var cells: Dictionary[Vector3i, RoomState] = {}
	for room: RoomState in base.rooms:
		var def: RoomDef = defs.get(room.def_id)
		if def == null or not room.is_built():
			continue
		var area: Rect2i = BaseRules.footprint(room, def)
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				cells[Vector3i(x, y, room.level)] = room
	return cells


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
) -> PackedVector3Array:
	var cells: Array[Vector3i] = [to]
	var cell: Vector3i = to
	while cell != from:
		cell = came[cell]
		cells.append(cell)
	cells.reverse()
	var points := PackedVector3Array()
	for step: Vector3i in cells:
		points.append(Vector3(step.x + 0.5, step.y + 0.5, step.z))
	return points
