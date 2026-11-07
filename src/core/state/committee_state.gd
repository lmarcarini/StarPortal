class_name CommitteeState
extends RefCounted
## Saved state of the Committee and the daily settlement (docs/content/m27-daily-rhythm.md
## sections 1, 2 and 7): Confidence in tenths, the cost carry, the last 30 daily balances, the
## last 10 causes, settlements in a row in the red, the commendation and Confidence 0 flags,
## and what has already earned Confidence (so each lock, survey and project counts once).
## Only EconomySystem (through DailySettlement and ConfidenceEvents) changes it.
## Saved shape: {"confidence" (tenths), "cost_carry", "days_in_red", "commendation_paid",
## "zero_warned", "funds_history": [int...], "causes": [ConfidenceCause...],
## "credited_locks": [world id...], "credited_surveys": [world id...],
## "credited_research": [project id...]}.
## Bible: docs/content/m27-daily-rhythm.md sections 1, 2 and 7

## Saved id-list keys.
const ID_KEYS: Array[String] = ["credited_locks", "credited_surveys", "credited_research"]
## Saved count keys.
const COUNT_KEYS: Array[String] = ["cost_carry", "days_in_red"]
## Saved flag keys.
const FLAG_KEYS: Array[String] = ["commendation_paid", "zero_warned"]

## Committee Confidence in tenths, 0 to 1000.
var confidence: int = ConfidenceRules.START
## Remainder of the daily cost division carried to the next settlement, 0 to 29.
var cost_carry: int = 0
## Settlements in a row that ended below zero; reset by one at or above zero.
var days_in_red: int = 0
## True once the commendation is paid, until Confidence falls below 60.
var commendation_paid: bool = false
## True once the Confidence 0 warning is given, until Confidence rises above 10.
var zero_warned: bool = false
## The balance after each of the last 30 settlements, oldest first, in $k.
var funds_history: Array[int] = []
## The last 10 Confidence causes, oldest first.
var causes: Array[ConfidenceCause] = []
## Worlds whose first lock already counted.
var credited_locks: Array[StringName] = []
## Worlds whose first survey (horizon record) already counted.
var credited_surveys: Array[StringName] = []
## Research projects whose completion already counted.
var credited_research: Array[StringName] = []


## A fresh Committee for [param state]: Confidence at the start value, and everything the
## state already has (locks, surveys, research) credited so it never counts.
static func starting(state: GameState) -> CommitteeState:
	var committee := CommitteeState.new()
	committee.credited_locks = ConfidenceRules.locked_worlds(state)
	committee.credited_surveys = ConfidenceRules.surveyed_worlds(state)
	committee.credited_research = state.research.done.duplicate()
	return committee


## Confidence's whole part, 0 to 100.
func whole() -> int:
	return ConfidenceRules.whole(confidence)


## Adds [param cause] as the newest, dropping the oldest beyond ConfidenceRules.CAUSES_KEPT.
func add_cause(cause: ConfidenceCause) -> void:
	causes.append(cause)
	while causes.size() > ConfidenceRules.CAUSES_KEPT:
		causes.pop_front()


## Records [param funds_k] as the newest daily balance, keeping the last 30.
func add_funds_record(funds_k: int) -> void:
	funds_history.append(funds_k)
	while funds_history.size() > ConfidenceRules.FUNDS_HISTORY_KEPT:
		funds_history.pop_front()


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var cause_data: Array = []
	for cause: ConfidenceCause in causes:
		cause_data.append(cause.to_dict())
	return {
		"confidence": confidence,
		"cost_carry": cost_carry,
		"days_in_red": days_in_red,
		"commendation_paid": commendation_paid,
		"zero_warned": zero_warned,
		"funds_history": funds_history.duplicate(),
		"causes": cause_data,
		"credited_locks": _strings(credited_locks),
		"credited_surveys": _strings(credited_surveys),
		"credited_research": _strings(credited_research),
	}


