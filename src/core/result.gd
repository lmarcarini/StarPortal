class_name Result
extends RefCounted
## Outcome of a fallible operation that is not a command: a value on success, or an
## error code with detail on an expected failure. Programmer errors use assert() instead.
## Bible: technical-architecture.md#errors-and-guard-clauses

## True when the operation succeeded.
var is_ok: bool
## The produced value on success; null on failure.
var value: Variant
## Machine-readable failure reason, e.g. &"missing_file". Empty on success.
var error_code: StringName
## Human-readable failure detail for logs. Empty on success.
var detail: String

## Returns a successful result carrying [param value].
@warning_ignore("shadowed_variable")
static func ok(value: Variant = null) -> Result:
	var result := Result.new()
	result.is_ok = true
	result.value = value
	return result


## Returns a failed result with error [param code] and optional [param detail].
@warning_ignore("shadowed_variable")
static func fail(code: StringName, detail: String = "") -> Result:
	var result := Result.new()
	result.is_ok = false
	result.error_code = code
	result.detail = detail
	return result
