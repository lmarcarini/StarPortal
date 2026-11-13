class_name ExpeditionRules
extends RefCounted
## Pure rules of planning and sending a team (docs/content/m3-beyond-the-ring.md section 4):
## who may fill each slot, what each objective needs, and the 10-minute margin of open time a
## departure needs on the wormhole's charge and on its time limit. No side effects.
## Bible: docs/content/m3-beyond-the-ring.md section 4 (The team, Objectives, Departure)

## Refusals.
const LOCKED: StringName = &"expeditions_locked"
const BUSY: StringName = &"expedition_away"
const UNKNOWN_OBJECTIVE: StringName = &"unknown_objective"
const NOT_PROBED: StringName = &"world_not_probed"
const NOT_RECOVERABLE: StringName = &"target_not_recoverable"
const TEAM_INCOMPLETE: StringName = &"team_incomplete"
const DUPLICATE_MEMBER: StringName = &"duplicate_member"
const WRONG_ROLE: StringName = &"wrong_role"
const MEMBER_INJURED: StringName = &"member_injured"
const NO_PLAN: StringName = &"no_plan"
const NO_WORMHOLE: StringName = &"no_wormhole"
const WRONG_WORLD: StringName = &"wrong_world"
const NOT_ENOUGH_TIME: StringName = &"not_enough_open_time"
## Translation key of the reason shown when the wormhole has too little open time left:
## "Not enough open time to send a team (10 minutes needed)."
const NOT_ENOUGH_TIME_TEXT: String = "EXPEDITION_NOT_ENOUGH_TIME"
## Minutes (ticks) of open time a departure needs.
const MARGIN_TICKS: int = 10
## Roles each slot takes; an empty list takes anyone.
static var slot_roles: Dictionary[String, Array] = {
	"leader": [],
	"scientist": [StartingStaff.SCIENTIST],
	"soldier": [StartingStaff.SOLDIER],
	"specialist":
	[StartingStaff.MEDIC, StartingStaff.ENGINEER, StartingStaff.ANALYST, StartingStaff.SCIENTIST],
}


## Why [param plan]'s objective, world and target with [param team] (slot -> person id)
## cannot be planned in [param state], or &"": Expeditions unlocked, no team away.
static func plan_error(state: GameState, plan: ExpeditionState, team: Dictionary) -> StringName:
	if not ExpeditionUnlock.is_unlocked(state):
		return LOCKED
	if state.expedition.is_out():
		return BUSY
	var error: StringName = objective_error(state, plan)
	if not error.is_empty():
		return error
	return team_error(state, team)


## Why the objective of [param plan] cannot be done now in [param state], or &"".
static func objective_error(state: GameState, plan: ExpeditionState) -> StringName:
	match plan.objective:
		ExpeditionState.Objective.SURVEY:
			if not state.worlds.has_reached(plan.world_id, WorldsState.WorldStatus.PROBED):
				return NOT_PROBED
		ExpeditionState.Objective.RECOVER:
			if not state.worlds.targets.is_recoverable(plan.world_id, plan.target_id):
				return NOT_RECOVERABLE
		_:
			return UNKNOWN_OBJECTIVE
	return &""


## Why [param team] (slot -> person id) cannot go in [param state], or &"": every slot filled
## by a different person, on base, well, of a role the slot takes.
static func team_error(state: GameState, team: Dictionary) -> StringName:
	var seen: Array[StringName] = []
	for slot: String in ExpeditionState.SLOTS:
		var person_id := StringName(str(team.get(slot, "")))
		if person_id.is_empty():
			return TEAM_INCOMPLETE
		if person_id in seen:
			return DUPLICATE_MEMBER
		seen.append(person_id)
		var person: PersonState = state.staff.find_person(person_id)
		if person == null:
			return StaffRules.UNKNOWN_PERSON
		if not person.is_on_base(state.clock.tick):
			return StaffRules.NOT_ON_BASE
		if person.is_injured():
			return MEMBER_INJURED
		var roles: Array = slot_roles[slot]
		if not roles.is_empty() and not person.role in roles:
			return WRONG_ROLE
	return &""


## Why the planned team cannot go through now in [param state], or &"": a plan ready, the
## wormhole open to its world with MARGIN_TICKS of open time left, and the plan still valid.
static func send_error(state: GameState) -> StringName:
	var plan: ExpeditionState = state.expedition
	if plan.mode != ExpeditionState.Mode.PLANNED:
		return NO_PLAN
	if state.gate.mode != GateState.RingMode.LOCKED:
		return NO_WORMHOLE
	if state.gate.connected_world_id != plan.world_id:
		return WRONG_WORLD
	if open_ticks_left(state) < MARGIN_TICKS:
		return NOT_ENOUGH_TIME
	return plan_error(state, plan, plan.team)


## Ticks the open wormhole could still stay open in [param state]: the lesser of its time
## limit and its charge (stored energy against the drain less live charging); 0 unless open.
static func open_ticks_left(state: GameState) -> int:
	var by_time: int = GateQueries.open_ticks_left(state)
	if by_time <= 0:
		return 0
	var net_mw: float = PowerRules.charge_mw(state) - PowerRules.drain_mw(state)
	if net_mw >= 0.0:
		return by_time
	var by_charge: int = floori(state.power.stored_mwh / (-net_mw / PowerMath.TICKS_PER_HOUR))
	return mini(by_time, by_charge)
