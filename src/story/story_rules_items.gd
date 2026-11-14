class_name StoryRulesItems
extends RefCounted
## The story effects that create or change saved items: request offers, artefacts arriving,
## handed over and studied, and research revealed or completed. Called only by
## StoryRules.apply(). Housing and the request lifecycle come in later cards; here the items are
## only recorded.
## Bible: docs/content/m4-core-systems.md sections 1, 4 and 5


## Applies an item effect; false for an effect this class does not handle or that cannot apply.
static func apply(state: GameState, effect: EffectDef) -> bool:
	if effect is StartIncursionEffect:
		return IncursionRules.start(state, (effect as StartIncursionEffect).incursion).is_ok
	if effect is OfferRequestEffect:
		return offer_request(state, (effect as OfferRequestEffect).request) >= 0
	if effect is GiveArtefactEffect:
		return give_artefact(state, (effect as GiveArtefactEffect).artefact) >= 0
	if effect is TakeArtefactEffect:
		return _take_artefact(state, (effect as TakeArtefactEffect).artefact)
	if effect is StudyArtefactEffect:
		return _study_artefact(state, (effect as StudyArtefactEffect).artefact)
	if effect is UnlockResearchEffect:
		return _reveal(state, (effect as UnlockResearchEffect).project)
	if effect is CompleteResearchEffect:
		return _complete(state, (effect as CompleteResearchEffect).project)
	return false


## Appends an OFFERED instance of [param request] and posts request_offered. While offered,
## deadline_tick holds the tick the offer lapses (offered + offer_days); acceptance (M4-15)
## replaces it with the real deadline. Returns the uid, or −1 for an unknown request or one
## with an instance still open (OFFERED or ACTIVE).
static func offer_request(state: GameState, request: StringName) -> int:
	var def: RequestDef = state.request_defs.get(request)
	if def == null or RequestRules.open_instance(state, request) != null:
		return -1
	var record := RequestRecord.new()
	record.uid = state.requests.next_uid
	state.requests.next_uid += 1
	record.request = request
	record.offered_tick = state.clock.tick
	record.deadline_tick = state.clock.tick + def.offer_days * TimeMath.TICKS_PER_DAY
	state.requests.items.append(record)
	state.events.post(&"request_offered", [record.uid])
	return record.uid


## Appends a RECOVERED [param artefact] in Gate Room holding (waiting at the gate when holding
## is full) and posts artefact_arrived.
## Returns the uid, or −1 for an empty id.
static func give_artefact(state: GameState, artefact: StringName) -> int:
	if artefact.is_empty():
		return -1
	var record := ArtefactRecord.new()
	record.uid = state.artefacts.next_uid
	state.artefacts.next_uid += 1
	record.artefact = artefact
	record.arrived_tick = state.clock.tick
	if ArtefactRules.holding(state).size() >= ArtefactRules.capacity(state):
		record.room_uid = ArtefactRecord.AT_GATE
	state.artefacts.items.append(record)
	state.events.post(&"artefact_arrived", [record.uid])
	return record.uid


static func _take_artefact(state: GameState, artefact: StringName) -> bool:
	for index: int in state.artefacts.items.size():
		if state.artefacts.items[index].artefact == artefact:
			state.artefacts.items.remove_at(index)
			state.events.post(&"artefact_taken", [artefact])
			return true
	return false


static func _study_artefact(state: GameState, artefact: StringName) -> bool:
	var found: bool = false
	for record: ArtefactRecord in state.artefacts.items:
		if record.artefact == artefact and record.room_uid != ArtefactRecord.AT_GATE:
			record.state = ArtefactRecord.ArtefactState.STUDIED
			found = true
	if found:
		state.events.post(&"artefact_studied", [artefact])
	return found


static func _reveal(state: GameState, project: StringName) -> bool:
	if not state.research_defs.has(project) or state.research.revealed.has(project):
		return false
	state.research.revealed.append(project)
	state.events.post(&"research_revealed", [project])
	return true


static func _complete(state: GameState, project: StringName) -> bool:
	var def: ResearchDef = state.research_defs.get(project)
	if def == null or state.research.is_done(project):
		return false
	if state.research.active == project:
		ResearchSystem.finish(state, def)
		return true
	StoryRules.apply_all(state, def.effects, def.id)
	state.research.done.append(project)
	state.events.post(&"research_done", [project])
	return true
