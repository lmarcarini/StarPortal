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
## Index of each total in totals().
const SUPPLY: int = 0
const DRAW: int = 1
const BANKS: int = 2
const RATED_BANKS: int = 3


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


## One pass over [param state]'s rooms: [supply MW, running rooms' draw MW, standing banks,
## standing banks that have a charge rate], over powered_rooms() only.
static func totals(state: GameState) -> PackedFloat64Array:
	var supply: float = 0.0
	var draw: float = 0.0
	var banks: float = 0.0
	var rated: float = 0.0
	var rates: Dictionary[StringName, int] = state.power.charge_rates
	var rooms: Array[RoomState] = powered_rooms(state)
	var defs: Array[RoomDef] = state.power.powered_defs_cache
	for index: int in rooms.size():
		var room: RoomState = rooms[index]
		if room.build_ticks_left > 0 or room.demolish_ticks_left > 0:
			continue
		var def: RoomDef = defs[index]
		if def.max_charge_rate_mw > 0.0:
			banks += 1.0
			if rates.has(room.id):
				rated += 1.0
		elif def.always_on or room.powered_on:
			supply += def.power_output_mw
			draw += def.power_draw_mw
	return PackedFloat64Array([supply, draw, banks, rated])


## The rooms of [param state]'s base whose def gives, draws or stores power, built or not.
## Cached on the PowerState and gathered again only when rooms are added or removed (or the
## defs change); their switches and build state are read live.
static func powered_rooms(state: GameState) -> Array[RoomState]:
	var base: BaseState = state.base
	var power: PowerState = state.power
	if (
		power.powered_rooms_count == base.rooms.size()
		and power.powered_rooms_next == base.next_room_number
		and power.powered_rooms_defs == state.room_defs.size()
		and power.powered_rooms_base == base.get_instance_id()
	):
		return power.powered_rooms_cache
	var found: Array[RoomState] = []
	var found_defs: Array[RoomDef] = []
	for room: RoomState in base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def == null:
			continue
		if def.power_output_mw > 0.0 or def.power_draw_mw > 0.0 or is_bank(def):
			found.append(room)
			found_defs.append(def)
	power.powered_rooms_cache = found
	power.powered_defs_cache = found_defs
	power.powered_rooms_base = base.get_instance_id()
	power.powered_rooms_count = base.rooms.size()
	power.powered_rooms_next = base.next_room_number
	power.powered_rooms_defs = state.room_defs.size()
	return found


## Supply in MW: the outputs of the running plants of [param state]'s base.
static func supply_mw(state: GameState) -> float:
	return totals(state)[SUPPLY]


## MW drawn by the running rooms (charging not included).
static func room_draw_mw(state: GameState) -> float:
	return totals(state)[DRAW]


## MW allocated to charging: the charge rates of the standing banks.
static func charge_mw(state: GameState) -> float:
	return charge_mw_of(state, totals(state))


## charge_mw() given [param state]'s [param sums] from totals(): when every rated bank stands
## it is the plain sum of the rates, without looking the rooms up.
static func charge_mw_of(state: GameState, sums: PackedFloat64Array) -> float:
	var total: float = 0.0
	var all_standing: bool = int(sums[RATED_BANKS]) == state.power.charge_rates.size()
	for room_id: StringName in state.power.charge_rates:
		if not all_standing:
			var room: RoomState = state.base.find_room(room_id)
			if room == null or not is_standing(room):
				continue
		total += state.power.charge_rates[room_id]
	return total


## MW allocated in all: running rooms' draws plus charging.
static func allocated_mw(state: GameState) -> float:
	var sums: PackedFloat64Array = totals(state)
	return sums[DRAW] + charge_mw_of(state, sums)


## Spare MW: supply less allocated, never below 0.
static func spare_mw(state: GameState) -> float:
	var sums: PackedFloat64Array = totals(state)
	return maxf(sums[SUPPLY] - sums[DRAW] - charge_mw_of(state, sums), 0.0)


## Capacitor capacity in MWh: BalanceConfig.capacitor_bank_capacity_mwh per standing bank.
static func capacity_mwh(state: GameState) -> float:
	return capacity_of(state, totals(state))


## capacity_mwh() given [param state]'s [param sums] from totals().
static func capacity_of(state: GameState, sums: PackedFloat64Array) -> float:
	if state.balance == null:
		return 0.0
	return sums[BANKS] * state.balance.capacitor_bank_capacity_mwh


## MWh per tick a charge rate of [param rate_mw] gives.
static func charge_per_tick_mwh(rate_mw: float) -> float:
	return rate_mw / TICKS_PER_HOUR


## Net MW flowing into the capacitors: charging less an open wormhole's drain.
static func net_flow_mw(state: GameState) -> float:
	return charge_mw(state) - PowerMath.drain_mw(state.gate, state.balance)
