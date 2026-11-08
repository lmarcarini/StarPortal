class_name ExpeditionSystem
extends SimSystem
## Runs the team away each tick, after ProbeSystem (docs/content/m3-beyond-the-ring.md section
## 4): every 24 hours from departure a field day ends (ExpeditionFieldDay) at its check-in, and
## the last one is the return, at departure plus the objective's days. On return the team brings
## back what ExpeditionReturns gives and goes back to the rooms it kept; the plan clears.
## Check-in messages, recall and rescue (card M3-10) hook into [method _check_in].
## Events: team_returned(world id, objective, success).
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Id of the system and of its random stream.
const ID: StringName = &"expedition"
## Event posted when the team comes home.
const RETURNED_EVENT: StringName = &"team_returned"


## Returns &"expedition".
func get_id() -> StringName:
	return ID


## Ends the field day due by now, then returns the team after its last.
func tick(state: GameState) -> void:
	var plan: ExpeditionState = state.expedition
	if plan.mode != ExpeditionState.Mode.AWAY or state.clock.tick < plan.next_day_end_tick():
		return
	var rng: RandomNumberGenerator = state.random.stream(ID)
	plan.day_results.append(ExpeditionFieldDay.resolve(state, plan.day_results.size(), rng))
	if plan.day_results.size() < plan.days():
		_check_in(state)
		return
	_return(state, rng)


## A check-in that is not the return. Card M3-10 posts its message here.
func _check_in(_state: GameState) -> void:
	return


func _return(state: GameState, rng: RandomNumberGenerator) -> void:
	var plan: ExpeditionState = state.expedition
	var world_id: StringName = plan.world_id
	var objective: int = plan.objective
	var success: bool = ExpeditionReturns.apply(state, rng)
	plan.clear()
	state.events.post(RETURNED_EVENT, [world_id, objective, success])
