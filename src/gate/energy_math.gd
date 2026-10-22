class_name EnergyMath
extends RefCounted
## Lock energy and dial costs. Pure static functions; no autoloads, no randomness.
##
## E_lock = E_base * (1 + d / d_ref) * M_seals. The player must know the charge before dialing
## a guess, so d comes from the address, not the world: the distance from the home Ring to the
## anchor of seal 1 (the destination's nearest anchor), which exists for any address.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy


## Returns the energy in MWh the capacitors must hold before dialing [param address] from the
## home Ring at [param home_ly]. [param anchors_ly] is indexed by glyph. Every address is 8
## seals for now, so M_seals is [member BalanceConfig.seal_multiplier_8]. Returns 0.0 (and
## asserts) when the address has no seal 1 inside [param anchors_ly], or balance is null.
static func lock_energy_mwh(
	address: GateAddress, home_ly: Vector3i, anchors_ly: Array[Vector3i], balance: BalanceConfig
) -> float:
	var is_valid: bool = (
		address != null
		and balance != null
		and not address.coordinates.is_empty()
		and address.coordinates[0] >= 0
		and address.coordinates[0] < anchors_ly.size()
	)
	assert(is_valid, "EnergyMath.lock_energy_mwh(): no seal 1 anchor, or no balance")
	if not is_valid:
		return 0.0
	var distance: float = AddressRule.distance_ly(home_ly, anchors_ly[address.coordinates[0]])
	var distance_factor: float = 1.0 + distance / balance.lock_reference_distance_ly
	return balance.lock_energy_base_mwh * distance_factor * balance.seal_multiplier_8


## Returns the energy in MWh a dial spends for [param outcome] when its lock energy is
## [param lock_energy_mwh]: the outcome's cost fraction from [param balance] for No gate,
## Blocked and Origin rejected; all of it for a lock (the open drain comes on top).
static func dial_cost_mwh(
	lock_energy_mwh: float, outcome: DialOutcome.Kind, balance: BalanceConfig
) -> float:
	assert(balance != null, "EnergyMath.dial_cost_mwh(): no balance")
	if balance == null:
		return 0.0
	return lock_energy_mwh * _cost_fraction(outcome, balance)


## Fraction of the lock energy spent for [param outcome].
static func _cost_fraction(outcome: DialOutcome.Kind, balance: BalanceConfig) -> float:
	match outcome:
		DialOutcome.Kind.NO_GATE:
			return balance.cost_fraction_no_gate
		DialOutcome.Kind.BLOCKED:
			return balance.cost_fraction_blocked
		DialOutcome.Kind.ORIGIN_REJECTED:
			return balance.cost_fraction_origin_rejected
	return 1.0
