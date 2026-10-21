class_name CommandResult
extends RefCounted
## Outcome of validating or submitting a Command: success, or an error code with detail.
## Same shape as Result, without a value.
## Bible: technical-architecture.md#errors-and-guard-clauses

## True when the command is valid or was accepted.
var is_ok: bool
## Machine-readable failure reason, e.g. &"ring_busy". Empty on success.
var error_code: StringName
## Human-readable failure detail for logs. Empty on success.
var detail: String


## Returns a successful command result.
static func ok() -> CommandResult:
	var result := CommandResult.new()
	result.is_ok = true
	return result


## Returns a failed command result with error [param code] and optional [param detail].
@warning_ignore("shadowed_variable")
static func fail(code: StringName, detail: String = "") -> CommandResult:
	var result := CommandResult.new()
	result.is_ok = false
	result.error_code = code
	result.detail = detail
	return result
