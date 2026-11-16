class_name ExpeditionSystem
extends SimSystem
## Runs the team away each tick, after GateSystem and ProbeSystem
## (docs/content/m3-beyond-the-ring.md section 4): every 24 hours from departure a field day
## ends (ExpeditionFieldDay), silently: a team talks to the base only through an open gate
## (TeamContactRules, interface-rethink.md section 4). The last day is the return, at departure
## plus the objective's days; Recall team or Come home now makes the return come at once. A day
## due while CAIRN's wormhole is open comes when it closes. A day whose result is
## ExpeditionState.DAY_MISSED (a field event's worst setback) leaves the team in trouble: it
## calls the base (ExpeditionRescue.miss) and the rescue window runs until it is home or lost. On
## return the team brings back what ExpeditionReturns gives (nothing when recalled before its
## last day) and goes back to the rooms it kept; the plan clears.
## Events: team_sent (SendTeamCommand) and team_returned(world id, objective, success,
## team names), prologue_completed(world id) once at the first return (section 1), and
## ExpeditionRescue's.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Id of the system and of its random stream.
const ID: StringName = &"expedition"
## Event posted when the team comes home.
const RETURNED_EVENT: StringName = &"team_returned"
## Event posted once, at the first team's first return home (not a rescue): the Prologue ends.
const PROLOGUE_EVENT: StringName = &"prologue_completed"
## Flag set (true) once the Prologue has ended.
const PROLOGUE_FLAG: StringName = &"prologue_complete"

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
	if plan.mode == ExpeditionState.Mode.AWAY and plan.coming_home:
		_return(state, state.random.stream(ID))
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
	elif plan.day_results.size() >= plan.days() or plan.recalled:
		_return(state, rng)


func _return(state: GameState, rng: RandomNumberGenerator) -> void:
	var plan: ExpeditionState = state.expedition
	var world_id: StringName = plan.world_id
	var objective: int = plan.objective
	var team: Array[String] = team_names(state)
	var success: bool = false
	if plan.day_results.size() >= plan.days():
		success = ExpeditionReturns.apply(state, rng)
	var early: bool = plan.coming_home
	var days: int = plan.day_results.size()
	plan.clear()
	TeamContactRules.open_return(state, world_id)
	state.events.post(RETURNED_EVENT, [world_id, objective, success, team])
	var summary: Dictionary = {
		"objective": objective, "success": success, "early": early, "team": team, "days": days
	}
	state.events.post(&"team_debrief", [world_id, summary])
	if state.flags.get(PROLOGUE_FLAG, false) != true:
		state.flags[PROLOGUE_FLAG] = true
		state.events.post(PROLOGUE_EVENT, [world_id])


## The names of [param state]'s team in slot order (people no longer on the roster skipped).
static func team_names(state: GameState) -> Array[String]:
	var names: Array[String] = []
	for person_id: StringName in state.expedition.member_ids():
		var person: PersonState = state.staff.find_person(person_id)
		if person != null:
			names.append(person.name)
	return names


## (light, serious) injuries among [param state]'s team.
static func injuries(state: GameState) -> Vector2i:
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
