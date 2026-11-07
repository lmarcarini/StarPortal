class_name DailySettlement
extends RefCounted
## The daily settlement at 00:00 (docs/content/m27-daily-rhythm.md sections 1 and 2), in the
## doc's order: pay the allocation from Confidence's whole part, charge today's costs with the
## carried remainder, record the balance, check the commendation, apply the drift (0.1 toward
## 50 while solvent, -0.2 in the red), then check the warnings (every 7 settlements in a row
## in the red; Confidence 0 once, re-armed above 10). Posts one budget_changed and
## confidence_changed; no Log line of its own. Warnings only: nothing ends the game or pauses.
## Called only from EconomySystem.on_day().
## Bible: docs/content/m27-daily-rhythm.md sections 1 and 2


## Settles the day on [param state] with [param base_allocation_k] (the daily allocation at
## Confidence 50) and [param costs_k] (rooms and salaries per 30 days).
static func settle(state: GameState, base_allocation_k: int, costs_k: int) -> void:
	var committee: CommitteeState = state.committee
	state.budget.funds_k += ConfidenceRules.daily_allocation_k(base_allocation_k, committee.whole())
	var charge: Vector2i = ConfidenceRules.daily_charge(costs_k, committee.cost_carry)
	state.budget.funds_k -= charge.x
	committee.cost_carry = charge.y
	committee.add_funds_record(state.budget.funds_k)
	ConfidenceEvents.check_commendation(state)
	var in_red: bool = state.budget.funds_k < 0
	committee.confidence = ConfidenceRules.changed(
		committee.confidence, ConfidenceRules.drift(committee.confidence, in_red)
	)
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"confidence_changed", [committee.confidence])
	_check_warnings(state, in_red)


static func _check_warnings(state: GameState, in_red: bool) -> void:
	var committee: CommitteeState = state.committee
	committee.days_in_red = committee.days_in_red + 1 if in_red else 0
	if in_red and committee.days_in_red % ConfidenceRules.RED_DAYS_WARNING == 0:
		state.events.post(&"committee_warning", [ConfidenceEvents.WARN_RED_DAYS])
	if committee.confidence > ConfidenceRules.ZERO_REARM_ABOVE:
		committee.zero_warned = false
	elif committee.confidence <= ConfidenceRules.MIN and not committee.zero_warned:
		committee.zero_warned = true
		state.events.post(&"committee_warning", [ConfidenceEvents.WARN_CONFIDENCE_ZERO])
