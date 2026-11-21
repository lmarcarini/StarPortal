class_name SoakResearch
extends RefCounted
## The soak bot's research moves: getting the Research Lab on and starting the next project.
## Bible: technical-architecture.md#testing-and-tooling (Soak test),
## docs/content/m25-lean-start.md section 3

## Power comes in 5 MW blocks; the bot lowers charging by whole blocks.
const BLOCK_MW: int = 5
## The Engineering projects the bot researches in the Workshop, in order (M7: the Security
## Post and blast door plans first, E02, E09, E10; then E01, E04, E03, E06, E07, E05; none
## needs a reveal beyond its needs).
const ORDER: Array[StringName] = [
	&"plan_personnel_office",
	&"plan_security_post",
	&"blast_doors",
	&"excavation_survey",
	&"bank_array",
	&"survey_drones",
	&"lift_shaft",
	&"deep_excavation",
	&"prefab_modules",
]


## When the lab stands off: lowers the bank's charge rate by just enough whole blocks, or,
## with enough spare, switches the lab on. True when it sent a command.
static func work_lab(simulation: Simulation, lab_def: StringName) -> bool:
	var state: GameState = simulation.state
	var lab: RoomState = PowerFixture.first_room(state, lab_def)
	if lab == null or not lab.is_built() or lab.powered_on:
		return false
	var draw: int = ceili(state.room_defs[lab_def].power_draw_mw)
	var short: int = draw - floori(PowerRules.spare_mw(state))
	var next: Command = SwitchRoomCommand.create(lab.id, true)
	if short > 0:
		var bank: StringName = state.power.charge_rates.keys()[0]
		var lower: int = ceili(float(short) / BLOCK_MW) * BLOCK_MW
		next = SetChargeRateCommand.create(bank, maxi(0, state.power.charge_rates[bank] - lower))
	if not next.validate(state).is_ok:
		return false
	simulation.submit(next)
	return true


## Starts the first project of [param order] not done yet when nothing runs and it may start;
## while one runs, queues the next one in order (M4-31). True when it sent a command.
static func work_research(simulation: Simulation, order: Array[StringName]) -> bool:
	var state: GameState = simulation.state
	if state.research.is_running():
		return _queue_next(simulation, order)
	for project_id: StringName in order:
		if state.research.is_done(project_id):
			continue
		var next := StartResearchCommand.create(project_id)
		if not next.validate(state).is_ok:
			return false
		simulation.submit(next)
		return true
	return false


## Queues the first project of [param order] that is neither done, running nor queued, when the
## queue is empty and the project may be queued. True when it sent a command.
static func _queue_next(simulation: Simulation, order: Array[StringName]) -> bool:
	var state: GameState = simulation.state
	var running: Array[StringName] = state.research.running()
	var room_id: StringName = state.research.room_running(running[0])
	if not state.research.bench_of(room_id).queue.is_empty():
		return false
	for project_id: StringName in order:
		if state.research.is_done(project_id) or project_id in running:
			continue
		var next := QueueResearchCommand.new(project_id, room_id)
		if not next.validate(state).is_ok:
			return false
		simulation.submit(next)
		return true
	return false
