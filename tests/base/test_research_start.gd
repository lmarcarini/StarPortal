## Tests for starting and cancelling research: the refusals (no lab on, one project at a time,
## unmet needs, money, locked, done, unknown), full payment at start and the 50% refund.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite


func _start(game: GameState, project_id: StringName) -> CommandResult:
	return ConstructionFixture.run(game, StartResearchCommand.create(project_id))


## With no lab, a lab being built, a lab switched off or one being demolished, Start is refused.
func test_needs_a_lab_that_is_on() -> void:
	var game: GameState = ResearchFixture.state(false)
	assert_that(_start(game, &"bank_array").error_code).is_equal(&"needs_lab")
	var lab: RoomState = PowerFixture.lab(game)
	lab.build_ticks_left = 10
	assert_that(_start(game, &"bank_array").error_code).is_equal(&"needs_lab")
	lab.build_ticks_left = 0
	lab.powered_on = false
	assert_that(_start(game, &"bank_array").error_code).is_equal(&"needs_lab")
	lab.powered_on = true
	lab.demolish_ticks_left = 5
	assert_that(_start(game, &"bank_array").error_code).is_equal(&"needs_lab")
	lab.demolish_ticks_left = 0
	assert_bool(_start(game, &"bank_array").is_ok).is_true()


## Starting pays the full cost at once and makes the project active from zero.
func test_start_pays_in_full() -> void:
	var game: GameState = ResearchFixture.state()
	var funds: int = game.budget.funds_k
	assert_bool(_start(game, &"bank_array").is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(funds - 600)
	assert_that(game.research.active).is_equal(&"bank_array")
	assert_int(game.research.ticks_done).is_equal(0)
	var names: Array[StringName] = []
	for event: SimEvent in game.events.drain():
		names.append(event.name)
	assert_array(names).is_equal([&"budget_changed", &"research_started"])


## A second start while one runs is refused, naming the running project.
func test_one_project_at_a_time() -> void:
	var game: GameState = ResearchFixture.state()
	_start(game, &"bank_array")
	var result: CommandResult = _start(game, &"second_plant")
	assert_that(result.error_code).is_equal(&"research_running")
	assert_str(result.detail).is_equal("bank_array")


## Unmet needs name the first missing project; once done, the next one may start.
func test_needs() -> void:
	var game: GameState = ResearchFixture.state()
	var result: CommandResult = _start(game, &"deep_excavation")
	assert_that(result.error_code).is_equal(&"needs_project")
	assert_str(result.detail).is_equal("lift_shaft")
	assert_that(_start(game, &"fuel_contracts").detail).is_equal("second_plant")
	ResearchFixture.finish(game, &"excavation_survey")
	ResearchFixture.finish(game, &"lift_shaft")
	assert_bool(_start(game, &"deep_excavation").is_ok).is_true()


## Too little money is refused, with the cost as detail, and nothing is paid.
func test_insufficient_funds() -> void:
	var game: GameState = ResearchFixture.state()
	game.budget.funds_k = 599
	var result: CommandResult = _start(game, &"bank_array")
	assert_that(result.error_code).is_equal(&"insufficient_funds")
	assert_str(result.detail).is_equal("600")
	assert_int(game.budget.funds_k).is_equal(599)


## Locked slots, done projects and unknown ids are refused.
func test_locked_done_unknown() -> void:
	var game: GameState = ResearchFixture.state()
	var hidden: CommandResult = _start(game, &"later_containment")
	assert_that(hidden.error_code).is_equal(&"unknown_project")
	game.research.revealed.append(&"later_containment")
	assert_that(_start(game, &"later_containment").error_code).is_equal(&"requirement_unmet")
	assert_that(_start(game, &"warp_drive").error_code).is_equal(&"unknown_project")
	ResearchFixture.finish(game, &"bank_array")
	assert_that(_start(game, &"bank_array").error_code).is_equal(&"project_done")


## Cancelling refunds half the cost and drops the progress; with nothing running it is refused.
func test_cancel_refunds_half() -> void:
	var game: GameState = ResearchFixture.state()
	var cancel := CancelResearchCommand.new()
	assert_that(cancel.validate(game).error_code).is_equal(&"no_research")
	var funds: int = game.budget.funds_k
	_start(game, &"second_plant")
	var system := ResearchSystem.new()
	for i: int in 100:
		system.tick(game)
		game.clock.tick += 1
	assert_bool(ConstructionFixture.run(game, cancel).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(funds - 500 + 250)
	assert_bool(game.research.is_running()).is_false()
	assert_int(game.research.ticks_done).is_equal(0)
	assert_bool(game.research.is_done(&"second_plant")).is_false()
	assert_bool(_start(game, &"second_plant").is_ok).is_true()


## The project list starts with the seven M2.5 projects in order; M4 adds the rest of the tree.
func test_project_list() -> void:
	var ids: Array[StringName] = []
	for def: ResearchDef in ResearchRules.projects(ResearchFixture.state()):
		ids.append(def.id)
	assert_array(ids.slice(0, 7)).is_equal(UnlockFixture.projects().keys())
	assert_int(ids.size()).is_equal(37)
	var cost: int = 0
	var days: int = 0
	for def: ResearchDef in ResearchRules.projects(ResearchFixture.state()):
		if def.order <= 7:
			cost += def.cost_k
			days += def.days
	assert_int(cost).is_equal(3400)
	assert_int(days).is_equal(19)


## Start and cancel commands survive a JSON round trip; a start without a project is malformed.
func test_commands_round_trip() -> void:
	var data: Dictionary = JSON.parse_string(
		JSON.stringify(StartResearchCommand.create(&"bank_array").to_dict())
	)
	var rebuilt: StartResearchCommand = CommandFactory.from_dict(data).value
	assert_that(rebuilt.project_id).is_equal(&"bank_array")
	assert_that(CommandFactory.from_dict({"type": "start_research"}).error_code).is_equal(
		&"malformed_command"
	)
	assert_bool(CommandFactory.from_dict({"type": "cancel_research"}).is_ok).is_true()
