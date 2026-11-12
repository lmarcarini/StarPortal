class_name StudyArtefactEffect
extends EffectDef
## Marks the held artefact Studied (the end effect of a study project).
## Bible: docs/content/m4-core-systems.md section 1

## Artefact id.
@export var artefact: StringName = &""


## Returns the artefact id.
func get_references() -> Array[StringName]:
	return [artefact]
