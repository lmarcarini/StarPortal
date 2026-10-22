## Tests for SetFlagCommand.validate() at the JSON integer limit: an int flag value beyond
## 2^53 in absolute value cannot survive a save, so it is rejected.
## Bible: technical-architecture.md#simulation-clock-and-commands,
## technical-architecture.md#data-model
extends GdUnitTestSuite

const LIMIT: int = JsonLimits.MAX_EXACT_INT


func _validate(value: Variant) -> CommandResult:
	return SetFlagCommand.create(&"flag", value).validate(GameState.new_game(1))


## Ints from -2^53 to 2^53 pass validation.
func test_ints_within_two_pow_53_are_valid() -> void:
	for value: int in [0, -1, LIMIT, -LIMIT, LIMIT - 1]:
		var result := _validate(value)
		assert_bool(result.is_ok).override_failure_message(str(value)).is_true()


## Ints beyond 2^53 in absolute value fail with &"invalid_value".
func test_ints_beyond_two_pow_53_are_invalid() -> void:
	for value: int in [LIMIT + 1, -LIMIT - 1, 9223372036854775807, -9223372036854775807 - 1]:
		var result := _validate(value)
		assert_bool(result.is_ok).override_failure_message(str(value)).is_false()
		assert_str(result.error_code).override_failure_message(str(value)).is_equal(
			&"invalid_value"
		)


## Bools and Strings are unaffected by the limit.
func test_bools_and_strings_stay_valid() -> void:
	for value: Variant in [true, false, "", "9223372036854775807"]:
		assert_bool(_validate(value).is_ok).override_failure_message(str(value)).is_true()


## A queued command with an int beyond 2^53 is rejected and never reaches the state.
func test_queue_rejects_int_beyond_two_pow_53() -> void:
	var state := GameState.new_game(1)
	var queue := CommandQueue.new()
	var result := queue.submit(SetFlagCommand.create(&"big", LIMIT + 1), state)
	assert_str(result.error_code).is_equal(&"invalid_value")
	assert_bool(state.flags.has(&"big")).is_false()
