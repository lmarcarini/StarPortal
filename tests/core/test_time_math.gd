## Tests for TimeMath tick to calendar conversions, including a leap day.
## Bible: technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const DAY: int = TimeMath.TICKS_PER_DAY
## Days from 2026-01-01 to 2028-02-29: 365 (2026) + 365 (2027) + 31 (Jan) + 28 (Feb).
const LEAP_DAY_INDEX: int = 789


func _date(year: int, month: int, day: int, hour: int, minute: int) -> Dictionary:
	return {"year": year, "month": month, "day": day, "hour": hour, "minute": minute}


## The campaign starts at 2026-01-01 00:00 UTC.
func test_campaign_start_is_2026_01_01_utc() -> void:
	var expected: int = Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00")
	assert_int(TimeMath.CAMPAIGN_START_UNIX).is_equal(expected)


## Tick 0 is 2026-01-01 00:00.
func test_tick_zero_is_campaign_start() -> void:
	assert_dict(TimeMath.date_of(0)).is_equal(_date(2026, 1, 1, 0, 0))


## One tick is one minute.
func test_tick_is_one_minute() -> void:
	assert_dict(TimeMath.date_of(61)).is_equal(_date(2026, 1, 1, 1, 1))
	assert_dict(TimeMath.date_of(DAY - 1)).is_equal(_date(2026, 1, 1, 23, 59))


## Tick 1440 starts day 1 (January 2); tick 1439 does not start a day.
func test_tick_1440_is_day_start() -> void:
	assert_bool(TimeMath.is_day_start(DAY)).is_true()
	assert_bool(TimeMath.is_day_start(DAY - 1)).is_false()
	assert_bool(TimeMath.is_day_start(DAY + 1)).is_false()
	assert_dict(TimeMath.date_of(DAY)).is_equal(_date(2026, 1, 2, 0, 0))


## day_index counts whole days since tick 0.
func test_day_index_counts_whole_days() -> void:
	assert_int(TimeMath.day_index(0)).is_equal(0)
	assert_int(TimeMath.day_index(DAY - 1)).is_equal(0)
	assert_int(TimeMath.day_index(DAY)).is_equal(1)
	assert_int(TimeMath.day_index(31 * DAY + 5)).is_equal(31)


## Tick 31 x 1440 is February 1 and starts a month; the day before does not.
func test_february_first_is_month_start() -> void:
	assert_dict(TimeMath.date_of(31 * DAY)).is_equal(_date(2026, 2, 1, 0, 0))
	assert_bool(TimeMath.is_month_start(31 * DAY)).is_true()
	assert_bool(TimeMath.is_month_start(30 * DAY)).is_false()
	assert_bool(TimeMath.is_month_start(31 * DAY + 1)).is_false()


## Tick 0 starts both a day and a month.
func test_tick_zero_is_day_and_month_start() -> void:
	assert_bool(TimeMath.is_day_start(0)).is_true()
	assert_bool(TimeMath.is_month_start(0)).is_true()


## 2026 is not a leap year: February 28 is followed by March 1.
func test_non_leap_february_has_28_days() -> void:
	assert_dict(TimeMath.date_of(58 * DAY)).is_equal(_date(2026, 2, 28, 0, 0))
	assert_dict(TimeMath.date_of(59 * DAY)).is_equal(_date(2026, 3, 1, 0, 0))
	assert_bool(TimeMath.is_month_start(59 * DAY)).is_true()


## 2028 is a leap year: 2028-02-29 exists and is not a month start; March 1 follows it.
func test_leap_day_2028_02_29() -> void:
	var leap_tick: int = LEAP_DAY_INDEX * DAY
	assert_dict(TimeMath.date_of(leap_tick)).is_equal(_date(2028, 2, 29, 0, 0))
	assert_bool(TimeMath.is_day_start(leap_tick)).is_true()
	assert_bool(TimeMath.is_month_start(leap_tick)).is_false()
	assert_dict(TimeMath.date_of(leap_tick + DAY)).is_equal(_date(2028, 3, 1, 0, 0))
	assert_bool(TimeMath.is_month_start(leap_tick + DAY)).is_true()
	assert_int(TimeMath.day_index(leap_tick + 90)).is_equal(LEAP_DAY_INDEX)
