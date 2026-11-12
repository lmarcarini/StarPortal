class_name OfferRequestEffect
extends EffectDef
## Creates a request offer.
## Bible: docs/content/m4-core-systems.md section 1

## Request id.
@export var request: StringName = &""


## Returns the request id.
func get_references() -> Array[StringName]:
	return [request]
