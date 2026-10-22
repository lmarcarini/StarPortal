class_name PowerSystem
extends SimSystem
## The M1 placeholder power system: each tick the starting plant's whole output charges the
## capacitor bank, and an open wormhole's drain comes out of that output first and storage
## second. Posts no events; views read power on tick_advanced. M2 replaces this with rooms.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#base-building-and-power

var _balance: BalanceConfig


func _init(balance: BalanceConfig) -> void:
	_balance = balance


## Returns the system id, &"power".
func get_id() -> StringName:
	return &"power"


## Charges or drains the bank by one tick of the plant output minus the open drain.
func tick(state: GameState) -> void:
	var power: PowerState = state.power
	var drain: float = PowerMath.drain_mw(state.gate, _balance)
	var net: float = PowerMath.net_flow_mw(power.plant_output_mw, drain)
	power.stored_mwh = PowerMath.step_stored_mwh(power.stored_mwh, power.capacity_mwh, net)
