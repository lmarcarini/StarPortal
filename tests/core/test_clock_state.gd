## Tests for ClockState's time-control fields: defaults, the computed is_paused property,
## the saved format, a v2 round trip and validate_dict.
## Bible: technical-architecture.md#data-model, technical-architecture.md#save-system,
## game-design.md#time-real-time-with-pause
extends GdUnitTestSuite

const SimClockScript := preload("res://src/core/sim_clock.gd")
const RUNNING := ClockState.Mode.RUNNING
const PAUSED := ClockState.Mode.PAUSED
const HELD := ClockState.Mode.HELD


func _json_round_trip(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return {}
	return parsed


## A valid saved clock that is HELD by two reasons and will pause afterwards.
func _held_data() -> Dictionary:
	return {
		"tick": 10,
		"speed_index": 1,
		"mode": "held",
		"holds": ["cutscene", "decision"],
		"mode_after_hold": "paused",
		"slows": [],
		"overridden": [],
	}


## A new clock is PAUSED with no holds and will stay paused after any hold.
func test_defaults() -> void:
	var clock := ClockState.new()
	assert_int(clock.mode).is_equal(PAUSED)
	assert_array(clock.holds).is_empty()
	assert_int(clock.mode_after_hold).is_equal(PAUSED)
	assert_bool(clock.is_paused).is_true()


## SPEED_COUNT matches the number of SimClock speeds.
func test_speed_count_matches_sim_clock() -> void:
	assert_int(ClockState.SPEED_COUNT).is_equal(SimClockScript.SPEEDS.size())


## is_paused reads true in every mode but RUNNING.
func test_is_paused_getter_is_computed_from_mode() -> void:
	var clock := ClockState.new()
	for mode: ClockState.Mode in [RUNNING, PAUSED, HELD]:
		clock.mode = mode
		assert_bool(clock.is_paused).is_equal(mode != RUNNING)


## Setting is_paused is a player pause or resume request.
func test_is_paused_setter_requests_pause_and_resume() -> void:
	var clock := ClockState.new()
	clock.is_paused = false
	assert_int(clock.mode).is_equal(RUNNING)
	clock.is_paused = false
	assert_int(clock.mode).is_equal(RUNNING)
	clock.is_paused = true
	assert_int(clock.mode).is_equal(PAUSED)


## While HELD the setter changes only mode_after_hold and never clears a hold.
func test_is_paused_setter_never_clears_a_hold() -> void:
	var clock := ClockState.new()
	TimeControl.add_hold(clock, &"cutscene")
	clock.is_paused = false
	assert_int(clock.mode).is_equal(HELD)
	assert_bool(clock.is_paused).is_true()
	assert_array(clock.holds).is_equal([&"cutscene"])
	assert_int(clock.mode_after_hold).is_equal(RUNNING)
	clock.is_paused = true
	assert_int(clock.mode_after_hold).is_equal(PAUSED)
	TimeControl.release_hold(clock, &"cutscene")
	assert_int(clock.mode).is_equal(PAUSED)


## to_dict stores modes as lowercase strings and holds as strings, and no is_paused.
func test_to_dict_format() -> void:
	var clock := ClockState.new()
	clock.tick = 10
	TimeControl.add_hold(clock, &"cutscene")
	TimeControl.add_hold(clock, &"decision")
	assert_dict(clock.to_dict()).is_equal(_held_data())
	clock.mode = RUNNING
	clock.holds.clear()
	var data := clock.to_dict()
	assert_str(data["mode"]).is_equal("running")
	assert_bool(data.has("is_paused")).is_false()


## A v2 clock round-trips mode, holds and mode_after_hold exactly through JSON.
func test_v2_round_trip_through_json() -> void:
	for after: ClockState.Mode in [RUNNING, PAUSED]:
		var clock := ClockState.new()
		clock.tick = 77
		clock.speed_index = 3
		clock.mode = after
		TimeControl.add_hold(clock, &"cutscene")
		TimeControl.add_hold(clock, &"decision")
		var data := _json_round_trip(clock.to_dict())
		assert_array(ClockState.validate_dict(data)).is_empty()
		var restored := ClockState.from_dict(data)
		assert_int(restored.mode).is_equal(HELD)
		assert_array(restored.holds).is_equal([&"cutscene", &"decision"])
		assert_int(restored.mode_after_hold).is_equal(after)
		assert_dict(restored.to_dict()).is_equal(clock.to_dict())
		TimeControl.release_hold(restored, &"cutscene")
		TimeControl.release_hold(restored, &"decision")
		assert_int(restored.mode).is_equal(after)


## from_dict keeps the defaults for missing or unreadable mode fields.
func test_from_dict_missing_fields_use_defaults() -> void:
	var clock := ClockState.from_dict({"mode": "frozen", "holds": "x"})
	assert_int(clock.mode).is_equal(PAUSED)
	assert_array(clock.holds).is_empty()
	assert_int(clock.mode_after_hold).is_equal(PAUSED)


## Valid clocks in every mode pass validate_dict.
func test_validate_accepts_every_mode() -> void:
	assert_array(ClockState.validate_dict(_held_data())).is_empty()
	for mode: String in ["running", "paused"]:
		var data := _held_data()
		data["mode"] = mode
		data["holds"] = []
		data["mode_after_hold"] = "running"
		assert_array(ClockState.validate_dict(data)).is_empty()


## validate_dict rejects each kind of bad clock. Each case is [key, value, error text];
## a null value removes the key.
func test_validate_rejects_bad_clocks() -> void:
	var cases: Array[Array] = [
		["mode", "frozen", "'mode' is not one of"],
		["mode", 1, "'mode' is not one of"],
		["mode", null, "missing 'mode'"],
		["holds", [], "'mode' is \"held\" but 'holds' is empty"],
		["holds", [3], "hold 0 is not a non-empty string"],
		["holds", ["cutscene", ""], "hold 1 is not a non-empty string"],
		["holds", ["cutscene", "cutscene"], "listed twice"],
		["holds", "cutscene", "'holds' is not an array"],
		["holds", null, "missing 'holds'"],
		["mode_after_hold", "held", "'mode_after_hold' is not"],
		["mode_after_hold", "frozen", "'mode_after_hold' is not"],
		["mode_after_hold", null, "missing 'mode_after_hold'"],
		["speed_index", ClockState.SPEED_COUNT, "'speed_index' is not below 4"],
		["speed_index", 4.0, "'speed_index' is not below 4"],
		["speed_index", -1, "'speed_index' is not a whole number"],
		["tick", 1.5, "'tick' is not a whole number"],
	]
	for case: Array in cases:
		var data := _held_data()
		if case[1] == null:
			data.erase(case[0])
		else:
			data[case[0]] = case[1]
		var expected: String = case[2]
		var errors := ClockState.validate_dict(data)
		var found := errors.any(func(error: String) -> bool: return error.contains(expected))
		assert_bool(found).override_failure_message(str(case) + " -> " + str(errors)).is_true()


## A clock that is not HELD but lists holds is rejected.
func test_validate_rejects_holds_when_not_held() -> void:
	for mode: String in ["running", "paused"]:
		var data := _held_data()
		data["mode"] = mode
		var errors := ClockState.validate_dict(data)
		assert_array(errors).contains(["'holds' is not empty but 'mode' is not \"held\""])


## The tick limit is exactly 2^53 (JsonLimits.MAX_EXACT_INT): the float 2^53 is accepted,
## the next double above it is not.
func test_validate_tick_boundary_is_two_pow_53() -> void:
	var limit: float = float(JsonLimits.MAX_EXACT_INT)
	var data := _held_data()
	data["tick"] = limit
	assert_array(ClockState.validate_dict(data)).is_empty()
	data["tick"] = limit + 2.0
	assert_array(ClockState.validate_dict(data)).contains(
		["'tick' is not a whole number from 0 to 2^53"]
	)
