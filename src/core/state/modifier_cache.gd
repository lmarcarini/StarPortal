class_name ModifierCache
extends RefCounted
## The summed modifiers by key and the signature of the sources they were summed from. Not
## saved: ModifierRules rebuilds it whenever the signature changes (research done, an artefact
## moved, a room built, switched or demolished, a load), never every tick.
## Bible: docs/content/m4-core-systems.md section 6

## Total per key (clamped where the key is a percent).
var totals: Dictionary[StringName, int] = {}
## The source signature the totals belong to; empty before the first sum.
var signature: Array = []
## How many times the totals were summed (for tests and the soak budget).
var rebuilds: int = 0
