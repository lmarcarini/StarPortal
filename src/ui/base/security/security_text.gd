class_name SecurityText
extends RefCounted
## The Security strip's words (M4c-12).
## Bible: docs/content/m4c-incursions.md section 7


## "Squad 1 · 2/3 · Hold · Level 1".
static func squad_row(state: GameState, squad: SquadState) -> String:
	var post: RoomState = state.base.find_room(squad.post_room)
	var total: int = 0
	for person: PersonState in state.staff.people:
		if person.room_id == squad.post_room and person.role == SquadRules.SOLDIER:
			total += 1
	var standing: int = SquadRules.members(state, squad.post_room).size()
	return (
		_tr(&"SECURITY_SQUAD_ROW")
		. format(
			{
				"number": SquadRules.number_of(state, squad.post_room),
				"standing": standing,
				"total": total,
				"order":
				_tr(StringName("SECURITY_ORDER_" + SquadState.ORDER_NAMES[squad.order].to_upper())),
				"level": squad.pos.z if post != null else 0,
			}
		)
	)


## "Door L1 (24, 9): Sealed".
static func door_row(door: DoorState) -> String:
	var key: StringName = (
		&"SECURITY_DOOR_SEALED" if door.mode == DoorState.Mode.SEALED else &"SECURITY_DOOR_OPEN"
	)
	if not door.is_built():
		key = &"SECURITY_DOOR_BUILDING"
	return _tr(key).format({"level": door.level, "x": door.cell.x, "y": door.cell.y})


## Where [param door] stands, for a player: "L1 · BY RESEARCH LAB" (the nearest room
## within two cells) or "L1 · CORRIDOR".
static func door_place(state: GameState, door: DoorState) -> String:
	var best: RoomState = null
	var best_distance: float = 2.5
	for room: RoomState in BaseRules.rooms_on_level(state.base, door.level):
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def == null or room.def_id == StartingBase.CORRIDOR_DEF:
			continue
		var cells: Rect2i = BaseRules.footprint(room, def)
		var inside: Vector2 = Vector2(door.cell).clamp(
			Vector2(cells.position), Vector2(cells.end - Vector2i.ONE)
		)
		var distance: float = inside.distance_to(Vector2(door.cell))
		if distance < best_distance:
			best = room
			best_distance = distance
	if best == null:
		return _tr(&"SECURITY_DOOR_CORRIDOR").format({"level": door.level})
	var room_name: String = _tr(state.room_defs[best.def_id].name_key).to_upper()
	return _tr(&"SECURITY_DOOR_BY").format({"level": door.level, "room": room_name})


## The line after an order: what was ordered, or why it was refused.
static func result(outcome: CommandResult, what: SquadState.Order) -> String:
	if outcome.is_ok:
		return _tr(StringName("SECURITY_ORDER_" + SquadState.ORDER_NAMES[what].to_upper()))
	var key: String = "SECURITY_ERR_" + String(outcome.error_code).to_upper()
	var text: String = _tr(StringName(key))
	return text if text != key else _tr(&"BASE_BUILD_ERR_OTHER")


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
