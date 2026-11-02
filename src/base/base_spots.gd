class_name BaseSpots
extends RefCounted
## Pure search for a place to put a room (docs/content/m2-base.md section 6): the valid spot
## nearest to a target area, such as the Gate Room's walls for the first Capacitor Bank. No side
## effects; never touches a Node.
## Bible: docs/content/m2-base.md sections 4 and 6

## Returned by [method nearest_spot] when no spot on the level is valid.
const NO_SPOT: Vector2i = Vector2i(-1, -1)


## Returns the origin of the nearest valid spot for an unturned [param def_id] on [param level]
## of [param base] to [param target], or [constant NO_SPOT]. Valid: it breaks no placement rule
## (BaseRules.placement_error) and touches a corridor, lift or stairs; money is not checked.
## Nearest: the fewest empty cells between the footprint and [param target] (a gap of 0 shares
## a wall), then the closest centres, then the top-most row, then the left-most column.
## [param defs] holds RoomDefs by id.
static func nearest_spot(
	base: BaseState, defs: Dictionary, def_id: StringName, level: int, target: Rect2i
) -> Vector2i:
	var def: RoomDef = _def(defs, def_id)
	if def == null:
		return NO_SPOT
	var best: Vector2i = NO_SPOT
	var best_key: Vector2i = Vector2i.MAX
	for y: int in range(base.grid_size.y - def.size_cells.y + 1):
		for x: int in range(base.grid_size.x - def.size_cells.x + 1):
			var probe := RoomState.create(&"", def_id, level, Vector2i(x, y))
			if not _valid(base, defs, probe):
				continue
			var area := Rect2i(probe.origin, def.size_cells)
			var key := Vector2i(gap(area, target), _centre_distance(area, target))
			if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
				best_key = key
				best = probe.origin
	return best


## The number of empty cells between [param a] and [param b] across plus down: 0 when they
## share a wall or overlap.
static func gap(a: Rect2i, b: Rect2i) -> int:
	var across: int = maxi(0, maxi(a.position.x - b.end.x, b.position.x - a.end.x))
	var down: int = maxi(0, maxi(a.position.y - b.end.y, b.position.y - a.end.y))
	return across + down


## Squared distance between the centres of [param a] and [param b], in half cells.
static func _centre_distance(a: Rect2i, b: Rect2i) -> int:
	var delta: Vector2i = (a.position * 2 + a.size) - (b.position * 2 + b.size)
	return delta.x * delta.x + delta.y * delta.y


static func _valid(base: BaseState, defs: Dictionary, probe: RoomState) -> bool:
	if not BaseRules.placement_error(base, defs, probe).is_empty():
		return false
	return BaseRules.touches_connector(base, defs, probe)


## Returns the Gate Room of [param base], or null.
static func gate_room(base: BaseState) -> RoomState:
	for room: RoomState in base.rooms:
		if room.def_id == StartingBase.GATE_ROOM_DEF:
			return room
	return null


## Returns the origin of the nearest valid spot for a Capacitor Bank to the Gate Room, on the
## Gate Room's level, or [constant NO_SPOT] (also when there is no Gate Room).
static func bank_spot(base: BaseState, defs: Dictionary) -> Vector2i:
	var gate: RoomState = gate_room(base)
	var gate_def: RoomDef = _def(defs, StartingBase.GATE_ROOM_DEF)
	if gate == null or gate_def == null:
		return NO_SPOT
	var target: Rect2i = BaseRules.footprint(gate, gate_def)
	return nearest_spot(base, defs, StartingBase.CAPACITOR_BANK_DEF, gate.level, target)


static func _def(defs: Dictionary, def_id: StringName) -> RoomDef:
	var found: Variant = defs.get(def_id)
	return found if found is RoomDef else null
