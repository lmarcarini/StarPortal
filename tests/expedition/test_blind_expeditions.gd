## Blind expeditions (M4c-22): a Survey may go to a world only Locked; it is blind: risks read
## the threat one step higher, the first check-in comes a day later, the flag survives a save,
## and the Log tags it. Expeditions unlock on the first lock.
## Bible: docs/content/m4c-incursions.md section 6
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")


func _sent(probed: bool) -> Simulation:
	var game: GameState = Fixture.state()
	if not probed:
		game.worlds.statuses[Fixture.WORLD_ID] = WorldsState.WorldStatus.LOCKED
	var simulation: Simulation = Fixture.simulation(game)
	RescueFixture.send(simulation)
	simulation.advance_tick()
	return simulation


func test_a_blind_survey_is_allowed_and_slower_and_riskier() -> void:
	var blind: Simulation = _sent(false)
	var seen: Simulation = _sent(true)
	var plan: ExpeditionState = blind.state.expedition
	assert_int(plan.mode).is_equal(ExpeditionState.Mode.AWAY)
	assert_bool(plan.blind).is_true()
	assert_bool(seen.state.expedition.blind).is_false()
	var delay: int = plan.next_day_end_tick() - seen.state.expedition.next_day_end_tick()
	assert_int(delay).is_equal(TimeMath.TICKS_PER_DAY)
	var true_threat: int = WorldFactRules.facts_for_id(blind.state.galaxy, Fixture.WORLD_ID).threat
	var expected: int = mini(true_threat + 1, WorldDef.Threat.HIGH)
	assert_int(ExpeditionRules.risk_facts(blind.state).threat).is_equal(expected)
	assert_int(ExpeditionRules.risk_facts(seen.state).threat).is_equal(true_threat)
	var data: Dictionary = JSON.parse_string(JSON.stringify(blind.state.to_dict()))
	assert_bool(GameState.from_dict(data).expedition.blind).is_true()
	var tagged: bool = false
	for entry: LogEntry in blind.state.operations_log.entries:
		tagged = tagged or entry.args.get("blind", false) == true
	assert_bool(tagged).is_true()


func test_expeditions_unlock_on_the_first_lock() -> void:
	var game := GameState.new_game(3, Registry.balance())
	GameSetup.build_new(game, GameDefs.from_registry(Registry))
	assert_bool(ExpeditionUnlock.is_due(game)).is_false()
	var world: StringName = game.galaxy.all_worlds()[1].id
	game.worlds.statuses[world] = WorldsState.WorldStatus.LOCKED
	assert_bool(ExpeditionUnlock.is_due(game)).is_true()
