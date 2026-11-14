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


## The line after an order: what was ordered, or why it was refused.
static func result(outcome: CommandResult, what: SquadState.Order) -> String:
	if outcome.is_ok:
		return _tr(StringName("SECURITY_ORDER_" + SquadState.ORDER_NAMES[what].to_upper()))
	var key: String = "SECURITY_ERR_" + String(outcome.error_code).to_upper()
	var text: String = _tr(StringName(key))
	return text if text != key else _tr(&"BASE_BUILD_ERR_OTHER")


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
