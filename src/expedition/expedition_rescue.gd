class_name ExpeditionRescue
extends RefCounted
## A missed check-in and the rescue (docs/content/m3-beyond-the-ring.md section 4, Missed
## check-in and rescue; A rescue is not a sure thing, owner 2026-11-07), run by
## ExpeditionSystem. A missed check-in pauses the game (pause_requested), sets the speed to
## 1× for when it resumes and opens a WINDOW_DAYS window. Signal T-1 on a wormhole open to the
## world brings the team to the Ring SIGNAL_TICKS later; closing it before fails the Signal.
## On arrival each member rolls to have survived (SurvivalRules): the deceased leave the
## roster (Confidence -3 each), the rest come home; if nobody survived there is no answer and
## the team is lost, as when the window runs out (all four leave, Confidence -10). Lost
## people go through ExpeditionUnlock.lose_person (lent soldiers are replaced). Call only
## from SimSystem.tick(). Events: check_in_missed(world id), rescue_signal_failed(world id),
## member_deceased(name, world id), team_rescued(world id, survivors), team_lost(world id,
## reason).
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Days the rescue window stays open.
const WINDOW_DAYS: int = 3
## Minutes (ticks) from the Signal until the team reaches the Ring.
const SIGNAL_TICKS: int = 15
## Why a team is lost: the window ran out, or nobody answered the Signal.
const LOST_WINDOW: StringName = &"window"
const LOST_NO_ANSWER: StringName = &"no_answer"
## Reason of the pause a missed check-in asks for (the clock pauses through SimClock).
const PAUSE_REASON: StringName = &"check_in_missed"


## The tick [param plan]'s rescue window closes at.
static func window_end_tick(plan: ExpeditionState) -> int:
	return plan.missed_tick + WINDOW_DAYS * TimeMath.TICKS_PER_DAY


## The team of [param state] missed the check-in due now: the rescue window opens, the game
## pauses and its speed is set to 1× for when it resumes.
static func miss(state: GameState) -> void:
	var plan: ExpeditionState = state.expedition
	plan.mode = ExpeditionState.Mode.MISSING
	plan.recalled = false
	plan.missed_tick = state.clock.tick
	plan.signal_tick = -1
	state.clock.speed_index = ClockState.NORMAL_SPEED_INDEX
	state.events.post(&"check_in_missed", [plan.world_id])
	state.events.post(Simulation.PAUSE_EVENT, [PAUSE_REASON])


## One tick of an open rescue window in [param state]: a waiting Signal fails if the wormhole
## to the world closed and brings the team to the Ring once due; with no Signal waiting, the
## window running out loses the team. [param rng] is the expedition's seeded generator.
static func tick(state: GameState, rng: RandomNumberGenerator) -> void:
	var plan: ExpeditionState = state.expedition
	if plan.signal_tick < 0:
		if state.clock.tick >= window_end_tick(plan):
			lose_team(state, LOST_WINDOW)
		return
	if not is_open_to_team(state):
		plan.signal_tick = -1
		state.events.post(&"rescue_signal_failed", [plan.world_id])
		return
	if state.clock.tick >= plan.signal_tick + SIGNAL_TICKS:
		_arrive(state, rng)


## True when [param state]'s wormhole is open to the missing team's world.
static func is_open_to_team(state: GameState) -> bool:
	return (
		state.gate.mode == GateState.RingMode.LOCKED
		and state.gate.connected_world_id == state.expedition.world_id
	)


## Loses the whole team of [param state] for [param reason]: all four leave the roster,
## Confidence -10, team_lost is posted and the plan clears.
static func lose_team(state: GameState, reason: StringName) -> void:
	var plan: ExpeditionState = state.expedition
	var world_id: StringName = plan.world_id
	for person_id: StringName in plan.member_ids():
		ExpeditionUnlock.lose_person(state, person_id)
	ConfidenceEvents.raise(
		state, ConfidenceRules.TEAM_LOST, world_id, Vector2i(1, ConfidenceRules.TEAM_LOST_CHANGE)
	)
	plan.clear()
	state.events.post(&"team_lost", [world_id, reason])


## The team reaches the Ring: survival rolls, then the deceased leave and the rest come home.
static func _arrive(state: GameState, rng: RandomNumberGenerator) -> void:
	var plan: ExpeditionState = state.expedition
	var members: Array[PersonState] = []
	for person_id: StringName in plan.member_ids():
		var person: PersonState = state.staff.find_person(person_id)
		if person != null:
			members.append(person)
	var days: int = (state.clock.tick - plan.missed_tick) / TimeMath.TICKS_PER_DAY
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, plan.world_id)
	if facts == null:
		facts = WorldFacts.new()
	var deceased: Array[StringName] = SurvivalRules.roll(members, facts, days, rng)
	if deceased.size() >= members.size():
		lose_team(state, LOST_NO_ANSWER)
		return
	var world_id: StringName = plan.world_id
	for person_id: StringName in deceased:
		state.events.post(&"member_deceased", [state.staff.find_person(person_id).name, world_id])
		ExpeditionUnlock.lose_person(state, person_id)
	if not deceased.is_empty():
		var change: int = ConfidenceRules.DECEASED_CHANGE * deceased.size()
		ConfidenceEvents.raise(
			state, ConfidenceRules.DECEASED, world_id, Vector2i(deceased.size(), change)
		)
	plan.clear()
	state.events.post(&"team_rescued", [world_id, members.size() - deceased.size()])
