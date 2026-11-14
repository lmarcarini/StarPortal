class_name TopBarText
extends RefCounted
## Text and states of the top bar's readouts, read from the simulation state with no side
## effects: today's net change of the funds (the Command ledger's rules), power and stored
## energy, and the gate chip.
## Bible: docs/content/interface-pass.md section 3

## Gate chip states.
const GATE_IDLE: StringName = &"idle"
const GATE_DIALLING: StringName = &"dialling"
const GATE_OPEN: StringName = &"open"
const GATE_INCOMING: StringName = &"incoming"
## The Shutter is closed (M4c-10).
const GATE_SHUTTER: StringName = &"shutter"


## Today's net change of the funds in $k per day: the Command ledger's net line, rounded.
static func net_per_day(state: GameState) -> int:
	var lines: Array[CommandLine] = CommandLedger.lines(state)
	if lines.is_empty():
		return 0
	var net: CommandLine = lines.back()
	return roundi(net.per_day_tenths / 10.0)


## "+38/d", "-12/d" or "±0/d" for [param net_k] $k a day.
static func net_text(net_k: int) -> String:
	var sign: String = "+" if net_k > 0 else ("-" if net_k < 0 else "±")
	return _tr(&"TOPBAR_NET_PER_DAY").format({"net": "%s%d" % [sign, absi(net_k)]})


## "PWR 25/30 MW", switched-on draw over supply.
static func power_text(state: GameState) -> String:
	var values: Dictionary = {
		"used": roundi(PowerRules.allocated_mw(state)),
		"supply": roundi(PowerRules.supply_mw(state)),
	}
	return _tr(&"TOPBAR_POWER").format(values)


## "CAP 310 MWh", the energy stored; "" when the base has no capacitors.
static func stored_text(state: GameState) -> String:
	if PowerRules.capacity_mwh(state) <= 0.0:
		return ""
	return _tr(&"TOPBAR_STORED").format({"stored": floori(state.power.stored_mwh)})


## The gate chip state of [param state]: open (LOCKED), dialling, incoming (a wormhole waits
## to be answered) or idle.
static func gate_status(state: GameState) -> StringName:
	var gate: GateState = state.gate
	if gate.mode == GateState.RingMode.LOCKED:
		return GATE_OPEN
	if gate.mode == GateState.RingMode.DIALING:
		return GATE_DIALLING
	if gate.incoming_faction != &"":
		return GATE_INCOMING
	if gate.shutter == GateState.Shutter.CLOSED:
		return GATE_SHUTTER
	return GATE_IDLE


## The gate chip text: "GATE: IDLE", "GATE: DIALLING", "GATE: INCOMING", "GATE: SHUTTER" or
## "GATE: OPEN Abydos 38 min".
static func gate_text(state: GameState) -> String:
	var status: StringName = gate_status(state)
	if status != GATE_OPEN:
		return _tr(StringName("TOPBAR_GATE_" + String(status).to_upper()))
	var world: String = AddressBookText.name_of_world(state.gate.connected_world_id, state)
	return _tr(&"TOPBAR_GATE_OPEN").format(
		{"world": world, "left": time_left(GateQueries.open_ticks_left(state))}
	)


## "1 h 05 min" or "38 min" for [param ticks] in-game minutes.
static func time_left(ticks: int) -> String:
	var minutes: int = maxi(ticks, 0)
	if minutes < 60:
		return _tr(&"TOPBAR_MINUTES").format({"m": minutes})
	return _tr(&"TOPBAR_HOURS_MINUTES").format({"h": minutes / 60, "m": "%02d" % (minutes % 60)})


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
