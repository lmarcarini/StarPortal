class_name FactionMetCondition
extends ConditionDef
## True when the faction has been met.
## Bible: docs/content/m4-core-systems.md section 1

## Faction id.
@export var faction: StringName = &""


## Returns &"COND_FACTION_MET".
func reason_key() -> StringName:
	return &"COND_FACTION_MET"


## Returns the faction id.
func get_references() -> Array[StringName]:
	return [faction]
