class_name ClockState
extends RefCounted
## Saved state of the simulation clock: the current tick, speed and pause flag.
## Bible: technical-architecture.md#data-model

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
