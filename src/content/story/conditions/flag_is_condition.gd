class_name FlagIsCondition
extends ConditionDef
## True when GameState.flags[flag] equals value (a missing flag is false).
## Bible: docs/content/m4-core-systems.md section 1

## Flag name.
@export var flag: StringName = &""
## Expected value: bool, int or String.
@export var value: Variant = true


## Returns &"COND_FLAG_IS".
func reason_key() -> StringName:
	return &"COND_FLAG_IS"
