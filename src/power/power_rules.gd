class_name PowerRules
extends RefCounted
## Pure power rules over the base (docs/content/m2-base.md section 3): the plants' supply, the
## MW allocated to running rooms and to charging, the spare, the capacitors' capacity and the
## charge they gain per tick. Power works like FTL: a fixed supply shared out between rooms,
## never over-allocated. A room counts when it is built and not being demolished; an always-on
## room counts whatever its switch says. Digging and building sites draw nothing.
## Bible: game-design.md#base-building-and-power, docs/content/m2-base.md section 3

## Ticks in one in-game hour; a rate in MW moves rate / 60 MWh per tick.
const TICKS_PER_HOUR: float = 60.0


## True when [param room] is built and not being demolished.
static func is_standing(room: RoomState) -> bool:
	return room.is_built() and not room.is_demolishing()


## True when [param room] of [param def] is standing and running: always on, or switched on.
static func is_running(room: RoomState, def: RoomDef) -> bool:
	if def == null or not is_standing(room):
		return false
	return def.always_on or room.powered_on


## True when [param def] is a Capacitor Bank: a room with a charge rate.
static func is_bank(def: RoomDef) -> bool:
	return def != null and def.max_charge_rate_mw > 0.0


## True when [param def] has an on/off switch: not always on, not a bank, and it draws or
## gives power (lifts, stairs and corridors have none).
static func has_switch(def: RoomDef) -> bool:
	if def == null or def.always_on or is_bank(def):
		return false
	return def.power_draw_mw > 0.0 or def.power_output_mw > 0.0


## Supply in MW: the outputs of the running plants of [param state]'s base.
static func supply_mw(state: GameState) -> float:
	var total: float = 0.0
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if is_running(room, def):
			total += def.power_output_mw
	return total


## MW drawn by the running rooms (charging not included).
static func room_draw_mw(state: GameState) -> float:
	var total: float = 0.0
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if is_running(room, def):
			total += def.power_draw_mw
	return total


## MW allocated to charging: the charge rates of the standing banks.
static func charge_mw(state: GameState) -> float:
	var total: float = 0.0
	for room_id: StringName in state.power.charge_rates:
		var room: RoomState = state.base.find_room(room_id)
		if room != null and is_standing(room):
			total += state.power.charge_rates[room_id]
	return total


## MW allocated in all: running rooms' draws plus charging.
static func allocated_mw(state: GameState) -> float:
	return room_draw_mw(state) + charge_mw(state)


## Spare MW: supply less allocated, never below 0.
static func spare_mw(state: GameState) -> float:
	return maxf(supply_mw(state) - allocated_mw(state), 0.0)


## Capacitor capacity in MWh: BalanceConfig.capacitor_bank_capacity_mwh per standing bank.
static func capacity_mwh(state: GameState) -> float:
	if state.balance == null:
		return 0.0
	var banks: int = 0
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if is_standing(room) and is_bank(def):
			banks += 1
	return banks * state.balance.capacitor_bank_capacity_mwh


## MWh per tick a charge rate of [param rate_mw] gives.
static func charge_per_tick_mwh(rate_mw: float) -> float:
	return rate_mw / TICKS_PER_HOUR


## Net MW flowing into the capacitors: charging less an open wormhole's drain.
static func net_flow_mw(state: GameState) -> float:
	return charge_mw(state) - PowerMath.drain_mw(state.gate, state.balance)
