class_name ContentCheckBalance
extends RefCounted
## Content check: the tunables of the BalanceConfig the address and energy math depend on. Pure;
## returns one line per problem.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#the-dial-console

## Tunables that must be finite and greater than zero.
const POSITIVE: Array[StringName] = [
	&"lock_energy_base_mwh",
	&"lock_reference_distance_ly",
	&"seal_multiplier_8",
	&"seal_multiplier_9",
	&"seal_multiplier_10",
	&"open_drain_mw_8",
	&"open_drain_mw_9",
	&"starting_plant_output_mw",
	&"capacitor_bank_capacity_mwh",
	&"capacitor_bank_install_ticks",
	&"max_capacitor_banks",
	&"dial_duration_ticks",
	&"max_open_ticks",
	&"starting_levels",
	&"lift_segment_cost_k",
	&"lift_segment_ticks",
]
## Tunables that must be finite and at least zero.
const NON_NEGATIVE: Array[StringName] = [&"starting_capacity_mwh"]
## Tunables that are shares of the lock energy: 0..1.
const FRACTIONS: Array[StringName] = [
	&"cost_fraction_no_gate", &"cost_fraction_blocked", &"cost_fraction_origin_rejected"
]


## Returns the problems of [param balance]: a missing config, a tunable of POSITIVE that is not
## above zero (or not a finite number), a tunable of NON_NEGATIVE below zero (or not a finite
## number), a tunable of FRACTIONS outside 0..1.
static func check(balance: BalanceConfig) -> Array[String]:
	var errors: Array[String] = []
	if balance == null:
		errors.append("balance: no BalanceConfig with id 'balance'")
		return errors
	for tunable: StringName in POSITIVE:
		var value: float = type_convert(balance.get(tunable), TYPE_FLOAT)
		if not is_finite(value) or value <= 0.0:
			errors.append("balance: %s is %s, expected above 0" % [tunable, value])
	for tunable: StringName in NON_NEGATIVE:
		var value: float = type_convert(balance.get(tunable), TYPE_FLOAT)
		if not is_finite(value) or value < 0.0:
			errors.append("balance: %s is %s, expected at least 0" % [tunable, value])
	for tunable: StringName in FRACTIONS:
		var value: float = type_convert(balance.get(tunable), TYPE_FLOAT)
		if not (value >= 0.0 and value <= 1.0):
			errors.append("balance: %s is %s, expected 0..1" % [tunable, value])
	return errors
