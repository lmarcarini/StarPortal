## Tests for ResearchSystem: progress only while a lab is on (paused and kept otherwise), the
## listed time exactly, a second lab adding nothing, and a finished project applying its
## unlocks, pausing the game and writing the Log line; determinism through a Simulation.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite

const DAY: int = TimeMath.TICKS_PER_DAY

var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_real_locale)


func _ticks(game: GameState, count: int) -> void:
	var system := ResearchSystem.new()
	for i: int in count:
		system.tick(game)


## A project takes exactly its listed days; a second lab does not make it faster.
func test_listed_time_and_second_lab() -> void:
	var game: GameState = ResearchFixture.state()
	assert_int(ResearchFixture.finish(game, &"bank_array")).is_equal(3 * DAY)
	game.base.add_room(ResearchRules.LAB_DEF, 1, Vector2i(5, 5))
	assert_int(ResearchFixture.finish(game, &"second_plant")).is_equal(3 * DAY)


## Switching the lab off pauses the project and keeps its progress; demolishing it does too.
func test_lab_off_pauses_and_keeps() -> void:
	var game: GameState = ResearchFixture.state()
	var lab: RoomState = PowerFixture.lab(game)
	ConstructionFixture.run(game, StartResearchCommand.create(&"bank_array"))
	_ticks(game, 100)
	lab.powered_on = false
	_ticks(game, 500)
	assert_int(game.research.ticks_done).is_equal(100)
	assert_float(ResearchRules.progress(game)).is_equal_approx(100.0 / (3 * DAY), 0.0001)
	lab.powered_on = true
	_ticks(game, 50)
	assert_int(ResearchRules.ticks_left(game)).is_equal(3 * DAY - 150)
	game.base.remove_room(lab.id)
	_ticks(game, 500)
	assert_int(game.research.ticks_done).is_equal(150)
	assert_that(game.research.active).is_equal(&"bank_array")
	PowerFixture.lab(game)
	_ticks(game, 3 * DAY - 150)
	assert_bool(game.research.is_done(&"bank_array")).is_true()


## Progress only advances while the clock runs: a paused Simulation does not tick systems.
func test_only_while_clock_runs() -> void:
	var sim: Simulation = _simulation()
	sim.state.clock.is_paused = true
	sim.submit(StartResearchCommand.create(&"bank_array"))
	assert_that(sim.state.research.active).is_equal(&"bank_array")
	assert_int(sim.state.research.ticks_done).is_equal(0)
	sim.state.clock.is_paused = false
	sim.advance_tick()
	assert_int(sim.state.research.ticks_done).is_equal(1)


## Finishing applies the effect, posts research_done, asks for a pause and writes the Log
## line "Research done: Bank array. Up to 3 Capacitor Banks."
func test_finish_pauses_and_logs() -> void:
	var sim: Simulation = _simulation()
	sim.submit(StartResearchCommand.create(&"bank_array"))
	var pauses: Array[StringName] = []
	var done: Array[StringName] = []
	sim.pause_requested.connect(func(reason: StringName) -> void: pauses.append(reason))
	sim.event_posted.connect(
		func(event_name: StringName, args: Array) -> void:
			if event_name == &"research_done":
				done.append(args[0])
	)
	for i: int in 3 * DAY + 1:
		sim.advance_tick()
	assert_array(pauses).is_equal([&"research_done"])
	assert_array(done).is_equal([&"bank_array"])
	assert_int(sim.state.unlocks.bank_cap).is_equal(3)
	var entry: LogEntry = sim.state.operations_log.entries.back()
	assert_that(entry.kind).is_equal(&"research")
	assert_str(ArchiveLogRow.line_for(entry, sim.state)).is_equal(
		"Research done: Bank array. Up to 3 Capacitor Banks."
	)


## Two runs from the same start give the same state, tick for tick.
func test_deterministic() -> void:
	var first: Simulation = _simulation()
	var second: Simulation = _simulation()
	for sim: Simulation in [first, second]:
		sim.submit(StartResearchCommand.create(&"excavation_survey"))
		for i: int in 2 * DAY + 10:
			sim.advance_tick()
		sim.submit(StartResearchCommand.create(&"lift_shaft"))
		for i: int in DAY:
			sim.advance_tick()
	assert_dict(first.state.to_dict()).is_equal(second.state.to_dict())


## A running Simulation over the research fixture with only the research system.
func _simulation() -> Simulation:
	var game: GameState = ResearchFixture.state()
	var systems: Array[SimSystem] = [ResearchSystem.new()]
	return Simulation.new(game, systems)
