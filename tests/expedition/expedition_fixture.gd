extends RefCounted
## Test fixture for expeditions: the probe fixture's game with Expeditions unlocked (so the two
## lent soldiers are on base), the open world Probed, and a simulation with the power, gate,
## probe, expedition and staff care systems. team() fills the four slots from the start crew.
## Bible: docs/content/m3-beyond-the-ring.md section 4

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

const WORLD_ID: StringName = ProbeFixture.WORLD_ID
const ANCHOR_ID: StringName = ProbeFixture.ANCHOR_ID
const DAY: int = TimeMath.TICKS_PER_DAY


## Returns a paused game, Expeditions unlocked, the open world Probed.
static func state() -> GameState:
	var game: GameState = ProbeFixture.state()
	ExpeditionUnlock.unlock(game)
	game.worlds.statuses[WORLD_ID] = WorldsState.WorldStatus.PROBED
	game.events.drain()
	return game


## Returns a Simulation over [param game] with the systems an expedition needs.
static func simulation(game: GameState) -> Simulation:
	var systems: Array[SimSystem] = [
		PowerSystem.new(game.balance),
		GateSystem.new(),
		ProbeSystem.new(),
		ExpeditionSystem.new(),
		StaffCareSystem.new(),
	]
	return Simulation.new(game, systems)


## The first person of [param role] in [param game] not in [param taken].
static func person_of(game: GameState, role: StringName, taken: Array = []) -> PersonState:
	for person: PersonState in game.staff.people:
		if person.role == role and not person.id in taken:
			return person
	return null


## A valid team: an engineer leads, a scientist, a lent soldier and a second scientist.
static func team(game: GameState) -> Dictionary:
	var leader: PersonState = person_of(game, StartingStaff.ENGINEER)
	var scientist: PersonState = person_of(game, StartingStaff.SCIENTIST)
	var soldier: PersonState = person_of(game, StartingStaff.SOLDIER)
	var specialist: PersonState = person_of(game, StartingStaff.SCIENTIST, [scientist.id])
	return {
		"leader": leader.id,
		"scientist": scientist.id,
		"soldier": soldier.id,
		"specialist": specialist.id,
	}


## A Survey plan of the open world with team().
static func survey(game: GameState) -> PlanExpeditionCommand:
	return PlanExpeditionCommand.create(ExpeditionState.Objective.SURVEY, WORLD_ID, &"", team(game))


## A Recover plan of the anchor with team().
static func recover(game: GameState) -> PlanExpeditionCommand:
	return PlanExpeditionCommand.create(
		ExpeditionState.Objective.RECOVER, WORLD_ID, ANCHOR_ID, team(game)
	)


## Advances [param simulation] [param ticks] ticks.
static func advance(simulation: Simulation, ticks: int) -> void:
	for index: int in ticks:
		simulation.advance_tick()
