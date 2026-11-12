class_name AddDocumentEffect
extends EffectDef
## Delivers a document.
## Bible: docs/content/m4-core-systems.md section 1

## Document id.
@export var document: StringName = &""


## Returns the document id.
func get_references() -> Array[StringName]:
	return [document]
