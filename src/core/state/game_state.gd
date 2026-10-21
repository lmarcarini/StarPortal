class_name GameState
extends RefCounted
## Root of all runtime state; the only thing saved. Sub-states are plain RefCounted
## classes that convert to and from JSON-safe dictionaries.
## Bible: technical-architecture.md#data-model

## Largest whole number a JSON number (a double) holds exactly: 2^53.
const _MAX_EXACT_JSON_INT: float = 9007199254740992.0

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


## Returns human-readable errors for saved [param data], empty when it is valid: "clock",
## "random" and "flags" must be objects, the sub-states must pass their own validate_dict(),
## and every flag must be a bool, a String or a whole number. Errors from a sub-state are
## prefixed with its key, e.g. "clock: 'tick' is not a whole number ...".
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["clock", "random", "flags"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not data[key] is Dictionary:
			errors.append("'%s' is not an object" % key)
	if not errors.is_empty():
		return errors
	var clock_data: Dictionary = data["clock"]
	var random_data: Dictionary = data["random"]
	var flag_data: Dictionary = data["flags"]
	for error: String in ClockState.validate_dict(clock_data):
		errors.append("clock: " + error)
	for error: String in RandomState.validate_dict(random_data):
		errors.append("random: " + error)
	for key: Variant in flag_data:
		if not _is_flag_value(flag_data[key]):
			errors.append("flag '%s' is not a bool, String or whole number" % str(key))
	return errors


static func _is_flag_value(value: Variant) -> bool:
	if value is bool or value is int or value is String:
		return true
	if not value is float:
		return false
	var number: float = value
	return number == floorf(number) and absf(number) <= _MAX_EXACT_JSON_INT


static func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
