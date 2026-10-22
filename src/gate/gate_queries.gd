class_name GateQueries
extends RefCounted
## Read-only answers about the Ring for commands and views: the charge a dial needs, how long
## until it is ready, earlier attempts at an address and the open wormhole's time left. Pure
## static over a GameState whose transient balance and galaxy are set (GameSetup sets them).
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#player-tools, game-design.md#time-real-time-with-pause


## Returns the energy in MWh the capacitors must hold to dial the well-formed
## [param address] from the home Ring.
static func lock_energy_mwh(state: GameState, address: GateAddress) -> float:
	assert(state.galaxy != null and state.balance != null, "GateQueries: no galaxy or balance")
	if state.galaxy == null or state.balance == null:
		return 0.0
	var home_ly: Vector3i = state.galaxy.home().position_ly
	return EnergyMath.lock_energy_mwh(address, home_ly, state.galaxy.anchors_ly(), state.balance)


## Returns the ticks until the bank holds the lock energy of [param address] at the current
## plant output less any open drain: 0 when it already does, -1 when it never will (the
## energy is above the bank's capacity, or the net flow is not positive).
static func ticks_until_ready(state: GameState, address: GateAddress) -> int:
	var needed: float = lock_energy_mwh(state, address)
	var power: PowerState = state.power
	if power.stored_mwh >= needed:
		return 0
	if needed > power.capacity_mwh:
		return -1
	var drain: float = PowerMath.drain_mw(state.gate, state.balance)
	var net: float = PowerMath.net_flow_mw(power.plant_output_mw, drain)
	return PowerMath.ticks_until_mwh(power.stored_mwh, needed, net)


## Returns the Dial Log entries whose address equals [param address] seal for seal, oldest
## first.
static func previous_attempts(state: GameState, address: GateAddress) -> Array[DialLogEntry]:
	var found: Array[DialLogEntry] = []
	for entry: DialLogEntry in state.gate.dial_log:
		if entry.address != null and entry.address.equals(address):
			found.append(entry)
	return found


## Returns the ticks the open wormhole has left before it closes itself, counted from the
## clock's tick; 0 unless the Ring is LOCKED.
static func open_ticks_left(state: GameState) -> int:
	var gate: GateState = state.gate
	if gate.mode != GateState.RingMode.LOCKED or state.balance == null:
		return 0
	var open_for: int = state.clock.tick - gate.lock_started_tick
	return maxi(state.balance.max_open_ticks - open_for, 0)
