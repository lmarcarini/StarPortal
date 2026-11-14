class_name OutcomeState
extends RefCounted
## Whether the game still runs (M4c): RUNNING, or FAILED with a cause and the tick it ended,
## and the two warning counters (days at Confidence 0, days with funds below zero).
## Saved shape: {"status", "cause", "tick", "zero_confidence_days", "negative_funds_days"}.
## Bible: docs/content/m4c-incursions.md sections 8 and 9

## RUNNING until a failure ends the game.
enum Status { RUNNING, FAILED }

## Saved names of the statuses, indexed by Status value.
const STATUS_NAMES: Array[String] = ["running", "failed"]
## Saved keys, in to_dict() order.
const KEYS: Array[String] = [
	"status", "cause", "tick", "zero_confidence_days", "negative_funds_days"
]

## RUNNING or FAILED.
var status: Status = Status.RUNNING
## Why it failed (&"overrun"), or &"".
var cause: StringName = &""
## Tick it failed, or −1.
var tick: int = -1
## Daily settlements in a row at Confidence 0.
var zero_confidence_days: int = 0
## Daily settlements in a row with funds below zero.
var negative_funds_days: int = 0


## True once the game has ended.
func has_failed() -> bool:
	return status == Status.FAILED


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"status": StateNames.write(STATUS_NAMES, status),
		"cause": String(cause),
		"tick": tick,
		"zero_confidence_days": zero_confidence_days,
		"negative_funds_days": negative_funds_days,
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> OutcomeState:
	var outcome := OutcomeState.new()
	outcome.status = StateNames.read(STATUS_NAMES, data.get("status")) as Status
	outcome.cause = StringName(str(data.get("cause", "")))
	outcome.tick = SaveFields.read_int(data.get("tick"), -1)
	outcome.zero_confidence_days = SaveFields.read_int(data.get("zero_confidence_days"))
	outcome.negative_funds_days = SaveFields.read_int(data.get("negative_funds_days"))
	return outcome


## Errors of saved [param data]; FAILED needs a cause and a tick.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not StateNames.is_name(STATUS_NAMES, data["status"]):
		errors.append("'status' is not running or failed")
	if not data["cause"] is String:
		errors.append("'cause' is not a String")
	if not SaveFields.is_tick_or_unset(data["tick"]):
		errors.append("'tick' is not a tick or -1")
	if data["status"] == "failed" and (str(data["cause"]).is_empty() or data["tick"] == -1):
		errors.append("a failed outcome needs a cause and a tick")
	for key: String in ["zero_confidence_days", "negative_funds_days"]:
		if not (SaveFields.is_int(data[key]) and data[key] >= 0):
			errors.append("'%s' is not a whole number of at least 0" % key)
	return errors
