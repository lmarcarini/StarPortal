class_name ModifierEffect
extends EffectDef
## A lasting modifier: a key and an amount. Valid only on research and artefact definitions.
## Bible: docs/content/m4-core-systems.md sections 1 and 6

## The modifier keys of M4 (design section 6).
const KEYS: Array[StringName] = [
	&"research_speed_pct",
	&"build_speed_pct",
	&"allocation_k",
	&"upkeep_pct",
	&"plant_output_mw",
	&"charge_rate_pct",
	&"dial_cost_pct",
	&"wormhole_minutes",
	&"field_check_bonus",
	&"moth_battery_pct",
	&"wormhole_open_pct",
	&"bank_capacity_pct",
]

## One of KEYS.
@export var key: StringName = &""
## Amount in the key's unit (percent, $k, MW, minutes or points).
@export var amount: int = 0


## Returns true when [param modifier_key] is one of KEYS.
static func is_known_key(modifier_key: StringName) -> bool:
	return KEYS.has(modifier_key)
