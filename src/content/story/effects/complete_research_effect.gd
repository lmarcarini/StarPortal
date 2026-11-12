class_name CompleteResearchEffect
extends EffectDef
## Marks a research project done for free.
## Bible: docs/content/m4-core-systems.md section 1

## Research project id.
@export var project: StringName = &""


## Returns the project id.
func get_references() -> Array[StringName]:
	return [project]
