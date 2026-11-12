class_name NoDialSinceCondition
extends ConditionDef
## True when no dial has started since the tick stored in the flag (used by "keep the Ring
## closed" requests).
## Bible: docs/content/m4-core-systems.md section 1

## Flag holding the start tick.
@export var flag: StringName = &""


## Returns &"COND_NO_DIAL_SINCE".
func reason_key() -> StringName:
	return &"COND_NO_DIAL_SINCE"
