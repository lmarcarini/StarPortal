class_name RequestRecord
extends RefCounted
## One request instance: which RequestDef, its state and its ticks. Ticks not reached yet are −1.
## Saved shape: {"uid", "request", "state", "offered_tick", "accepted_tick", "deadline_tick",
## "closed_tick"}.
## Bible: docs/content/m4-core-systems.md sections 4 and 9

## Lifecycle states; the same ints as RequestIsCondition.RequestState.
enum RequestState { OFFERED = 0, ACTIVE = 1, FULFILLED = 2, FAILED = 3, DECLINED = 4, LAPSED = 5 }

## Saved keys, in to_dict() order.
const KEYS: Array[String] = [
	"uid", "request", "state", "offered_tick", "accepted_tick", "deadline_tick", "closed_tick"
]
## Keys of ticks that must not be later than the clock (the deadline may be).
const PAST_TICKS: Array[String] = ["offered_tick", "accepted_tick", "closed_tick"]

## Unique id among requests.
var uid: int = 0
## Id of the RequestDef.
var request: StringName = &""
## Where it is in its lifecycle.
var state: RequestState = RequestState.OFFERED
## Tick it was offered.
var offered_tick: int = 0
## Tick it was accepted, or −1.
var accepted_tick: int = -1
## Tick of its deadline, or −1 when none (or not accepted yet).
var deadline_tick: int = -1
## Tick it closed (fulfilled, failed, declined, lapsed), or −1.
var closed_tick: int = -1


## True while it is OFFERED or ACTIVE.
func is_open() -> bool:
	return state == RequestState.OFFERED or state == RequestState.ACTIVE


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"request": String(request),
		"state": state,
		"offered_tick": offered_tick,
		"accepted_tick": accepted_tick,
		"deadline_tick": deadline_tick,
		"closed_tick": closed_tick,
	}


## Builds a record from valid saved [param data].
static func from_dict(data: Dictionary) -> RequestRecord:
	var record := RequestRecord.new()
	record.uid = SaveFields.read_int(data.get("uid"))
	record.request = SaveFields.read_id(data.get("request"))
	record.state = SaveFields.read_int(data.get("state")) as RequestState
	record.offered_tick = SaveFields.read_int(data.get("offered_tick"))
	record.accepted_tick = SaveFields.read_int(data.get("accepted_tick"), -1)
	record.deadline_tick = SaveFields.read_int(data.get("deadline_tick"), -1)
	record.closed_tick = SaveFields.read_int(data.get("closed_tick"), -1)
	return record


## Errors of saved [param data]: keys, a uid of at least 0, a request id, a known state, an
## offered tick, and the other ticks either ticks or −1.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not SaveFields.is_tick(data["uid"]):
		errors.append("'uid' is not a whole number of at least 0")
	if not SaveFields.is_id(data["request"]):
		errors.append("'request' is not a non-empty string")
	if not SaveFields.is_enum(data["state"], RequestState.size()):
		errors.append("'state' is not a request state")
	if not SaveFields.is_tick(data["offered_tick"]):
		errors.append("'offered_tick' is not a tick")
	for key: String in ["accepted_tick", "deadline_tick", "closed_tick"]:
		if not SaveFields.is_tick_or_unset(data[key]):
			errors.append("'%s' is not a tick or -1" % key)
	return errors
