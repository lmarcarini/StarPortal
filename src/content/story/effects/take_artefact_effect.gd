class_name TakeArtefactEffect
extends EffectDef
## One held artefact of that id is handed over.
## Bible: docs/content/m4-core-systems.md section 1

## Artefact id.
@export var artefact: StringName = &""


## Returns the artefact id.
func get_references() -> Array[StringName]:
	return [artefact]
