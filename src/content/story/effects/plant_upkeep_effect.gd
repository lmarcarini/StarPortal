class_name PlantUpkeepEffect
extends EffectDef
## Research unlock: every diesel Power Plant's upkeep per 30 days becomes this, in $k.
## Applied through UnlockRules.
## Bible: docs/content/m4-core-systems.md section 7 (1), docs/content/m25-lean-start.md section 3

## UnlockRules effect id.
const UNLOCK: StringName = &"plant_upkeep"

## Every diesel Power Plant's upkeep per 30 days becomes this, in $k.
@export var amount_k: int = 0


## [UnlockRules effect id, value].
func unlock_pair() -> Array:
	return [UNLOCK, amount_k]
