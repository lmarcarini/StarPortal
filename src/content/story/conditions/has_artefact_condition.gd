class_name HasArtefactCondition
extends ConditionDef
## True when the player holds at least one of that artefact, in any place.
## Bible: docs/content/m4-core-systems.md section 1

## Artefact id.
@export var artefact: StringName = &""


## Returns &"COND_HAS_ARTEFACT".
func reason_key() -> StringName:
	return &"COND_HAS_ARTEFACT"


## Returns the artefact id.
func get_references() -> Array[StringName]:
	return [artefact]
