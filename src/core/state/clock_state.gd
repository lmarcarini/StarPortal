class_name ClockState
extends RefCounted
## Saved state of the simulation clock: the current tick, speed and pause flag.
## Bible: technical-architecture.md#data-model

## Largest whole number a JSON number (a double) holds exactly: 2^53.
const _MAX_EXACT_JSON_INT: float = 9007199254740992.0

## Ticks elapsed since the campaign start; one tick is one in-game minute.
var tick: int = 0
## Index into SimClock.SPEEDS.
var speed_index: int = 1
## True while the clock is paused.
var is_paused: bool = true


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {"tick": tick, "speed_index": speed_index, "is_paused": is_paused}


## Builds a ClockState from saved [param data]. Missing keys keep their defaults; JSON
## floats are cast back to ints.
static func from_dict(data: Dictionary) -> ClockState:
	var clock := ClockState.new()
	clock.tick = type_convert(data.get("tick", clock.tick), TYPE_INT)
	var speed_index_data: Variant = data.get("speed_index", clock.speed_index)
	clock.speed_index = type_convert(speed_index_data, TYPE_INT)
	clock.is_paused = type_convert(data.get("is_paused", clock.is_paused), TYPE_BOOL)
	return clock


## Returns human-readable errors for saved [param data], empty when it is valid: "tick" and
## "speed_index" must be whole numbers from 0 to 2^53 (JSON numbers are doubles), and
## "is_paused" a bool. The upper bound of speed_index is SimClock's to check.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["tick", "speed_index"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not _is_count(data[key]):
			errors.append("'%s' is not a whole number from 0 to 2^53" % key)
	if not data.has("is_paused"):
		errors.append("missing 'is_paused'")
	elif not data["is_paused"] is bool:
		errors.append("'is_paused' is not a bool")
	return errors


## True for an int, or a whole float, from 0 to 2^53.
static func _is_count(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = value
	return number == floorf(number) and number >= 0.0 and number <= _MAX_EXACT_JSON_INT
