class_name MonthReport
extends RefCounted
## One month-end report (docs/content/m26-staff-and-money.md sections 4 and 5): the money paid
## and charged, the Committee Confidence causes with their amounts, the quarterly review and
## the warnings. Built by MonthEnd at each month-end; read by the report UI and the Log.
## Saved shape (also the Log entry's args, so only Strings, bools, ints and int lists):
## {"year", "month" (date of the month-end, e.g. 2 for 1 February), "allocation_k",
## "upkeep_k" (rooms), "salaries_k", "people", "funds_before_k", "funds_after_k" (after the
## grant), "confidence_before", "confidence_after", "amounts" and "counts" (one int per
## [constant ConfidenceRules.CAUSES] entry), "locked_worlds" and "surveyed_worlds" (world ids
## joined by commas), "review" ("" or a [constant ConfidenceRules.REVIEWS] key), "grant_k",
## "next_allocation_k", "months_in_red", "warn_red_months", "warn_confidence_zero"}.
## Bible: docs/content/m26-staff-and-money.md sections 4 and 5

## Whole-number keys, in to_dict() order.
const INT_KEYS: Array[String] = [
	"year",
	"month",
	"allocation_k",
	"upkeep_k",
	"salaries_k",
	"people",
	"funds_before_k",
	"funds_after_k",
	"confidence_before",
	"confidence_after",
	"grant_k",
	"next_allocation_k",
	"months_in_red",
]
## Whole-number list keys, each one entry per cause.
const LIST_KEYS: Array[String] = ["amounts", "counts"]
## String keys.
const STRING_KEYS: Array[String] = ["locked_worlds", "surveyed_worlds", "review"]
## Bool keys.
const BOOL_KEYS: Array[String] = ["warn_red_months", "warn_confidence_zero"]

## Year and month of the month-end date.
var year: int = 1
var month: int = 1
## Allocation paid, room upkeep and salaries charged, in $k.
var allocation_k: int = 0
var upkeep_k: int = 0
var salaries_k: int = 0
## People paid (the roster, arrivals included).
var people: int = 0
## Balance before the month-end and after it (grant included), in $k.
var funds_before_k: int = 0
var funds_after_k: int = 0
## Confidence before and after the month's change.
var confidence_before: int = 0
var confidence_after: int = 0
## Change and count per cause, in [constant ConfidenceRules.CAUSES] order. A cause with a 0
## count and a 0 amount did not apply. The cap's amount is what it took off (or added).
var amounts: Array[int] = []
var counts: Array[int] = []
## World ids of the new locks and surveys, in id order.
var locked_worlds: Array[StringName] = []
var surveyed_worlds: Array[StringName] = []
## The quarterly review: &"" outside a quarter month, else a ConfidenceRules.REVIEWS key.
var review: StringName = &""
## Grant paid by the review, in $k.
var grant_k: int = 0
## Allocation the next month-end will pay, in $k.
var next_allocation_k: int = 0
## Month-ends in a row ending below zero, this one included.
var months_in_red: int = 0
## Warnings raised: months in the red reached the limit, Confidence reached 0.
var warn_red_months: bool = false
var warn_confidence_zero: bool = false


## Returns a report with every cause at 0.
static func blank() -> MonthReport:
	var report := MonthReport.new()
	for _cause: StringName in ConfidenceRules.CAUSES:
		report.amounts.append(0)
		report.counts.append(0)
	return report


## The change of [param cause] (a ConfidenceRules.CAUSES id), 0 when unknown.
func amount_of(cause: StringName) -> int:
	var index: int = ConfidenceRules.CAUSES.find(cause)
	return amounts[index] if index >= 0 and index < amounts.size() else 0


## The count of [param cause] (worlds, projects, analysts; 1 for a month cause).
func count_of(cause: StringName) -> int:
	var index: int = ConfidenceRules.CAUSES.find(cause)
	return counts[index] if index >= 0 and index < counts.size() else 0


## The causes that applied this month, in ConfidenceRules.CAUSES order.
func applied_causes() -> Array[StringName]:
	var applied: Array[StringName] = []
	for cause: StringName in ConfidenceRules.CAUSES:
		if amount_of(cause) != 0 or count_of(cause) != 0:
			applied.append(cause)
	return applied


## Returns JSON-safe data for saving; also valid LogEntry args.
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	for key: String in INT_KEYS:
		data[key] = get(key)
	data["amounts"] = amounts.duplicate()
	data["counts"] = counts.duplicate()
	data["locked_worlds"] = ",".join(PackedStringArray(locked_worlds))
	data["surveyed_worlds"] = ",".join(PackedStringArray(surveyed_worlds))
	data["review"] = String(review)
	data["warn_red_months"] = warn_red_months
	data["warn_confidence_zero"] = warn_confidence_zero
	return data


## Builds a report from saved [param data] (or a Log entry's args); whole floats become ints.
## Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> MonthReport:
	var report := MonthReport.blank()
	for key: String in INT_KEYS:
		if JsonLimits.is_exact_int(data.get(key)):
			report.set(key, type_convert(data[key], TYPE_INT))
	for key: String in LIST_KEYS:
		var list: Array[int] = report.get(key)
		var saved: Variant = data.get(key)
		if not saved is Array:
			continue
		var saved_list: Array = saved
		if saved_list.size() == list.size():
			for index: int in list.size():
				list[index] = type_convert(saved_list[index], TYPE_INT)
	report.locked_worlds = _ids(data.get("locked_worlds"))
	report.surveyed_worlds = _ids(data.get("surveyed_worlds"))
	report.review = StringName(str(data.get("review", "")))
	report.warn_red_months = data.get("warn_red_months", false) == true
	report.warn_confidence_zero = data.get("warn_confidence_zero", false) == true
	return report


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present with its type, Confidence before and after from 0 to 100, each list one whole
## number per cause, and "review" empty or a review key.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in INT_KEYS:
		if not JsonLimits.is_exact_int(data.get(key)):
			errors.append("'%s' is missing or not a whole number" % key)
	for key: String in LIST_KEYS:
		if not _is_int_list(data.get(key)):
			errors.append("'%s' is not a list of %d whole numbers" % [key, _cause_count()])
	for key: String in STRING_KEYS:
		if not data.get(key) is String:
			errors.append("'%s' is missing or not a string" % key)
	for key: String in BOOL_KEYS:
		if not data.get(key) is bool:
			errors.append("'%s' is missing or not a bool" % key)
	for key: String in ["confidence_before", "confidence_after"]:
		var value: Variant = data.get(key)
		if JsonLimits.is_exact_int(value):
			var number: float = type_convert(value, TYPE_FLOAT)
			if number < ConfidenceRules.MIN or number > ConfidenceRules.MAX:
				errors.append("'%s' is not from 0 to 100" % key)
	var review_value: Variant = data.get("review")
	if review_value is String and not str(review_value).is_empty():
		if not ConfidenceRules.REVIEWS.has(StringName(str(review_value))):
			errors.append("'review' is not a review")
	return errors


static func _cause_count() -> int:
	return ConfidenceRules.CAUSES.size()


static func _is_int_list(value: Variant) -> bool:
	if not value is Array:
		return false
	var list: Array = value
	if list.size() != _cause_count():
		return false
	for item: Variant in list:
		if not JsonLimits.is_exact_int(item):
			return false
	return true


static func _ids(value: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not value is String:
		return ids
	for part: String in str(value).split(",", false):
		ids.append(StringName(part))
	return ids
