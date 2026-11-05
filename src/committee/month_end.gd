class_name MonthEnd
extends RefCounted
## The month-end of section 4, in the doc's order: pay the allocation, charge room upkeep and
## salaries, check Within budget or In the red, apply the Confidence change (capped at ±15),
## then in a quarter month the review and its grant. Writes a MonthReport, keeps it in
## state.committee and posts budget_changed, month_report_filed and any committee_warning.
## Bankruptcy and Confidence 0 only warn (owner, 2026-11-02). Called only from
## EconomySystem.on_month().
## Bible: docs/content/m26-staff-and-money.md sections 4, 5 and 8

## committee_warning reasons.
const WARN_RED_MONTHS: StringName = &"red_months"
const WARN_CONFIDENCE_ZERO: StringName = &"confidence_zero"


## Runs the month-end on [param state] with [param base_allocation_k] (the allocation at
## Confidence 50) and [param rooms_upkeep_k]; returns the report.
static func close(state: GameState, base_allocation_k: int, rooms_upkeep_k: int) -> MonthReport:
	var committee: CommitteeState = state.committee
	var report := MonthReport.blank()
	var date: Dictionary = TimeMath.date_of(state.clock.tick)
	report.year = date["year"]
	report.month = date["month"]
	report.confidence_before = committee.confidence
	report.allocation_k = ConfidenceRules.allocation_k(base_allocation_k, committee.confidence)
	report.upkeep_k = rooms_upkeep_k
	report.salaries_k = StaffRules.monthly_salaries_k(state)
	report.people = StaffRules.headcount(state)
	report.funds_before_k = state.budget.funds_k
	state.budget.funds_k += report.allocation_k - report.upkeep_k - report.salaries_k
	_count_causes(state, report)
	_apply_change(committee, report)
	_review(state, report)
	report.funds_after_k = state.budget.funds_k
	report.next_allocation_k = ConfidenceRules.allocation_k(base_allocation_k, committee.confidence)
	committee.add_report(report)
	_post(state, report)
	return report


static func _count_causes(state: GameState, report: MonthReport) -> void:
	var committee: CommitteeState = state.committee
	report.locked_worlds = ConfidenceRules.new_ids(
		ConfidenceRules.locked_worlds(state), committee.credited_locks
	)
	report.surveyed_worlds = ConfidenceRules.new_ids(
		ConfidenceRules.surveyed_worlds(state), committee.credited_surveys
	)
	var research: Array[StringName] = ConfidenceRules.new_ids(
		state.research.done, committee.credited_research
	)
	committee.credited_locks.append_array(report.locked_worlds)
	committee.credited_surveys.append_array(report.surveyed_worlds)
	committee.credited_research.append_array(research)
	_set_cause(report, &"locked", report.locked_worlds.size(), ConfidenceRules.LOCK)
	_set_cause(report, &"surveyed", report.surveyed_worlds.size(), ConfidenceRules.SURVEY)
	_set_cause(report, &"research", research.size(), ConfidenceRules.RESEARCH)
	_set_cause(
		report, &"reports", ConfidenceRules.reporting_analysts(state), ConfidenceRules.REPORT
	)
	var in_red: bool = state.budget.funds_k < 0
	_set_cause(report, &"in_red" if in_red else &"within_budget", 1, _budget_amount(in_red))
	committee.months_in_red = committee.months_in_red + 1 if in_red else 0
	report.months_in_red = committee.months_in_red
	var active: int = report.locked_worlds.size() + report.surveyed_worlds.size() + research.size()
	if active == 0:
		_set_cause(report, &"idle", 1, ConfidenceRules.IDLE)


static func _budget_amount(in_red: bool) -> int:
	return ConfidenceRules.IN_RED if in_red else ConfidenceRules.WITHIN_BUDGET


static func _set_cause(report: MonthReport, cause: StringName, count: int, each: int) -> void:
	if count <= 0:
		return
	var index: int = ConfidenceRules.CAUSES.find(cause)
	report.counts[index] = count
	report.amounts[index] = count * each


static func _apply_change(committee: CommitteeState, report: MonthReport) -> void:
	var total: int = 0
	for amount: int in report.amounts:
		total += amount
	var change: int = ConfidenceRules.capped(total)
	if change != total:
		report.amounts[ConfidenceRules.CAUSES.find(&"cap")] = change - total
	committee.confidence = ConfidenceRules.changed(committee.confidence, change)
	report.confidence_after = committee.confidence
	report.warn_confidence_zero = committee.confidence <= ConfidenceRules.MIN
	report.warn_red_months = committee.months_in_red >= ConfidenceRules.RED_MONTHS_WARNING


static func _review(state: GameState, report: MonthReport) -> void:
	if state.clock.tick <= 0 or not ConfidenceRules.is_review_month(report.month):
		return
	report.review = ConfidenceRules.review_of(report.confidence_after)
	report.grant_k = ConfidenceRules.grant_k(report.review)
	state.budget.credit(report.grant_k)


static func _post(state: GameState, report: MonthReport) -> void:
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"month_report_filed", [report.year, report.month])
	if report.warn_red_months:
		state.events.post(&"committee_warning", [WARN_RED_MONTHS])
	if report.warn_confidence_zero:
		state.events.post(&"committee_warning", [WARN_CONFIDENCE_ZERO])
