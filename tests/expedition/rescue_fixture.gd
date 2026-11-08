extends RefCounted
## Test fixture for check-ins and rescues: the expedition fixture's game and a simulation whose
## ExpeditionSystem misses the check-in of field day [param missed_day] (the hook field events,
## card M3-11, set through ExpeditionState.DAY_MISSED), and helpers to send and signal.
## Bible: docs/content/m3-beyond-the-ring.md section 4

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

const DAY: int = TimeMath.TICKS_PER_DAY


## A Simulation over [param game] whose field day [param missed_day] (0-based) is missed; -1
## for none.
static func simulation(game: GameState, missed_day: int = -1) -> Simulation:
	var expedition := ExpeditionSystem.new()
	expedition.resolve_day = func(_s: GameState, day: int, _r: RandomNumberGenerator) -> String:
		return ExpeditionState.DAY_MISSED if day == missed_day else ExpeditionState.DAY_OK
	var systems: Array[SimSystem] = [
		PowerSystem.new(game.balance),
		GateSystem.new(),
		ProbeSystem.new(),
		expedition,
		StaffCareSystem.new(),
	]
	return Simulation.new(game, systems)


## Plans a Survey of the open world, opens the wormhole and sends the team.
static func send(simulation: Simulation) -> void:
	simulation.submit(Fixture.survey(simulation.state))
	ProbeFixture.open(simulation)
	simulation.submit(SendTeamCommand.new())


## Sends a Survey and runs to its first check-in, missed by [param simulation].
static func send_and_miss(simulation: Simulation) -> void:
	send(simulation)
	var due: int = simulation.state.expedition.next_day_end_tick()
	Fixture.advance(simulation, due - simulation.state.clock.tick + 1)


## Opens the wormhole and gives Signal T-1; returns its result.
static func signal_team(simulation: Simulation) -> CommandResult:
	ProbeFixture.open(simulation)
	return simulation.submit(SignalTeamCommand.new())


## A seed of the expedition stream under which SurvivalRules.roll() of [param game]'s team,
## [param days] full days after the miss, leaves exactly [param deceased] dead.
static func seed_for(game: GameState, days: int, deceased: int) -> int:
	var members: Array[PersonState] = []
	for person_id: StringName in game.expedition.member_ids():
		members.append(game.staff.find_person(person_id))
	var facts: WorldFacts = WorldFactRules.facts_for_id(game.galaxy, game.expedition.world_id)
	var rng := RandomNumberGenerator.new()
	for candidate: int in 100_000:
		rng.seed = candidate
		if SurvivalRules.roll(members, facts, days, rng).size() == deceased:
			return candidate
	return -1
