class_name DigDepthEffect
extends EffectDef
## Research unlock: levels down to this may be dug (never lowers it). Applied through UnlockRules.
## Bible: docs/content/m4-core-systems.md section 7 (1), docs/content/m25-lean-start.md section 3

## UnlockRules effect id.
const UNLOCK: StringName = &"dig_depth"

## Levels down to this may be dug (never lowers it).
@export var levels: int = 0


## [UnlockRules effect id, value].
func unlock_pair() -> Array:
	return [UNLOCK, levels]
