class_name CommitteeState
extends RefCounted
## Saved state of the Committee (docs/content/m26-staff-and-money.md sections 4, 5 and 8):
## Confidence, month-ends in the red in a row, what has already earned Confidence (so each
## lock, survey and project counts once) and the last few month-end reports, oldest first.
## Only EconomySystem (through MonthEnd) changes it.
## Saved shape: {"confidence", "months_in_red", "credited_locks": [world id...],
## "credited_surveys": [world id...], "credited_research": [project id...],
## "reports": [MonthReport...]}.
## Bible: docs/content/m26-staff-and-money.md sections 4, 5 and 8

## Saved id-list keys.
const ID_KEYS: Array[String] = ["credited_locks", "credited_surveys", "credited_research"]

## Committee Confidence, 0 to 100.
var confidence: int = ConfidenceRules.START
## Month-ends in a row that ended below zero; reset by one at or above zero.
var months_in_red: int = 0
## Worlds whose first lock already counted.
var credited_locks: Array[StringName] = []
## Worlds whose first survey (horizon record) already counted.
var credited_surveys: Array[StringName] = []
## Research projects whose completion already counted.
var credited_research: Array[StringName] = []
## The last [constant ConfidenceRules.REPORTS_KEPT] month-end reports, oldest first.
var reports: Array[MonthReport] = []


## A fresh Committee for [param state]: Confidence at the start value, and everything the
## state already has (locks, surveys, research) credited so it never counts.
static func starting(state: GameState) -> CommitteeState:
	var committee := CommitteeState.new()
	committee.credited_locks = ConfidenceRules.locked_worlds(state)
	committee.credited_surveys = ConfidenceRules.surveyed_worlds(state)
	committee.credited_research = state.research.done.duplicate()
	return committee


## The newest report, or null before the first month-end.
func latest_report() -> MonthReport:
	return null if reports.is_empty() else reports.back()


## Adds [param report] as the newest, dropping the oldest beyond the cap.
func add_report(report: MonthReport) -> void:
	reports.append(report)
	while reports.size() > ConfidenceRules.REPORTS_KEPT:
		reports.pop_front()


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var report_data: Array = []
	for report: MonthReport in reports:
		report_data.append(report.to_dict())
	return {
		"confidence": confidence,
		"months_in_red": months_in_red,
		"credited_locks": _strings(credited_locks),
		"credited_surveys": _strings(credited_surveys),
		"credited_research": _strings(credited_research),
		"reports": report_data,
	}


## Builds a CommitteeState from saved [param data] (whole floats become ints). Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> CommitteeState:
	var committee := CommitteeState.new()
	if JsonLimits.is_exact_int(data.get("confidence")):
		committee.confidence = type_convert(data["confidence"], TYPE_INT)
	committee.months_in_red = RoomState.read_count(data.get("months_in_red"))
	committee.credited_locks = _ids(data.get("credited_locks"))
	committee.credited_surveys = _ids(data.get("credited_surveys"))
	committee.credited_research = _ids(data.get("credited_research"))
	var report_data: Variant = data.get("reports")
	if report_data is Array:
		var list: Array = report_data
		for item: Variant in list:
			if item is Dictionary:
				var item_data: Dictionary = item
				committee.add_report(MonthReport.from_dict(item_data))
	return committee


## Returns human-readable errors for saved [param data], empty when it is valid: Confidence a
## whole number from 0 to 100, months in the red a count, the id lists arrays of strings and
## "reports" at most ConfidenceRules.REPORTS_KEPT valid reports.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var value: Variant = data.get("confidence")
	var number: float = type_convert(value, TYPE_FLOAT) if JsonLimits.is_exact_int(value) else -1.0
	if number < 0.0 or number > ConfidenceRules.MAX:
		errors.append("'confidence' is not a whole number from 0 to 100")
	if not RoomState.is_count(data.get("months_in_red")):
		errors.append("'months_in_red' is not a whole number of at least 0")
	for key: String in ID_KEYS:
		if not _is_string_list(data.get(key)):
			errors.append("'%s' is not an array of strings" % key)
	var report_data: Variant = data.get("reports")
	var list: Array = report_data if report_data is Array else []
	if not report_data is Array or list.size() > ConfidenceRules.REPORTS_KEPT:
		errors.append("'reports' is not an array of at most %d" % ConfidenceRules.REPORTS_KEPT)
		return errors
	for index: int in list.size():
		if not list[index] is Dictionary:
			errors.append("reports %d is not an object" % index)
			continue
		var item_data: Dictionary = list[index]
		for error: String in MonthReport.validate_dict(item_data):
			errors.append("reports %d: %s" % [index, error])
	return errors


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
