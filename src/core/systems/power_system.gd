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


## Runs one tick of power: banks, allocation, then charge.
func tick(state: GameState) -> void:
	_forget_lost_banks(state)
	_adopt_new_banks(state)
	if PowerRules.allocated_mw(state) > PowerRules.supply_mw(state):
		_shed(state)
		state.events.post(&"power_allocation_changed", [])
	var capacity: float = PowerRules.capacity_mwh(state)
	var net: float = PowerRules.net_flow_mw(state)
	state.power.stored_mwh = PowerMath.step_stored_mwh(state.power.stored_mwh, capacity, net)


## Drops the charge rate of every bank that no longer stands.
func _forget_lost_banks(state: GameState) -> void:
	for room_id: StringName in state.power.charge_rates.keys():
		var room: RoomState = state.base.find_room(room_id)
		if room == null or not PowerRules.is_standing(room):
			state.power.charge_rates.erase(room_id)


## Gives each standing bank without a charge rate the spare supply, up to its maximum.
func _adopt_new_banks(state: GameState) -> void:
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


## Switches the newest switchable consumer rooms off, then lowers charge rates (newest bank
## first), until allocation fits supply.
func _shed(state: GameState) -> void:
	var rooms: Array[RoomState] = state.base.rooms.duplicate()
	rooms.reverse()
	for room: RoomState in rooms:
		if PowerRules.allocated_mw(state) <= PowerRules.supply_mw(state):
			return
		var def: RoomDef = state.room_defs.get(room.def_id)
		if PowerRules.has_switch(def) and def.power_output_mw <= 0.0:
			if PowerRules.is_running(room, def):
				room.powered_on = false
	var banks: Array[StringName] = state.power.charge_rates.keys()
	banks.reverse()
	for room_id: StringName in banks:
		var over: float = PowerRules.allocated_mw(state) - PowerRules.supply_mw(state)
		if over <= 0.0:
			return
		var rate: int = state.power.charge_rates[room_id]
		state.power.charge_rates[room_id] = maxi(rate - ceili(over), 0)
