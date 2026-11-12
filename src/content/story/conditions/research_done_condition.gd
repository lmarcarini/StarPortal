class_name ResearchDoneCondition
extends ConditionDef
## True when the research project is finished.
## Bible: docs/content/m4-core-systems.md section 1

## Research project id.
@export var project: StringName = &""


## Returns &"COND_RESEARCH_DONE".
func reason_key() -> StringName:
	return &"COND_RESEARCH_DONE"


## Returns the project id.
func get_references() -> Array[StringName]:
	return [project]
