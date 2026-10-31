class_name BaseRules
extends RefCounted
## Pure rules of the base plan: a room's footprint, whether a room fits where it stands, the
## rooms on a level and a room's neighbours. No side effects; never touches a Node.
## Bible: game-design.md#base-building-and-power


## Returns the cells [param room] covers as a [RoomDef] [param def]: its origin and the def's
## size, width and height swapped when the room is turned.
static func footprint(room: RoomState, def: RoomDef) -> Rect2i:
	var size: Vector2i = def.size_cells
	if room.rotated:
		size = Vector2i(size.y, size.x)
	return Rect2i(room.origin, size)


## True when [param room] can stand where it is in [param base]: its def is in [param defs]
## (RoomDef by id), it is turned only if the def is rotatable, its level exists and is dug, its
## footprint is inside the grid, and it overlaps no other room on its level (a room with the
## same id is ignored, so a placed room can be checked in place).
static func fits(base: BaseState, defs: Dictionary, room: RoomState) -> bool:
	var def: RoomDef = _def_of(defs, room.def_id)
	if def == null:
		return false
	if room.rotated and not def.rotatable:
		return false
	if room.level < 1 or room.level > base.level_count:
		return false
	if not base.levels[room.level - 1].is_dug():
		return false
	var area: Rect2i = footprint(room, def)
	if not Rect2i(Vector2i.ZERO, base.grid_size).encloses(area):
		return false
	for other: RoomState in rooms_on_level(base, room.level):
		if other.id == room.id:
			continue
		var other_def: RoomDef = _def_of(defs, other.def_id)
		if other_def != null and footprint(other, other_def).intersects(area):
			return false
	return true


## Returns the rooms of [param base] on [param level], in placement order.
static func rooms_on_level(base: BaseState, level: int) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for room: RoomState in base.rooms:
		if room.level == level:
			found.append(room)
	return found


## Returns the rooms on [param room]'s level sharing at least one cell edge with it (touching
## only at a corner does not count), in placement order. Rooms whose def is not in
## [param defs] are skipped.
static func neighbours(base: BaseState, defs: Dictionary, room: RoomState) -> Array[RoomState]:
	var found: Array[RoomState] = []
	var def: RoomDef = _def_of(defs, room.def_id)
	if def == null:
		return found
	var area: Rect2i = footprint(room, def)
	var wide: Rect2i = area.grow_individual(1, 0, 1, 0)
	var tall: Rect2i = area.grow_individual(0, 1, 0, 1)
	for other: RoomState in rooms_on_level(base, room.level):
		var other_def: RoomDef = _def_of(defs, other.def_id)
		if other.id == room.id or other_def == null:
			continue
		var other_area: Rect2i = footprint(other, other_def)
		if wide.intersects(other_area) or tall.intersects(other_area):
			found.append(other)
	return found


## The RoomDef with id [param def_id] in [param defs], or null when missing or not a RoomDef.
static func _def_of(defs: Dictionary, def_id: StringName) -> RoomDef:
	var found: Variant = defs.get(def_id)
	if found is RoomDef:
		return found
	return null
