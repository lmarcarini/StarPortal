class_name PowerUsageAtLeastCondition
extends ConditionDef
## True when the base draws at least [member percent]% of its supply.
## Bible: docs/content/research-and-progression.md section 10 (E08)

## The least share of the supply drawn, in percent.
@export var percent: int = 80


## Returns &"COND_POWER_USAGE".
func reason_key() -> StringName:
	return &"COND_POWER_USAGE"
