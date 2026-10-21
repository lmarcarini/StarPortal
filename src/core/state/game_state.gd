class_name GameState
extends RefCounted
## Root of all runtime state; the only thing saved. Sub-states are plain RefCounted
## classes that convert to and from JSON-safe dictionaries.
## Bible: technical-architecture.md#data-model

## The simulation clock.
var clock: ClockState = ClockState.new()
## Seeds and stream states for every random generator.
var random: RandomState = RandomState.new()
## Story and progress flags: StringName -> bool | int | String.
var flags: Dictionary = {}


## Returns a fresh campaign state seeded with [param base_seed].
static func new_game(base_seed: int) -> GameState:
	var state := GameState.new()
	state.random.base_seed = base_seed
	return state


## Returns JSON-safe data for saving. Flag keys become Strings.
func to_dict() -> Dictionary:
	var flag_data: Dictionary = {}
	for key: Variant in flags:
		flag_data[str(key)] = flags[key]
	return {"clock": clock.to_dict(), "random": random.to_dict(), "flags": flag_data}


## Builds a GameState from saved [param data], e.g. after a JSON round trip. Flag keys
## become StringNames again, float flag values become ints, and unsupported values are
## dropped.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.clock = ClockState.from_dict(_dict_or_empty(data.get("clock")))
	state.random = RandomState.from_dict(_dict_or_empty(data.get("random")))
	var flag_data: Dictionary = _dict_or_empty(data.get("flags"))
	for key: Variant in flag_data:
		var flag_value: Variant = flag_data[key]
		if flag_value is float:
			flag_value = type_convert(flag_value, TYPE_INT)
		if not (flag_value is bool or flag_value is int or flag_value is String):
			continue
		state.flags[StringName(str(key))] = flag_value
	return state


static func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
