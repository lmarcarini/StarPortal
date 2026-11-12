class_name AddAddressEffect
extends EffectDef
## Files a world's address.
## Bible: docs/content/m4-core-systems.md section 1

## World id.
@export var world: StringName = &""


## Returns the world id.
func get_references() -> Array[StringName]:
	return [world]
