class_name AmbientRules
extends RefCounted
## Pure rules for ambient staff movement on the plan (presentation only): who is on shift at
## an hour and what a person does next. Never touches the simulation or its randomness.
## Bible: docs/content/interface-pass.md section 5 (Ambient life)

## Night runs from this hour to MORNING_HOUR.
const NIGHT_HOUR: int = 22
const MORNING_HOUR: int = 6
## One person in NIGHT_SHIFT_SHARE stays on shift at night (besides each room's keeper).
const NIGHT_SHIFT_SHARE: int = 4
## Chance a move is a visit to another room, else a change of spot.
const VISIT_CHANCE: float = 0.12
## Chance a person just stays where they are this time.
const STAY_CHANCE: float = 0.35
## Real seconds between a person's moves at 1x, low and high.
const WAIT_MIN: float = 4.0
const WAIT_MAX: float = 11.0


## True when [param hour] is at night.
static func is_night(hour: int) -> bool:
	return hour >= NIGHT_HOUR or hour < MORNING_HOUR


## True when [param person_id] works at [param hour]: everyone by day, a steady few at night.
static func on_shift(person_id: StringName, hour: int) -> bool:
	if not is_night(hour):
		return true
	return absi(hash(String(person_id))) % NIGHT_SHIFT_SHARE == 0


## What a person does next, from [param state]: stay, move to a free spot in their room, or
## visit another room. Uses only [param rng].
static func next_move(rng: RandomNumberGenerator, state: AmbientState) -> AmbientMove:
	var move := AmbientMove.new()
	if rng.randf() < STAY_CHANCE:
		return move
	if state.other_rooms > 0 and rng.randf() < VISIT_CHANCE:
		move.kind = AmbientMove.VISIT
		move.index = rng.randi_range(0, state.other_rooms - 1)
		return move
	var free: Array[int] = []
	for spot: int in state.spot_count:
		if not state.taken.has(spot):
			free.append(spot)
	if free.is_empty():
		return move
	move.kind = AmbientMove.SPOT
	move.index = free[rng.randi_range(0, free.size() - 1)]
	return move


## Real seconds until the next move, at clock speed factor [param factor].
static func wait_seconds(rng: RandomNumberGenerator, factor: float) -> float:
	return rng.randf_range(WAIT_MIN, WAIT_MAX) / maxf(factor, 0.1)
