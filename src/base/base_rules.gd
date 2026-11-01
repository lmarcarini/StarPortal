class_name BaseRules
extends RefCounted
## Pure rules of the base plan: a room's footprint, whether a room fits where it stands, the
## rooms on a level and a room's neighbours. No side effects; never touches a Node.
## Bible: game-design.md#base-building-and-power, docs/content/m2-base.md section 4

## Stairs def id: joins one level to the next.
const STAIRS_DEF: StringName = &"room_stairs"


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


## True for a def that connects rooms: a corridor, a lift or stairs (m2-base.md section 4).
static func is_connector(def_id: StringName) -> bool:
	return def_id in [StartingBase.CORRIDOR_DEF, StartingBase.LIFT_DEF, STAIRS_DEF]


## True for one level of the starting lift shaft: it can never be demolished.
static func is_starting_lift(room: RoomState) -> bool:
	return (
		room.def_id == StartingBase.LIFT_DEF
		and room.origin == StartingBase.LIFT_ORIGIN
		and room.site.is_empty()
	)


## The first placement rule [param room] breaks in [param base], as an error code, or &"" when
## it may stand there: &"unknown_room", &"not_rotatable", &"no_such_level", &"level_not_dug",
## &"outside_level" or &"overlap" (with any room, corridor or site; a room with the same id is
## ignored). [param defs] holds RoomDefs by id.
static func placement_error(base: BaseState, defs: Dictionary, room: RoomState) -> StringName:
	var def: RoomDef = _def_of(defs, room.def_id)
	if def == null:
		return &"unknown_room"
	if room.rotated and not def.rotatable:
		return &"not_rotatable"
	if room.level < 1 or room.level > base.level_count:
		return &"no_such_level"
	if not base.levels[room.level - 1].is_dug():
		return &"level_not_dug"
	var area: Rect2i = footprint(room, def)
	if not Rect2i(Vector2i.ZERO, base.grid_size).encloses(area):
		return &"outside_level"
	if overlaps(base, defs, room.level, area):
		return &"overlap"
	return &""


## True when [param area] on [param level] overlaps any room of [param base].
static func overlaps(base: BaseState, defs: Dictionary, level: int, area: Rect2i) -> bool:
	for other: RoomState in rooms_on_level(base, level):
		var other_def: RoomDef = _def_of(defs, other.def_id)
		if other_def != null and footprint(other, other_def).intersects(area):
			return true
	return false


## True when [param room] shares a cell edge with a corridor, lift or stairs of [param base]
## (built or a site), skipping rooms whose id is in [param ignored].
static func touches_connector(
	base: BaseState, defs: Dictionary, room: RoomState, ignored: Array[StringName] = []
) -> bool:
	for other: RoomState in neighbours(base, defs, room):
		if is_connector(other.def_id) and not other.id in ignored:
			return true
	return false


## The rooms of [param base] in the site [param site_key], in placement order.
static func site_rooms(base: BaseState, site_key: StringName) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for room: RoomState in base.rooms:
		if room.site_key() == site_key:
			found.append(room)
	return found


## What the whole site [param rooms] cost, in $k: the def's cost per cell for a corridor run,
## the def's cost once for any other site (a lift shaft or stairs pays once).
static func site_cost_k(defs: Dictionary, rooms: Array[RoomState]) -> int:
	var total: int = 0
	for room: RoomState in rooms:
		var def: RoomDef = _def_of(defs, room.def_id)
		if def == null:
			continue
		if room.def_id != StartingBase.CORRIDOR_DEF:
			return def.build_cost_k
		total += def.build_cost_k
	return total


## True when taking [param removing] out of [param base] would leave a room or site (not a
## corridor, lift or stairs) that touches a connector today touching none. Rooms already being
## demolished count as gone, both today and after.
static func strands_a_room(base: BaseState, defs: Dictionary, removing: Array[RoomState]) -> bool:
	var leaving: Array[StringName] = []
	for room: RoomState in base.rooms:
		if room.is_demolishing():
			leaving.append(room.id)
	var gone: Array[StringName] = leaving.duplicate()
	var levels: Array[int] = []
	for room: RoomState in removing:
		gone.append(room.id)
		levels.append(room.level)
	for other: RoomState in base.rooms:
		if other.level not in levels or other.id in gone or is_connector(other.def_id):
			continue
		if (
			touches_connector(base, defs, other, leaving)
			and not touches_connector(base, defs, other, gone)
		):
			return true
	return false
