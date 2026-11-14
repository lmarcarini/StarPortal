class_name OutcomeSystem
extends SimSystem
## Tracks the failure states (M4c-14, FailureRules): each tick the Overrun count while
## intruders hold the Control Room; each day, after the settlement, the Confidence-0 and
## in-the-red counts with the Committee messages; and ends the game when a failure is
## complete. Counters reset the moment their condition clears. Nothing counts while the
## Failure states setting is off.
## Bible: docs/content/m4c-incursions.md section 8


## Returns the system id, &"outcome".
func get_id() -> StringName:
	return &"outcome"


## The Overrun count.
func tick(state: GameState) -> void:
	if not state.outcome.enabled or state.outcome.has_failed():
		return
	var held: bool = FailureRules.control_room_held(state)
	state.outcome.overrun_ticks = state.outcome.overrun_ticks + 1 if held else 0
	_end_if_failed(state)


## The daily counts and warnings.
func on_day(state: GameState) -> void:
	var outcome: OutcomeState = state.outcome
	if not outcome.enabled or outcome.has_failed():
		return
	var confidence: int = ConfidenceRules.whole(state.committee.confidence)
	outcome.zero_confidence_days = outcome.zero_confidence_days + 1 if confidence <= 0 else 0
	outcome.negative_funds_days = (
		outcome.negative_funds_days + 1 if state.budget.funds_k < 0 else 0
	)
	for reason: StringName in FailureRules.CONFIDENCE_WARNINGS:
		_warn_once(state, reason, confidence <= FailureRules.CONFIDENCE_WARNINGS[reason])
	var balance: BalanceConfig = state.balance
	_warn_once(state, &"would_close", outcome.zero_confidence_days >= balance.shutdown_days)
	_warn_once(state, &"would_bankrupt", outcome.negative_funds_days >= balance.bankruptcy_days)
	_end_if_failed(state)


# Posts committee_warning(reason) the first time [param now] holds; re-arms when it stops.
static func _warn_once(state: GameState, reason: StringName, now: bool) -> void:
	var warned: Array[StringName] = state.outcome.warned
	if not now:
		warned.erase(reason)
	elif not warned.has(reason):
		warned.append(reason)
		state.events.post(&"committee_warning", [reason])


static func _end_if_failed(state: GameState) -> void:
	var cause: StringName = FailureRules.check(state)
	if not cause.is_empty():
		FailureRules.fail(state, cause)
