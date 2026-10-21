## Tests for Result and CommandResult, the typed outcomes of fallible operations.
## Bible: technical-architecture.md#errors-and-guard-clauses
extends GdUnitTestSuite


## Result.ok() without a value succeeds with a null value and no error.
func test_result_ok_without_value() -> void:
	var result := Result.ok()
	assert_bool(result.is_ok).is_true()
	assert_that(result.value).is_null()
	assert_str(String(result.error_code)).is_empty()
	assert_str(result.detail).is_empty()


## Result.ok(value) carries the value.
func test_result_ok_carries_value() -> void:
	var result := Result.ok(42)
	assert_bool(result.is_ok).is_true()
	assert_that(result.value).is_equal(42)


## Result.fail() records the code and detail and carries no value.
func test_result_fail_records_code_and_detail() -> void:
	var result := Result.fail(&"missing_file", "slot_1.json")
	assert_bool(result.is_ok).is_false()
	assert_that(result.value).is_null()
	assert_that(result.error_code).is_equal(&"missing_file")
	assert_str(result.detail).is_equal("slot_1.json")


## Result.fail() detail defaults to an empty string.
func test_result_fail_detail_defaults_to_empty() -> void:
	var result := Result.fail(&"bad_data")
	assert_bool(result.is_ok).is_false()
	assert_str(result.detail).is_empty()


## CommandResult.ok() succeeds with no error.
func test_command_result_ok() -> void:
	var result := CommandResult.ok()
	assert_bool(result.is_ok).is_true()
	assert_str(String(result.error_code)).is_empty()
	assert_str(result.detail).is_empty()


## CommandResult.fail() records the code and detail.
func test_command_result_fail_records_code_and_detail() -> void:
	var result := CommandResult.fail(&"ring_busy", "Ring is dialing")
	assert_bool(result.is_ok).is_false()
	assert_that(result.error_code).is_equal(&"ring_busy")
	assert_str(result.detail).is_equal("Ring is dialing")


## CommandResult.fail() detail defaults to an empty string.
func test_command_result_fail_detail_defaults_to_empty() -> void:
	var result := CommandResult.fail(&"no_address")
	assert_bool(result.is_ok).is_false()
	assert_str(result.detail).is_empty()
