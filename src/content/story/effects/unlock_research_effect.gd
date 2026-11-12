class_name UnlockResearchEffect
extends EffectDef
## Reveals a hidden research project.
## Bible: docs/content/m4-core-systems.md section 1

## Research project id.
@export var project: StringName = &""


## Returns the project id.
func get_references() -> Array[StringName]:
	return [project]
