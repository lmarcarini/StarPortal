class_name ConfidenceEvents
extends RefCounted
## Confidence events, applied at once (docs/content/m27-daily-rhythm.md section 2): a new world
## locked (+5), a horizon record taken (+2), a research project finished (+3) and reports filed
## (+1 per analyst every 15th day); a team's survey of a new world (+3,
## docs/content/m3-beyond-the-ring.md section 4) raises its own cause through [method raise].
## Each adds a cause to the rolling list, posts confidence_changed and checks the commendation:
## $1,000k the first time Confidence reaches 70, re-armed below 60. Called only from
## EconomySystem, DailySettlement and ExpeditionSystem (through ExpeditionReturns).
## Bible: docs/content/m27-daily-rhythm.md section 2

## committee_warning reasons.
const WARN_RED_DAYS: StringName = &"red_days"
const WARN_CONFIDENCE_ZERO: StringName = &"confidence_zero"


## Credits every lock, survey and finished project in [param state] that has not counted yet,
## in that order and in id order within each.
static func credit_new(state: GameState) -> void:
	var committee: CommitteeState = state.committee
	var locks: Array[StringName] = ConfidenceRules.new_ids(
		ConfidenceRules.locked_worlds(state), committee.credited_locks
	)
	_credit_all(state, ConfidenceRules.LOCKED, locks, committee.credited_locks)
	if state.worlds.horizon_records.size() > committee.credited_surveys.size():
		var surveys: Array[StringName] = ConfidenceRules.new_ids(
			ConfidenceRules.surveyed_worlds(state), committee.credited_surveys
		)
		_credit_all(state, ConfidenceRules.HORIZON_RECORD, surveys, committee.credited_surveys)
	if state.research.done.size() > committee.credited_research.size():
		var projects: Array[StringName] = ConfidenceRules.new_ids(
			state.research.done, committee.credited_research
		)
		_credit_all(state, ConfidenceRules.RESEARCH, projects, committee.credited_research)


## Files the reports of every analyst in an active Control Room (+1 each); nothing without
## analysts. Posts reports_filed.
static func file_reports(state: GameState) -> void:
	var analysts: int = ConfidenceRules.reporting_analysts(state)
	if analysts <= 0:
		return
	var amounts := Vector2i(analysts, analysts * ConfidenceRules.REPORT_CHANGE)
	raise(state, ConfidenceRules.REPORTS, &"", amounts)
	state.events.post(&"reports_filed", [analysts])


## Changes Confidence for [param cause] about [param subject]; [param amounts] x is the count
## and y the change in tenths. Adds the cause, posts confidence_changed and checks the
## commendation.
static func raise(
	state: GameState, cause: StringName, subject: StringName, amounts: Vector2i
) -> void:
	var committee: CommitteeState = state.committee
	committee.confidence = ConfidenceRules.changed(committee.confidence, amounts.y)
	committee.add_cause(ConfidenceCause.create(state.clock.tick, cause, subject, amounts))
	state.events.post(&"confidence_changed", [committee.confidence])
	if check_commendation(state):
		state.events.post(&"budget_changed", [state.budget.funds_k])


## Pays the commendation the first time Confidence reaches 70 (posting
## committee_commendation; true when paid) and re-arms it below 60.
static func check_commendation(state: GameState) -> bool:
	var committee: CommitteeState = state.committee
	if committee.commendation_paid:
		if committee.confidence < ConfidenceRules.COMMENDATION_REARM_BELOW:
			committee.commendation_paid = false
		return false
	if committee.confidence < ConfidenceRules.COMMENDATION_AT:
		return false
	committee.commendation_paid = true
	state.budget.credit(ConfidenceRules.COMMENDATION_K)
	state.events.post(&"committee_commendation", [ConfidenceRules.COMMENDATION_K])
	return true


static func _credit_all(
	state: GameState, cause: StringName, ids: Array[StringName], credited: Array[StringName]
) -> void:
	for id: StringName in ids:
		credited.append(id)
		raise(state, cause, id, Vector2i(1, _change_of(cause)))


static func _change_of(cause: StringName) -> int:
	match cause:
		ConfidenceRules.LOCKED:
			return ConfidenceRules.LOCK_CHANGE
		ConfidenceRules.HORIZON_RECORD:
			return ConfidenceRules.HORIZON_CHANGE
		ConfidenceRules.RESEARCH:
			return ConfidenceRules.RESEARCH_CHANGE
	return ConfidenceRules.REPORT_CHANGE
