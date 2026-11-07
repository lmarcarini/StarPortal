class_name ConfidenceCause
extends RefCounted
## One entry of the Committee's rolling cause list (docs/content/m27-daily-rhythm.md section
## 2): when Confidence changed, why, about what and by how much. Read by the Command tab and
## the Confidence readout's tooltip.
## Saved shape: {"tick", "cause" (a ConfidenceRules.CAUSES id), "subject" (world or project
## id, or ""), "count" (analysts for reports, else 1), "change" (tenths)}.
## Bible: docs/content/m27-daily-rhythm.md section 2

## Whole-number keys.
const INT_KEYS: Array[String] = ["tick", "count", "change"]

## Tick the change happened.
var tick: int = 0
## One of ConfidenceRules.CAUSES.
var cause: StringName = &""
## The world or project concerned; empty for reports.
var subject: StringName = &""
## Analysts for reports; 1 otherwise.
var count: int = 1
## Change in tenths of a point.
var change: int = 0


## A cause of [param kind] at [param at_tick] about [param about]; [param amounts] x is the
## count (analysts, else 1) and y the change in tenths.
static func create(
	at_tick: int, kind: StringName, about: StringName, amounts: Vector2i
) -> ConfidenceCause:
	var entry := ConfidenceCause.new()
	entry.tick = at_tick
	entry.cause = kind
	entry.subject = about
	entry.count = amounts.x
	entry.change = amounts.y
	return entry


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"cause": String(cause),
		"subject": String(subject),
		"count": count,
		"change": change,
	}


## Builds a cause from saved [param data] (whole floats become ints). Call validate_dict()
## first for untrusted data.
static func from_dict(data: Dictionary) -> ConfidenceCause:
	var entry := ConfidenceCause.new()
	for key: String in INT_KEYS:
		if JsonLimits.is_exact_int(data.get(key)):
			entry.set(key, type_convert(data[key], TYPE_INT))
	entry.cause = StringName(str(data.get("cause", "")))
	entry.subject = StringName(str(data.get("subject", "")))
	return entry


## Returns human-readable errors for saved [param data], empty when it is valid.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in INT_KEYS:
		if not JsonLimits.is_exact_int(data.get(key)):
			errors.append("'%s' is missing or not a whole number" % key)
	var kind: Variant = data.get("cause")
	if not kind is String or not ConfidenceRules.CAUSES.has(StringName(str(kind))):
		errors.append("'cause' is not a cause")
	if not data.get("subject") is String:
		errors.append("'subject' is missing or not a string")
	return errors
