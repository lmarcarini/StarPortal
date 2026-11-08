extends RefCounted
## Test fixture for the probes: the dial fixture's galaxy with eight more procedural worlds
## (so a console's older log has entries), the open world given hand-set facts (threat and
## targets), and a simulation with the power, gate and probe systems.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Probes)

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

const WORLD_ID: StringName = DialFixture.OPEN_ID
## An object with marks (like STILLWATER's iron object) and a land feature.
const ANCHOR_ID: StringName = &"anchor"
const FOOTPRINTS_ID: StringName = &"footprints"
const MARKS_DOCUMENT_ID: StringName = &"doc_anchor_marks"
const EXTRA_WORLDS: int = 8


## Returns a paused game over the extended galaxy whose open world has true threat
## [param threat] and the targets anchor (object, with marks) and footprints.
static func state(threat: WorldDef.Threat = WorldDef.Threat.LOW, base_seed: int = 1) -> GameState:
	var game: GameState = DialFixture.state(null, true)
	game.random.base_seed = base_seed
	game.galaxy = galaxy()
	set_threat(game, threat)
	return game


## Sets the true threat of the open world of [param game] to [param threat].
static func set_threat(game: GameState, threat: WorldDef.Threat) -> void:
	game.galaxy.get_world(WORLD_ID).authored_facts.threat = threat


## Returns the dial fixture's galaxy plus EXTRA_WORLDS procedural worlds near the open world,
## whose facts are hand-set.
static func galaxy() -> GalaxyCatalogue:
	var base: GalaxyCatalogue = DialFixture.galaxy()
	var worlds: Array[WorldRecord] = base.all_worlds().duplicate()
	var open: WorldRecord = base.get_world(WORLD_ID)
	for index: int in EXTRA_WORLDS:
		var record := WorldRecord.new()
		record.id = StringName("world_extra_%d" % index)
		record.position_ly = open.position_ly + Vector3i(10 * (index + 1), 0, 0)
		worlds.append(record)
	open.authored_facts = facts()
	return GalaxyCatalogue.build(worlds, base.anchors_ly())


## The open world's facts: LOW, with an anchor (object, with marks) and footprints.
static func facts() -> WorldFacts:
	var world_facts := WorldFacts.new()
	world_facts.world_id = WORLD_ID
	world_facts.biohazard = WorldDef.Biohazard.LOW
	world_facts.life = WorldDef.Life.ANIMALS
	world_facts.structures = WorldDef.Structures.WORKED_STONE
	var anchor := WorldTarget.create(ANCHOR_ID, &"TARGET_ANCHOR", true)
	anchor.marks_document_id = MARKS_DOCUMENT_ID
	world_facts.targets = [anchor, WorldTarget.create(FOOTPRINTS_ID, &"TARGET_FOOTPRINTS", false)]
	return world_facts


## Returns a Simulation over [param game] with the power, gate and probe systems.
static func simulation(game: GameState) -> Simulation:
	var systems: Array[SimSystem] = [
		PowerSystem.new(game.balance), GateSystem.new(), ProbeSystem.new()
	]
	return Simulation.new(game, systems)


## Dials the open world and runs until the wormhole is open.
static func open(simulation: Simulation) -> void:
	var address: GateAddress = DialFixture.address_of(simulation.state.galaxy, WORLD_ID)
	simulation.submit(DialCommand.create(address))
	while simulation.state.gate.mode != GateState.RingMode.LOCKED:
		simulation.advance_tick()


## Submits [param command] and asserts nothing: returns its result.
static func run(simulation: Simulation, command: Command) -> CommandResult:
	return simulation.submit(command)


## Advances [param simulation] [param ticks] ticks.
static func advance(simulation: Simulation, ticks: int) -> void:
	for index: int in ticks:
		simulation.advance_tick()
