class_name GameSetup
extends RefCounted
## Builds a runnable Simulation around a new or loaded GameState: regenerates the galaxy from
## the state's saved seed and generator version, sets the state's transient balance and
## galaxy, and adds the systems in the bible's fixed tick order (power, gate, documents,
## probes, expedition, economy, construction, research, recruitment).
## Bible: technical-architecture.md#simulation-clock-and-commands,
## technical-architecture.md#save-system, technical-architecture.md#data-model


## Returns a Result whose value is a Simulation over [param state] with
## [PowerSystem, GateSystem, DocumentSystem, ProbeSystem, ExpeditionSystem, EconomySystem,
## ConstructionSystem, ResearchSystem, RecruitmentSystem], after setting [code]state.balance[/code],
## [code]state.room_defs[/code], [code]state.research_defs[/code] and
## [code]state.galaxy[/code] from [param defs]. Fails,
## leaving the state unchanged, with
## &"missing_content" when [param defs] lacks the balance, 36 anchors or exactly one home
## world, and with &"galaxy_version_mismatch" when the state's generator version is not
## WorldGenerator.GENERATOR_VERSION (the same seed would give another galaxy).
static func build(state: GameState, defs: GameDefs) -> Result:
	assert(state != null, "GameSetup.build() needs a state")
	var missing: String = _missing_content(defs)
	if not missing.is_empty():
		return Result.fail(&"missing_content", missing)
	if state.worlds.generator_version != WorldGenerator.GENERATOR_VERSION:
		return Result.fail(
			&"galaxy_version_mismatch",
			(
				"saved %d, generator %d"
				% [state.worlds.generator_version, WorldGenerator.GENERATOR_VERSION]
			)
		)
	state.balance = defs.balance
	# Rooms a new game starts with stay unlocked in older saves (the Security Post, M4c).
	for def_id: StringName in defs.balance.starting_room_unlocks:
		if not def_id in state.unlocks.rooms:
			state.unlocks.rooms.append(def_id)
	state.room_defs.clear()
	for def: RoomDef in defs.rooms:
		state.room_defs[def.id] = def
	state.artefact_defs.clear()
	for artefact: ArtefactDef in defs.artefacts:
		state.artefact_defs[artefact.id] = artefact
	state.modifiers = ModifierCache.new()
	state.faction_defs.clear()
	for faction: FactionDef in defs.factions:
		state.faction_defs[faction.id] = faction
	state.conversation_defs.clear()
	for conversation: ConversationDef in defs.conversations:
		state.conversation_defs[conversation.id] = conversation
	ConversationRules.settle_loaded(state)
	state.speaker_defs.clear()
	for speaker: SpeakerDef in defs.speakers:
		state.speaker_defs[speaker.id] = speaker
	state.portrait_defs.clear()
	for portrait: PortraitDef in defs.portraits:
		state.portrait_defs[portrait.id] = portrait
	state.request_defs.clear()
	for request: RequestDef in defs.requests:
		state.request_defs[request.id] = request
	state.incursion_defs.clear()
	for incursion: IncursionDef in defs.incursions:
		state.incursion_defs[incursion.id] = incursion
	state.unit_defs.clear()
	for unit: UnitDef in defs.units:
		state.unit_defs[unit.id] = unit
	state.installation_defs.clear()
	for installation: InstallationDef in defs.installations:
		state.installation_defs[installation.id] = installation
	state.research_defs.clear()
	for def: ResearchDef in defs.research:
		state.research_defs[def.id] = def
	_drop_unknown_research(state)
	state.galaxy = build_galaxy(state.worlds.galaxy_seed, defs)
	var systems: Array[SimSystem] = [
		PowerSystem.new(defs.balance),
		GateSystem.new(),
		MissionOrderSystem.new(),
		ConversationSystem.new(),
		RequestSystem.new(),
		DocumentSystem.new(defs.documents),
		ProbeSystem.new(),
		ExpeditionSystem.new(),
		EconomySystem.new(defs.balance, defs.rooms),
		ConstructionSystem.new(),
		ResearchSystem.new(),
		RecruitmentSystem.new(defs.balance, defs.roles, defs.staff_names),
		StaffCareSystem.new(),
		FactionSystem.new(),
		ArtefactSystem.new(),
		SecuritySystem.new(),
		IncursionSystem.new(),
		OutcomeSystem.new(),
	]
	return Result.ok(Simulation.new(state, systems))


## Like build(), for a new game: also delivers every AT_START document to the Archive at the
## clock's tick, in id order, posting document_received for each (emitted with the next
## tick's events). Only new games go through here, so a loaded game never re-delivers. Also
## sets the factions' starting standings and meets the Earth factions (FactionsState.starting).
static func build_new(state: GameState, defs: GameDefs) -> Result:
	var built: Result = build(state, defs)
	if built.is_ok:
		DocumentSystem.deliver_start_documents(state, defs.documents)
		state.factions = FactionsState.starting(defs.factions)
	return built


## Returns the galaxy generated from [param galaxy_seed] over [param defs]' anchors and
## authored worlds, with the default GeneratorParams. Same inputs, same galaxy.
static func build_galaxy(galaxy_seed: int, defs: GameDefs) -> GalaxyCatalogue:
	var anchors_ly: Array[Vector3i] = defs.anchors.positions_ly
	var worlds: Array[WorldRecord] = WorldGenerator.generate(
		galaxy_seed, anchors_ly, defs.authored_worlds, GeneratorParams.new(), defs.balance
	)
	return GalaxyCatalogue.build(worlds, anchors_ly)


## What [param defs] lacks, or "" when it has everything build() needs.
static func _missing_content(defs: GameDefs) -> String:
	if defs == null or defs.balance == null:
		return "no balance"
	if defs.anchors == null or defs.anchors.positions_ly.size() != GateAddress.GLYPH_COUNT:
		return "no field of %d anchors" % GateAddress.GLYPH_COUNT
	var homes: int = 0
	for def: WorldDef in defs.authored_worlds:
		if def != null and def.is_home:
			homes += 1
	if homes != 1:
		return "%d home worlds, not 1" % homes
	return ""


## Drops research ids [param state]'s content no longer has (an old save after a content
## change): from done, queue and revealed, and the active project with its progress.
static func _drop_unknown_research(state: GameState) -> void:
	var research: ResearchState = state.research
	var lists: Array = [research.done, research.revealed, research.opened]
	for bench: ResearchBench in research.benches.values():
		lists.append(bench.queue)
		if bench.is_running() and not state.research_defs.has(bench.active):
			bench.active = &""
			bench.ticks_done = 0
	for list: Array[StringName] in lists:
		for project_id: StringName in list.duplicate():
			if not state.research_defs.has(project_id):
				list.erase(project_id)
