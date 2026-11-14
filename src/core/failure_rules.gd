class_name FailureRules
extends RefCounted
## Losing the game, pure (M4c-14). Overrun: intruders alone in the Control Room for
## overrun_ticks ticks in a row ends the game. Shutdown (Confidence 0 at shutdown_days daily
## settlements in a row) and Bankruptcy (funds below zero at bankruptcy_days in a row) are
## counted and warned about; they end the game only when their balance flag is on (both off:
## owner decision 2026-11-14). Nothing counts while the Failure states setting is off.
## Bible: docs/content/m4c-incursions.md section 8

## Causes.
const OVERRUN: StringName = &"overrun"
const SHUTDOWN: StringName = &"shutdown"
const BANKRUPTCY: StringName = &"bankruptcy"
## Days in the red from which the Bankruptcy countdown alert shows.
const BANKRUPTCY_ALERT_FROM: int = 15
## Confidence levels (whole points) that bring a Committee message.
const CONFIDENCE_WARNINGS: Dictionary[StringName, int] = {
	&"confidence_20": 20, &"confidence_10": 10
}


## The cause that ends the game now, or &"": overrun, or shutdown / bankruptcy when their
## flags are on and their counts are complete.
static func check(state: GameState) -> StringName:
	var outcome: OutcomeState = state.outcome
	var balance: BalanceConfig = state.balance
	if outcome.overrun_ticks >= balance.overrun_ticks:
		return OVERRUN
	if balance.shutdown_ends_game and outcome.zero_confidence_days >= balance.shutdown_days:
		return SHUTDOWN
	if balance.bankruptcy_ends_game and outcome.negative_funds_days >= balance.bankruptcy_days:
		return BANKRUPTCY
	return &""


## Ends the game of [param state] with [param cause]; posts game_failed once.
static func fail(state: GameState, cause: StringName) -> void:
	if state.outcome.has_failed():
		return
	state.outcome.status = OutcomeState.Status.FAILED
	state.outcome.cause = cause
	state.outcome.tick = state.clock.tick
	state.events.post(&"game_failed", [cause])


## True when intruders stand in the Control Room of [param state] and no squad does. A base
## with no Control Room cannot be overrun.
static func control_room_held(state: GameState) -> bool:
	if not state.incursion.is_active():
		return false
	var control: StringName = ObjectiveRules.target_room(state, &"assault")
	if control.is_empty() or IntruderRules.contested(state, control):
		return false
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	for group: IntruderGroup in state.incursion.groups:
		var room: RoomState = cells.get(group.pos())
		if room != null and room.id == control and not group.standing().is_empty():
			return true
	return false


## Ticks left before an Overrun, for the alarm strip; −1 when the Control Room is not held.
static func overrun_left(state: GameState) -> int:
	if state.outcome.overrun_ticks <= 0:
		return -1
	return maxi(0, state.balance.overrun_ticks - state.outcome.overrun_ticks)


## Days left before Shutdown would come, or −1 when the count has not started.
static func shutdown_left(state: GameState) -> int:
	var days: int = state.outcome.zero_confidence_days
	return -1 if days <= 0 else maxi(0, state.balance.shutdown_days - days)


## Days left before Bankruptcy would come, or −1 before day BANKRUPTCY_ALERT_FROM in the red.
static func bankruptcy_left(state: GameState) -> int:
	var days: int = state.outcome.negative_funds_days
	if days < BANKRUPTCY_ALERT_FROM:
		return -1
	return maxi(0, state.balance.bankruptcy_days - days)
