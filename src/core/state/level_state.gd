class_name LevelState
extends RefCounted
## Saved state of one level of the base. Levels are dug whole; a level being dug holds no
## rooms until its digging ends. Its number is its place in BaseState.levels plus 1 (level 1
## the top underground level; the base has no surface level).
## Saved shape: {"dig_ticks_left"}.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model

## Ticks of digging left; 0 means dug and open for rooms.
var dig_ticks_left: int = 0


## True when the level is dug and can hold rooms.
func is_dug() -> bool:
	return dig_ticks_left == 0


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {"dig_ticks_left": dig_ticks_left}


## Builds a LevelState from saved [param data]; an unreadable value is 0.
static func from_dict(data: Dictionary) -> LevelState:
	var level := LevelState.new()
	level.dig_ticks_left = RoomState.read_count(data.get("dig_ticks_left"))
	return level


## Returns human-readable errors for saved [param data], empty when it is valid:
## "dig_ticks_left" a whole number of at least 0.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not RoomState.is_count(data.get("dig_ticks_left")):
		errors.append("'dig_ticks_left' is not a whole number of at least 0")
	return errors
