class_name MissionDefaults
extends RefCounted
## The mission sheet's starting choices for a world: its last plan when one was sent there,
## else the last team sent anywhere, with every empty or unfit slot (injured, away, gone)
## filled by the best free candidate of the slot's role. Pure.
## Bible: docs/content/interface-rethink.md sections 2 (The game remembers) and 4 (Teams)


## A draft for [param world] in [param state].
static func draft_for(state: GameState, world: StringName) -> ExpeditionPlanDraft:
	var draft: ExpeditionPlanDraft = ExpeditionPlanDraft.new()
	draft.world_id = world
	var memory: Dictionary = _memory(state, world)
	var objective: int = ExpeditionState.OBJECTIVE_NAMES.find(
		str(memory.get("objective", "survey"))
	)
	draft.objective = maxi(objective, ExpeditionState.Objective.SURVEY) as ExpeditionState.Objective
	if draft.objective == ExpeditionState.Objective.RECOVER:
		var targets: Array[WorldTarget] = ExpeditionPlanDraft.targets(state, world)
		if targets.is_empty():
			draft.objective = ExpeditionState.Objective.SURVEY
		else:
			draft.target_id = targets[0].id
	var team: Variant = memory.get("team", {})
	if team is Dictionary:
		var members: Dictionary = team
		for slot: String in ExpeditionState.SLOTS:
			if members.has(slot):
				draft.team[slot] = StringName(str(members[slot]))
	fill(state, draft)
	return draft


## Replaces every slot of [param draft] that is empty or unfit with the best fit candidate.
static func fill(state: GameState, draft: ExpeditionPlanDraft) -> void:
	for slot: String in ExpeditionState.SLOTS:
		var current_id: StringName = draft.team.get(slot, &"")
		var current: PersonState = state.staff.find_person(current_id)
		if current != null and is_fit(state, current, slot):
			continue
		var best: PersonState = best_for(state, slot, draft.team.values())
		if best != null:
			draft.team[slot] = best.id
		else:
			draft.team.erase(slot)


## True when [param person] can go in [param slot] now.
static func is_fit(state: GameState, person: PersonState, slot: String) -> bool:
	return (
		person.injury == PersonState.Injury.NONE
		and ExpeditionPlanDraft.candidates(state, slot).has(person)
	)


## The most skilled fit candidate for [param slot] not in [param taken], or null.
static func best_for(state: GameState, slot: String, taken: Array) -> PersonState:
	var best: PersonState = null
	for person: PersonState in ExpeditionPlanDraft.candidates(state, slot):
		if taken.has(person.id) or not is_fit(state, person, slot):
			continue
		if best == null or person.skill > best.skill:
			best = person
	return best


static func _memory(state: GameState, world: StringName) -> Dictionary:
	var plans: Dictionary[String, Dictionary] = state.expedition.last_plans
	if plans.has(String(world)):
		return plans[String(world)]
	var latest: Dictionary = {}
	for key: String in plans:
		latest = plans[key]
	return {"team": latest.get("team", {})}
