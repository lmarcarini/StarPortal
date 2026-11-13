class_name BankCapEffect
extends EffectDef
## Research unlock: up to this many Capacitor Banks (never lowers it). Applied through
## UnlockRules.
## Bible: docs/content/m4-core-systems.md section 7 (1), docs/content/m25-lean-start.md section 3

## UnlockRules effect id.
const UNLOCK: StringName = &"bank_cap"

## Up to this many Capacitor Banks (never lowers it).
@export var count: int = 0


## [UnlockRules effect id, value].
func unlock_pair() -> Array:
	return [UNLOCK, count]
