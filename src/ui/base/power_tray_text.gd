class_name PowerTrayText
extends RefCounted
## The POWER tray's words and rooms (pure).
## Bible: docs/content/interface-reference.md section 8


## "SUPPLY 30 MW · USED 25 · CHARGING 5" for [param state].
static func line(state: GameState) -> String:
	return (
		TranslationServer
		. translate(&"BASE_POWER_LINE")
		. format(
			{
				"supply": roundi(PowerRules.supply_mw(state)),
				"used": roundi(PowerRules.room_draw_mw(state)),
				"charging": roundi(PowerRules.charge_mw(state)),
			}
		)
	)


## The built rooms with a power switch, on every level, in base order.
static func switchable(state: GameState) -> Array[RoomState]:
	var out: Array[RoomState] = []
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def != null and room.is_built() and PowerRules.has_switch(def):
			out.append(room)
	return out


## The MW tag of [param room] on the POWER plan: "+30 MW" for a producer, "5 MW" for a draw,
## "" for none.
static func tag(_room: RoomState, def: RoomDef) -> String:
	if def.power_output_mw > 0.0:
		return "+%d MW" % roundi(def.power_output_mw)
	if def.power_draw_mw > 0.0:
		return "%d MW" % roundi(def.power_draw_mw)
	return ""
