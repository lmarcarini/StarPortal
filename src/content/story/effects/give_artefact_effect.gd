class_name GiveArtefactEffect
extends EffectDef
## An artefact arrives in Gate Room holding (or waits at the gate when holding is full).
## Bible: docs/content/m4-core-systems.md section 1

## Artefact id.
@export var artefact: StringName = &""


## Returns the artefact id.
func get_references() -> Array[StringName]:
	return [artefact]
