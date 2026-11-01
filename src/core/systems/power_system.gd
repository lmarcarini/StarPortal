class_name PowerSystem
extends SimSystem
## Runs the base's power each tick (docs/content/m2-base.md section 3), in this order:
## [br]1. Forgets the charge rate of a bank that is gone or being demolished.
## [br]2. Gives a newly completed Capacitor Bank the spare supply as its charge rate (up to its
## maximum), and posts capacitors_installed(capacity) and pause_requested(&"capacitors_installed").
## [br]3. Keeps allocation within supply: if a room just completed or a plant went away, it
## switches the newest switchable rooms off, then lowers charge rates, until it fits, and posts
## power_allocation_changed().
## [br]4. Charges the capacitors at the banks' rates less an open wormhole's drain, clamped to
## 0..capacity. The Ring never draws on the supply and the rooms never draw on the capacitors.
## Bible: docs/content/m2-base.md section 3, gate-and-address-spec.md#dialing-outcomes-and-energy

## Reason of the pause request a completed bank posts.
const PAUSE_REASON: StringName = &"capacitors_installed"

var _balance: BalanceConfig


func _init(balance: BalanceConfig) -> void:
	_balance = balance


## Returns the system id, &"power".
func get_id() -> StringName:
	return &"power"


## Runs one tick of power: banks, allocation, then charge. One pass over the rooms when
## nothing changed.
func tick(state: GameState) -> void:
	var sums: PackedFloat64Array = PowerRules.totals(state)
	if _needs_settling(state, sums):
		settle(state)
		sums = PowerRules.totals(state)
	var capacity: float = PowerRules.capacity_of(state, sums)
	var charge: float = PowerRules.charge_mw_of(state, sums)
	var net: float = charge - PowerMath.drain_mw(state.gate, state.balance)
	state.power.stored_mwh = PowerMath.step_stored_mwh(state.power.stored_mwh, capacity, net)


## Brings [param state]'s power back in line after rooms change: forgets gone banks, gives
## completed banks their rate, and sheds allocation above supply. Posts
## power_allocation_changed() only when something changed. Called by this system each tick
## when needed, and by ConstructionSystem and DemolishRoomCommand the moment rooms finish or
## start coming down, so allocation never exceeds supply between ticks.
static func settle(state: GameState) -> void:
	_forget_lost_banks(state)
	_adopt_new_banks(state)
	if _shed(state):
		state.events.post(&"power_allocation_changed", [])


## True when a bank was added or lost, or allocation is above supply.
static func _needs_settling(state: GameState, sums: PackedFloat64Array) -> bool:
	var rated: int = int(sums[PowerRules.RATED_BANKS])
	if rated != state.power.charge_rates.size() or rated != int(sums[PowerRules.BANKS]):
		return true
	var allocated: float = sums[PowerRules.DRAW] + PowerRules.charge_mw_of(state, sums)
	return allocated > sums[PowerRules.SUPPLY]


## Drops the charge rate of every bank that no longer stands.
static func _forget_lost_banks(state: GameState) -> void:
	for room_id: StringName in state.power.charge_rates.keys():
		var room: RoomState = state.base.find_room(room_id)
		if room == null or not PowerRules.is_standing(room):
			state.power.charge_rates.erase(room_id)


## Gives each standing bank without a charge rate the spare supply, up to its maximum.
static func _adopt_new_banks(state: GameState) -> void:
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if not PowerRules.is_bank(def) or not PowerRules.is_standing(room):
			continue
		if state.power.charge_rates.has(room.id):
			continue
		var spare: float = PowerRules.spare_mw(state)
		state.power.charge_rates[room.id] = floori(minf(spare, def.max_charge_rate_mw))
		state.events.post(&"capacitors_installed", [PowerRules.capacity_mwh(state)])
		state.events.post(Simulation.PAUSE_EVENT, [PAUSE_REASON])
		state.events.post(&"power_allocation_changed", [])


## Fits allocation to supply: first switches stopped plants back on while supply is below the
## always-on load, then switches the newest switchable rooms off, then lowers charge rates
## (newest bank first). Returns true when it changed anything.
static func _shed(state: GameState) -> bool:
	if PowerRules.allocated_mw(state) <= PowerRules.supply_mw(state):
		return false
	var changed: bool = _restart_plants(state)
	var rooms: Array[RoomState] = state.base.rooms.duplicate()
	rooms.reverse()
	for room: RoomState in rooms:
		if PowerRules.allocated_mw(state) <= PowerRules.supply_mw(state):
			return true
		var def: RoomDef = state.room_defs.get(room.def_id)
		if PowerRules.has_switch(def) and def.power_output_mw <= 0.0:
			if PowerRules.is_running(room, def):
				room.powered_on = false
				changed = true
	var banks: Array[StringName] = state.power.charge_rates.keys()
	banks.reverse()
	for room_id: StringName in banks:
		var over: float = PowerRules.allocated_mw(state) - PowerRules.supply_mw(state)
		var rate: int = state.power.charge_rates[room_id]
		if over <= 0.0 or rate == 0:
			continue
		state.power.charge_rates[room_id] = maxi(rate - ceili(over), 0)
		changed = true
	return changed


## Switches stopped, standing plants back on, oldest first, while supply is below the
## always-on rooms' draw. Returns true when it switched any.
static func _restart_plants(state: GameState) -> bool:
	var changed: bool = false
	for room: RoomState in state.base.rooms:
		if PowerRules.supply_mw(state) >= _always_on_mw(state):
			return changed
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def == null or def.power_output_mw <= 0.0 or room.powered_on:
			continue
		if PowerRules.is_standing(room):
			room.powered_on = true
			changed = true
	return changed


## MW drawn by the standing always-on rooms.
static func _always_on_mw(state: GameState) -> float:
	var total: float = 0.0
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def != null and def.always_on and PowerRules.is_standing(room):
			total += def.power_draw_mw
	return total
