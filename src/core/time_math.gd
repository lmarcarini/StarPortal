class_name TimeMath
extends RefCounted
## Pure conversions between simulation ticks and calendar dates. One tick is one in-game
## minute. Calendar rules (month lengths, leap years) come from Godot's Time singleton.
## Bible: technical-architecture.md#simulation-clock-and-commands

## Ticks in one in-game day.
const TICKS_PER_DAY: int = 1440
## Unix time of tick 0: 2026-01-01 00:00 UTC. Placeholder until BalanceConfig (M1).
const CAMPAIGN_START_UNIX: int = 1767225600

const _SECONDS_PER_TICK: int = 60


## Returns the calendar date of [param tick] as {year, month, day, hour, minute} ints.
static func date_of(tick: int) -> Dictionary:
	assert(tick >= 0, "TimeMath.date_of(): tick must not be negative")
	var unix_time: int = CAMPAIGN_START_UNIX + tick * _SECONDS_PER_TICK
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return {
		"year": datetime["year"],
		"month": datetime["month"],
		"day": datetime["day"],
		"hour": datetime["hour"],
		"minute": datetime["minute"],
	}


## Returns the number of whole days between tick 0 and [param tick].
static func day_index(tick: int) -> int:
	assert(tick >= 0, "TimeMath.day_index(): tick must not be negative")
	@warning_ignore("integer_division")
	return tick / TICKS_PER_DAY


## Returns true when [param tick] is the first minute of a day.
static func is_day_start(tick: int) -> bool:
	return tick % TICKS_PER_DAY == 0
