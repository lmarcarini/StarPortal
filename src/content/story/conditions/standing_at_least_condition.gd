class_name StandingAtLeastCondition
extends ConditionDef
## True when the faction's standing is at least amount (the Committee's is Confidence).
## Bible: docs/content/m4-core-systems.md section 1

## Faction id.
@export var faction: StringName = &""
## Minimum standing.
@export var amount: int = 0


## Returns &"COND_STANDING_AT_LEAST".
func reason_key() -> StringName:
	return &"COND_STANDING_AT_LEAST"


## Returns the faction id.
func get_references() -> Array[StringName]:
	return [faction]
