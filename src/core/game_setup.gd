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
	state.room_defs.clear()
	for def: RoomDef in defs.rooms:
		state.room_defs[def.id] = def
	state.research_defs.clear()
	for def: ResearchDef in defs.research:
		state.research_defs[def.id] = def
	state.galaxy = build_galaxy(state.worlds.galaxy_seed, defs)
	var systems: Array[SimSystem] = [
		PowerSystem.new(defs.balance),
		GateSystem.new(),
		DocumentSystem.new(defs.documents),
		ProbeSystem.new(),
		ExpeditionSystem.new(),
		EconomySystem.new(defs.balance, defs.rooms),
		ConstructionSystem.new(),
		ResearchSystem.new(),
		RecruitmentSystem.new(defs.balance, defs.roles, defs.staff_names),
		StaffCareSystem.new(),
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
