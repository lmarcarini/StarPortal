class_name RandomState
extends RefCounted
## Saved state of the simulation's randomness. Stub: M0-08 adds per-system streams.
## Bible: technical-architecture.md#simulation-clock-and-commands

## Seed every system stream derives from. Named to avoid shadowing the global seed().
var base_seed: int = 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {"base_seed": base_seed}


## Builds a RandomState from saved [param data]. JSON floats are cast back to ints.
static func from_dict(data: Dictionary) -> RandomState:
	var random := RandomState.new()
	var base_seed_data: Variant = data.get("base_seed", random.base_seed)
	random.base_seed = type_convert(base_seed_data, TYPE_INT)
	return random
