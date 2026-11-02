class_name FinishingPower
extends RefCounted
## The finishing-room rule (docs/content/m25-lean-start.md section 3, PO ruling): a room that
## finishes building switches on, taking power from charging first. When its draw is more than
## the spare supply, the Capacitor Bank charge rates come down, newest bank first, by just
## enough; no other room is ever switched off. If even zero charging is not enough, the room
## finishes off and the charge rates stay as they were. "Newest switchable rooms off first"
## (PowerSystem's shed) is left to losing a plant and to demolition.
## Posts charging_lowered(room id, total charge MW) or room_finished_off(room id, need MW,
## spare MW), each with power_allocation_changed().
## Bible: docs/content/m25-lean-start.md section 3


## Applies the rule to [param room] of [param state], which has just finished building. Call
## before PowerSystem.settle(), so the shed finds allocation already within supply.
static func switch_on(state: GameState, room: RoomState) -> void:
	var def: RoomDef = state.room_defs.get(room.def_id)
	if not PowerRules.has_switch(def) or def.power_output_mw > 0.0:
		return
	if not PowerRules.is_running(room, def):
		return
	var over: float = PowerRules.allocated_mw(state) - PowerRules.supply_mw(state)
	if over <= 0.0:
		return
	if over > PowerRules.charge_mw(state):
		room.powered_on = false
		var spare: int = floori(PowerRules.spare_mw(state))
		state.events.post(&"room_finished_off", [room.id, ceili(def.power_draw_mw), spare])
	else:
		lower_charging(state, ceili(over))
		state.events.post(&"charging_lowered", [room.id, roundi(PowerRules.charge_mw(state))])
	state.events.post(&"power_allocation_changed", [])


## Lowers [param state]'s charge rates by [param mw] in all, newest bank first, each down to
## 0 at most. Returns the MW it could not take (0 when charging covered it).
static func lower_charging(state: GameState, mw: int) -> int:
	var left: int = mw
	var banks: Array[StringName] = state.power.charge_rates.keys()
	banks.reverse()
	for room_id: StringName in banks:
		if left <= 0:
			break
		var room: RoomState = state.base.find_room(room_id)
		if room == null or not PowerRules.is_standing(room):
			continue
		var rate: int = state.power.charge_rates[room_id]
		var cut: int = mini(rate, left)
		state.power.charge_rates[room_id] = rate - cut
		left -= cut
	return left
