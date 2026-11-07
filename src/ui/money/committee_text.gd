class_name CommitteeText
extends RefCounted
## Words the Committee's daily rhythm (docs/content/m27-daily-rhythm.md sections 2 and 5) in
## the current locale: Confidence with one decimal, today's drift and why, a cause line
## ("New world locked: SILL  +5"), and the Log and message lines of reports filed, the
## commendation and the warnings.
## Bible: docs/content/m27-daily-rhythm.md sections 2 and 5

## Line key of each cause.
const CAUSE_KEYS: Dictionary[StringName, StringName] = {
	&"locked": &"CONFIDENCE_CAUSE_LOCKED",
	&"surveyed": &"CONFIDENCE_CAUSE_SURVEYED",
	&"research": &"CONFIDENCE_CAUSE_RESEARCH",
	&"reports": &"CONFIDENCE_CAUSE_REPORTS",
}
## Line key of each committee_warning reason.
const WARNING_KEYS: Dictionary[StringName, StringName] = {
	&"red_days": &"COMMITTEE_WARN_RED_DAYS",
	&"confidence_zero": &"COMMITTEE_WARN_CONFIDENCE_ZERO",
}


## [param tenths] as a value with one decimal: "61.4".
static func one_decimal(tenths: int) -> String:
	return "%d.%d" % [tenths / ConfidenceRules.TENTHS, tenths % ConfidenceRules.TENTHS]


## A change of [param tenths] with its sign: "+0.1", "-0.2", "+5" (whole points without a
## decimal), "0".
static func signed_tenths(tenths: int) -> String:
	if tenths == 0:
		return "0"
	var size: int = absi(tenths)
	var shown: String = str(size / ConfidenceRules.TENTHS)
	if size % ConfidenceRules.TENTHS != 0:
		shown = one_decimal(size)
	return ("+" if tenths > 0 else "-") + shown


## Today's drift for [param state]: what the next settlement applies with today's balance.
static func drift_of(state: GameState) -> int:
	return ConfidenceRules.drift(state.committee.confidence, state.budget.funds_k < 0)


## Why today's drift is what it is: "In the red", "Settling toward 50" or "Steady at 50".
static func drift_reason(state: GameState) -> String:
	if state.budget.funds_k < 0:
		return _tr(&"CONFIDENCE_DRIFT_IN_RED")
	if drift_of(state) == 0:
		return _tr(&"CONFIDENCE_DRIFT_STEADY")
	return _tr(&"CONFIDENCE_DRIFT_SETTLING")


## The line of [param cause], e.g. "New world locked: SILL  +5"; worlds and projects are
## named from [param state] when given.
static func cause_line(cause: ConfidenceCause, state: GameState) -> String:
	var key: StringName = CAUSE_KEYS.get(cause.cause, &"CONFIDENCE_CAUSE_REPORTS")
	if cause.cause == ConfidenceRules.REPORTS and cause.count == 1:
		key = &"CONFIDENCE_CAUSE_REPORTS_ONE"
	return (
		_tr(key)
		. format(
			{
				"name": _subject_name(cause, state),
				"count": cause.count,
				"amount": signed_tenths(cause.change),
			}
		)
	)


## The Log (and message) line of a "committee" entry's [param args]: reports filed, the
## commendation or a warning.
static func log_line(args: Dictionary) -> String:
	var reason: String = str(args.get("reason", ""))
	if reason == "reports":
		var count: int = type_convert(args.get("count", 0), TYPE_INT)
		var key: StringName = (
			&"COMMITTEE_LOG_REPORTS_ONE" if count == 1 else &"COMMITTEE_LOG_REPORTS"
		)
		return _tr(key).format({"count": count})
	if reason == "commendation":
		var amount_k: int = type_convert(args.get("amount_k", 0), TYPE_INT)
		return commendation_line(amount_k)
	var days: int = type_convert(args.get("days", 0), TYPE_INT)
	return warning_line(StringName(reason), days)


## "Committee commendation: $1,000k."
static func commendation_line(amount_k: int) -> String:
	return _tr(&"COMMITTEE_COMMENDATION").format({"amount": MoneyLabel.format_k(amount_k)})


## The line of a committee_warning [param reason] with [param days_in_red].
static func warning_line(reason: StringName, days_in_red: int) -> String:
	var key: StringName = WARNING_KEYS.get(reason, &"COMMITTEE_WARN_CONFIDENCE_ZERO")
	return _tr(key).format({"count": days_in_red})


static func _subject_name(cause: ConfidenceCause, state: GameState) -> String:
	if cause.subject.is_empty():
		return ""
	if cause.cause == ConfidenceRules.RESEARCH:
		var project: ResearchDef = Registry.get_def(cause.subject) as ResearchDef
		return String(cause.subject) if project == null else _tr(project.name_key)
	if state == null:
		return String(cause.subject)
	return AddressBookText.name_of_world(cause.subject, state)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
