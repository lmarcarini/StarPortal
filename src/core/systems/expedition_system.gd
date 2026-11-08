class_name ExpeditionSystem
extends SimSystem
## Runs the team away each tick, after GateSystem and ProbeSystem
## (docs/content/m3-beyond-the-ring.md section 4): every 24 hours from departure a field day
## ends (ExpeditionFieldDay) at its check-in, and the last one is the return, at departure plus
## the objective's days; Recall team makes the next check-in the return. A check-in that falls
## due while CAIRN's wormhole is open comes when it closes. A day whose result is
## ExpeditionState.DAY_MISSED (a field event's worst setback, card M3-11) is a missed check-in:
## ExpeditionRescue opens the rescue window and runs it until the team is home or lost. On
## return the team brings back what ExpeditionReturns gives (nothing when recalled before its
## last day) and goes back to the rooms it kept; the plan clears.
## Events: team_checked_in(world id, light injuries, serious injuries), team_returned(world id,
## objective, success), and ExpeditionRescue's.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Id of the system and of its random stream.
const ID: StringName = &"expedition"
## Event posted when the team comes home.
const RETURNED_EVENT: StringName = &"team_returned"
## Event posted at a check-in that is not the return.
const CHECKED_IN_EVENT: StringName = &"team_checked_in"

## Resolves a field day: (state, day, rng) -> an ExpeditionState.DAY_RESULTS entry. Tests may
## replace it; the game uses ExpeditionFieldDay.resolve.
var resolve_day: Callable = ExpeditionFieldDay.resolve


## Returns &"expedition".
func get_id() -> StringName:
	return ID


## Runs the rescue window, or ends the field day due by now (once CAIRN's wormhole is closed),
## then checks in, returns the team, or misses the check-in.
func tick(state: GameState) -> void:
	var plan: ExpeditionState = state.expedition
	if plan.mode == ExpeditionState.Mode.MISSING:
		ExpeditionRescue.tick(state, state.random.stream(ID))
		return
	if plan.mode != ExpeditionState.Mode.AWAY or state.clock.tick < plan.next_day_end_tick():
		return
	if state.gate.mode == GateState.RingMode.LOCKED:
		return
	var rng: RandomNumberGenerator = state.random.stream(ID)
	var result: String = resolve_day.call(state, plan.day_results.size(), rng)
	plan.day_results.append(result)
	if result == ExpeditionState.DAY_MISSED:
		ExpeditionRescue.miss(state)
	elif plan.day_results.size() < plan.days() and not plan.recalled:
		_check_in(state)
	else:
		_return(state, rng)


## A check-in that is not the return: a Log line and a non-blocking message with the team's
## injuries; no pause, no speed change.
func _check_in(state: GameState) -> void:
	var counts: Vector2i = _injuries(state)
	state.events.post(CHECKED_IN_EVENT, [state.expedition.world_id, counts.x, counts.y])


func _return(state: GameState, rng: RandomNumberGenerator) -> void:
	var plan: ExpeditionState = state.expedition
	var world_id: StringName = plan.world_id
	var objective: int = plan.objective
	var success: bool = false
	if plan.day_results.size() >= plan.days():
		success = ExpeditionReturns.apply(state, rng)
	plan.clear()
	state.events.post(RETURNED_EVENT, [world_id, objective, success])


## (light, serious) injuries among [param state]'s team.
static func _injuries(state: GameState) -> Vector2i:
	var counts := Vector2i.ZERO
	for person_id: StringName in state.expedition.member_ids():
		var person: PersonState = state.staff.find_person(person_id)
		if person == null:
			continue
		if person.injury == PersonState.Injury.LIGHT:
			counts.x += 1
		elif person.injury == PersonState.Injury.SERIOUS:
			counts.y += 1
	return counts
