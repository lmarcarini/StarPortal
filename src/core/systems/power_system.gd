class_name PowerSystem
extends SimSystem
## The M1 placeholder power system. Each tick it first advances a running capacitor bank
## install: when the install's last tick runs, the bank's capacity is added, and it posts
## capacitors_installed(new capacity) and pause_requested(&"capacitors_installed"). Then the
## starting plant's whole output charges the capacitors, and an open wormhole's drain comes
## out of that output first and storage second. Views read power on tick_advanced. M2
## replaces this with rooms.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#the-dial-console, game-design.md#base-building-and-power

## Reason of the pause request a finished install posts.
const PAUSE_REASON: StringName = &"capacitors_installed"

var _balance: BalanceConfig


func _init(balance: BalanceConfig) -> void:
	_balance = balance


## Returns the system id, &"power".
func get_id() -> StringName:
	return &"power"


## Advances a running install, then charges or drains the capacitors by one tick of the plant
## output minus the open drain.
func tick(state: GameState) -> void:
	var power: PowerState = state.power
	_advance_install(state)
	var drain: float = PowerMath.drain_mw(state.gate, _balance)
	var net: float = PowerMath.net_flow_mw(power.plant_output_mw, drain)
	power.stored_mwh = PowerMath.step_stored_mwh(power.stored_mwh, power.capacity_mwh, net)


## One tick of the install job; on its last tick the bank is installed.
func _advance_install(state: GameState) -> void:
	var power: PowerState = state.power
	if power.install_ticks_left <= 0:
		return
	power.install_ticks_left -= 1
	if power.install_ticks_left > 0:
		return
	power.banks_installed += 1
	power.capacity_mwh += _balance.capacitor_bank_capacity_mwh
	state.events.post(&"capacitors_installed", [power.capacity_mwh])
	state.events.post(Simulation.PAUSE_EVENT, [PAUSE_REASON])