## Builds a CommitteeState from saved [param data] (whole floats become ints). Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> CommitteeState:
	var committee := CommitteeState.new()
	if JsonLimits.is_exact_int(data.get("confidence")):
		committee.confidence = type_convert(data["confidence"], TYPE_INT)
	for key: String in COUNT_KEYS:
		committee.set(key, RoomState.read_count(data.get(key)))
	for key: String in FLAG_KEYS:
		committee.set(key, data.get(key, false) == true)
	var balance_data: Variant = data.get("funds_history")
	if balance_data is Array:
		var list: Array = balance_data
		for item: Variant in list:
			if JsonLimits.is_exact_int(item):
				var amount_k: int = type_convert(item, TYPE_INT)
				committee.add_funds_record(amount_k)
	var cause_data: Variant = data.get("causes")
	if cause_data is Array:
		var list: Array = cause_data
		for item: Variant in list:
			if item is Dictionary:
				var item_data: Dictionary = item
				committee.add_cause(ConfidenceCause.from_dict(item_data))
	committee.credited_locks = _ids(data.get("credited_locks"))
	committee.credited_surveys = _ids(data.get("credited_surveys"))
	committee.credited_research = _ids(data.get("credited_research"))
	return committee


## Returns human-readable errors for saved [param data], empty when it is valid: Confidence a
## whole number from 0 to 1000, the carry 0 to 29, days in the red a count, the flags bools,
## at most 30 whole balances, at most 10 valid causes and the id lists arrays of strings.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not _is_in_range(data.get("confidence"), ConfidenceRules.MAX):
		errors.append("'confidence' is not a whole number from 0 to 1000")
	if not _is_in_range(data.get("cost_carry"), ConfidenceRules.PERIOD_DAYS - 1):
		errors.append("'cost_carry' is not a whole number from 0 to 29")
	if not RoomState.is_count(data.get("days_in_red")):
		errors.append("'days_in_red' is not a whole number of at least 0")
	for key: String in FLAG_KEYS:
		if not data.get(key) is bool:
			errors.append("'%s' is missing or not a bool" % key)
	for key: String in ID_KEYS:
		if not _is_string_list(data.get(key)):
			errors.append("'%s' is not an array of strings" % key)
	if not _is_int_list(data.get("funds_history"), ConfidenceRules.FUNDS_HISTORY_KEPT):
		errors.append("'funds_history' is not at most 30 whole numbers")
	errors.append_array(_cause_errors(data.get("causes")))
	return errors


static func _cause_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	var list: Array = value if value is Array else []
	if not value is Array or list.size() > ConfidenceRules.CAUSES_KEPT:
		errors.append("'causes' is not an array of at most %d" % ConfidenceRules.CAUSES_KEPT)
		return errors
	for index: int in list.size():
		if not list[index] is Dictionary:
			errors.append("causes %d is not an object" % index)
			continue
		var item_data: Dictionary = list[index]
		for error: String in ConfidenceCause.validate_dict(item_data):
			errors.append("causes %d: %s" % [index, error])
	return errors


static func _is_in_range(value: Variant, top: int) -> bool:
	if not RoomState.is_count(value):
		return false
	var number: float = value
	return number <= top


static func _is_int_list(value: Variant, longest: int) -> bool:
	if not value is Array:
		return false
	var list: Array = value
	if list.size() > longest:
		return false
	for item: Variant in list:
		if not JsonLimits.is_exact_int(item):
			return false
	return true


static func _strings(ids: Array[StringName]) -> Array:
	var out: Array = []
	for id: StringName in ids:
		out.append(String(id))
	return out


static func _ids(value: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if value is Array:
		var list: Array = value
		for item: Variant in list:
			if item is String and not StringName(str(item)) in ids:
				ids.append(StringName(str(item)))
	return ids


static func _is_string_list(value: Variant) -> bool:
	if not value is Array:
		return false
	var list: Array = value
	for item: Variant in list:
		if not item is String:
			return false
	return true
