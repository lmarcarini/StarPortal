class_name IdOrder
extends RefCounted
## Sorting ids by their text. Array.sort() orders StringNames by their interned pointer, not
## alphabetically, so it can change with what was loaded first (and between a save and a
## load); every "in id order" rule in the simulation sorts with this instead.
## Bible: technical-architecture.md#simulation-clock-and-commands


## Sorts [param ids] (StringNames or Strings) alphabetically, in place.
static func sort(ids: Array) -> void:
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
