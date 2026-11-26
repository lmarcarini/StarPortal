## Tests for OpenResearchCommand (card #560): a revealed project is recorded as opened once,
## with research_opened; an unknown or invisible project is refused; it round-trips.
## Bible: docs/content/research-and-progression.md section 7
extends GdUnitTestSuite


func test_opens_once() -> void:
	var state: GameState = ResearchFixture.state()
	var def: ResearchDef = ResearchRules.visible_projects(state, &"science")[0]
	state.research.revealed.append(def.id)
	assert_bool(state.research.is_new(def.id)).is_true()
	assert_bool(ConstructionFixture.run(state, OpenResearchCommand.new(def.id)).is_ok).is_true()
	assert_bool(state.research.is_new(def.id)).is_false()
	var names: Array[StringName] = []
	for event: SimEvent in state.events.drain():
		names.append(event.name)
	assert_int(names.count(&"research_opened")).is_equal(1)
	ConstructionFixture.run(state, OpenResearchCommand.new(def.id))
	assert_int(state.research.opened.count(def.id)).is_equal(1)
	assert_int(state.events.drain().size()).is_equal(0)


func test_refuses_unknown_and_hidden() -> void:
	var state: GameState = ResearchFixture.state()
	assert_str(OpenResearchCommand.new(&"nope").validate(state).error_code).is_equal(
		"unknown_project"
	)
	for def: ResearchDef in state.research_defs.values():
		if not ResearchRules.visible(state, def):
			assert_bool(OpenResearchCommand.new(def.id).validate(state).is_ok).is_false()
			return


func test_round_trips() -> void:
	var command := OpenResearchCommand.new(&"gate_calibration")
	var back: Result = CommandFactory.from_dict(command.to_dict())
	assert_bool(back.is_ok).is_true()
	var again: OpenResearchCommand = back.value
	assert_str(String(again.project_id)).is_equal("gate_calibration")
