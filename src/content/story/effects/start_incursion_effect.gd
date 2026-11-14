class_name StartIncursionEffect
extends EffectDef
## Starts an incursion (M4c), e.g. as a refused demand's penalty. Does nothing while one is
## already under way.
## Bible: docs/content/m4c-incursions.md section 1

## The IncursionDef to start.
@export var incursion: StringName = &""


## The incursion.
func get_references() -> Array[StringName]:
	return [incursion]
