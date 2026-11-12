class_name StandingBelowCondition
extends ConditionDef
## True when the faction's standing is below amount.
## Bible: docs/content/m4-core-systems.md section 1

## Faction id.
@export var faction: StringName = &""
## Standing must be below this.
@export var amount: int = 0


## Returns &"COND_STANDING_BELOW".
func reason_key() -> StringName:
	return &"COND_STANDING_BELOW"


## Returns the faction id.
func get_references() -> Array[StringName]:
	return [faction]
