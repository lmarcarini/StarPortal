class_name MonthReportText
extends RefCounted
## Words a MonthReport (docs/content/m26-staff-and-money.md section 5) line by line, in the
## current locale: the Log's month-end entry, and the month-end message and report window.
## Reads state only to name worlds.
## Bible: docs/content/m26-staff-and-money.md sections 4 and 5

## Line key of each cause, in ConfidenceRules.CAUSES order.
const CAUSE_KEYS: Dictionary[StringName, StringName] = {
	&"locked": &"MONTH_CAUSE_LOCKED",
	&"surveyed": &"MONTH_CAUSE_SURVEYED",
	&"research": &"MONTH_CAUSE_RESEARCH",
	&"reports": &"MONTH_CAUSE_REPORTS",
	&"within_budget": &"MONTH_CAUSE_WITHIN_BUDGET",
	&"in_red": &"MONTH_CAUSE_IN_RED",
	&"idle": &"MONTH_CAUSE_IDLE",
	&"cap": &"MONTH_CAUSE_CAP",
	&"bounds": &"MONTH_CAUSE_BOUNDS",
}
## Line key of each review.
const REVIEW_KEYS: Dictionary[StringName, StringName] = {
	&"pleased": &"MONTH_REVIEW_PLEASED",
	&"notes": &"MONTH_REVIEW_NOTES",
	&"questions": &"MONTH_REVIEW_QUESTIONS",
}
## Line key of each committee_warning reason.
const WARNING_KEYS: Dictionary[StringName, StringName] = {
	&"red_months": &"COMMITTEE_WARN_RED_MONTHS",
	&"confidence_zero": &"COMMITTEE_WARN_CONFIDENCE_ZERO",
}


## The message line: "Month-end report: Confidence 50 to 65".
static func headline(report: MonthReport) -> String:
	return _tr(&"MONTH_REPORT_TITLE").format(
		{"before": report.confidence_before, "after": report.confidence_after}
	)


## Every line of [param report], in the doc's order: headline, money, Confidence and its
## causes, the review, months in the red (when any) and the next allocation. Worlds are named
## from [param state] (may be null: ids are shown).
static func lines(report: MonthReport, state: GameState) -> PackedStringArray:
	var out: PackedStringArray = [headline(report)]
	out.append_array(money_lines(report))
	out.append(
		_tr(&"MONTH_REPORT_CONFIDENCE").format(
			{"before": report.confidence_before, "after": report.confidence_after}
		)
	)
	for cause: StringName in report.applied_causes():
		out.append(cause_line(report, cause, state))
	if not report.review.is_empty():
		out.append(review_line(report))
	if report.months_in_red > 0:
		out.append(
			_tr(&"MONTH_REPORT_RED_MONTHS").format(
				{"count": report.months_in_red, "limit": ConfidenceRules.RED_MONTHS_WARNING}
			)
		)
	out.append(
		_tr(&"MONTH_REPORT_NEXT").format({"amount": MoneyLabel.format_k(report.next_allocation_k)})
	)
	return out


## Allocation, room upkeep, salaries and balance lines.
static func money_lines(report: MonthReport) -> PackedStringArray:
	var salaries_key: StringName = &"MONTH_REPORT_SALARIES"
	if report.people == 1:
		salaries_key = &"MONTH_REPORT_SALARIES_ONE"
	return [
		_tr(&"MONTH_REPORT_ALLOCATION").format({"amount": _signed_k(report.allocation_k)}),
		_tr(&"MONTH_REPORT_UPKEEP").format({"amount": _signed_k(-report.upkeep_k)}),
		_tr(salaries_key).format(
			{"people": report.people, "amount": _signed_k(-report.salaries_k)}
		),
		(
			_tr(&"MONTH_REPORT_BALANCE")
			. format(
				{
					"before": MoneyLabel.format_k(report.funds_before_k),
					"after": MoneyLabel.format_k(report.funds_after_k),
				}
			)
		),
	]


## The line of [param cause] in [param report], e.g. "New world locked: SILL  +5".
static func cause_line(report: MonthReport, cause: StringName, state: GameState) -> String:
	var worlds: Array[StringName] = []
	if cause == &"locked":
		worlds = report.locked_worlds
	elif cause == &"surveyed":
		worlds = report.surveyed_worlds
	var names: PackedStringArray = []
	for world_id: StringName in worlds:
		names.append(_world_name(world_id, state))
	var key: StringName = CAUSE_KEYS.get(cause, &"")
	if cause == &"reports" and report.count_of(cause) == 1:
		key = &"MONTH_CAUSE_REPORTS_ONE"
	return (
		_tr(key)
		. format(
			{
				"worlds": ", ".join(names),
				"count": report.count_of(cause),
				"limit": signed(ConfidenceRules.MONTHLY_CAP * signi(-report.amount_of(cause))),
				"amount": signed(report.amount_of(cause)),
			}
		)
	)


## The quarterly review line, with the grant when there is one.
static func review_line(report: MonthReport) -> String:
	var key: StringName = REVIEW_KEYS.get(report.review, &"MONTH_REVIEW_NOTES")
	return _tr(key).format({"amount": _signed_k(report.grant_k)})


## The line of a committee_warning [param reason] with [param months_in_red].
static func warning_line(reason: StringName, months_in_red: int) -> String:
	var key: StringName = WARNING_KEYS.get(reason, &"COMMITTEE_WARN_CONFIDENCE_ZERO")
	return _tr(key).format({"count": months_in_red})


## [param amount] with its sign: "+5", "-4", "0".
static func signed(amount: int) -> String:
	return "+%d" % amount if amount > 0 else str(amount)


static func _signed_k(amount_k: int) -> String:
	return ("+" if amount_k > 0 else "") + MoneyLabel.format_k(amount_k)


static func _world_name(world_id: StringName, state: GameState) -> String:
	if state == null:
		return String(world_id)
	return AddressBookText.name_of_world(world_id, state)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
