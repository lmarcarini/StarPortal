class_name ChangeStandingEffect
extends EffectDef
## Moves standing; for the Committee it moves Confidence.
## Bible: docs/content/m4-core-systems.md section 1

## Faction id.
@export var faction: StringName = &""
## Change in standing.
@export var delta: int = 0


## Returns the faction id.
func get_references() -> Array[StringName]:
	return [faction]
