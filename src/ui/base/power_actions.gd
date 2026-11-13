class_name PowerActions
extends RefCounted
## The Base tab's power actions: each builds a SwitchRoomCommand or SetChargeRateCommand and
## submits it, and returns "" when it was accepted or the refusal in plain words. Changes no
## state itself.
## Bible: docs/content/m2-base.md sections 3 and 6, docs/content/m26-staff-and-money.md section 3


## Switches room [param room_id] of [param simulation] to the other state.
static func toggle(simulation: Simulation, room_id: StringName) -> String:
	var state: GameState = simulation.state
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if def == null:
		return ""
	var on: bool = not room.powered_on
	var spare: float = PowerRules.supply_mw(state) - PowerRules.allocated_mw(state)
	var delta: float = def.power_draw_mw - def.power_output_mw
	var result: CommandResult = simulation.submit(SwitchRoomCommand.create(room_id, on))
	if result.is_ok:
		return ""
	var plant_off: bool = not on and def.power_output_mw > 0.0
	if plant_off:
		spare += PowerRules.charge_mw(state)
	return PowerText.refusal(result.error_code, delta if on else -delta, spare, plant_off)


## Sets bank [param room_id]'s charge rate to [param rate_mw], clamped to 0..its maximum.
static func set_rate(simulation: Simulation, room_id: StringName, rate_mw: int) -> String:
	var state: GameState = simulation.state
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if not PowerRules.is_bank(def):
		return ""
	var target: int = clampi(rate_mw, 0, PowerRules.max_charge_mw(state, def))
	var current: int = state.power.charge_rates.get(room_id, 0)
	if target == current:
		return ""
	var spare: float = PowerRules.supply_mw(state) - PowerRules.allocated_mw(state)
	var result: CommandResult = simulation.submit(SetChargeRateCommand.create(room_id, target))
	if result.is_ok:
		return ""
	return PowerText.refusal(result.error_code, target - current, spare, false)
