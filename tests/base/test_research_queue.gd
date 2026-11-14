## Tests for the research queue (M4-31): up to five, no duplicates, done or hidden projects;
## the next starts the tick the current finishes when affordable, otherwise waits with a reason
## and retries daily; cancelling keeps the queue; a Log line on start; saved.
## Bible: docs/content/m4-core-systems.md section 7 (4)
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = ResearchFixture.state()


func _queue(project: StringName) -> CommandResult:
	var command := QueueResearchCommand.new(project)
	var result: CommandResult = command.validate(_state)
	if result.is_ok:
		command.apply(_state)
	return result


func test_refusals() -> void:
	assert_str(String(_queue(&"later_containment").error_code)).is_equal("unknown_project")
	ResearchFixture.finish(_state, &"bank_array")
	assert_str(String(_queue(&"bank_array").error_code)).is_equal("project_done")
	assert_bool(_queue(&"excavation_survey").is_ok).is_true()
	assert_str(String(ResearchRules.queue_error(_state, &"excavation_survey"))).is_equal(
		"project_running"
	)
	assert_bool(_queue(&"lift_shaft").is_ok).is_true()
	assert_str(String(ResearchRules.queue_error(_state, &"lift_shaft"))).is_equal("already_queued")
	var more: Array[StringName] = [
		&"deep_excavation", &"second_plant", &"fuel_contracts", &"field_engineering"
	]
	for project: StringName in more:
		assert_bool(_queue(project).is_ok).is_true()
	assert_str(String(_queue(&"later_capacitor_lattice").error_code)).is_equal("queue_full")


func test_first_starts_at_once_and_next_on_finish() -> void:
	_state.budget.funds_k = 100000
	assert_bool(_queue(&"excavation_survey").is_ok).is_true()
	assert_str(String(_state.research.active)).is_equal("excavation_survey")
	_queue(&"lift_shaft")
	assert_array(_state.research.queue).is_equal([&"lift_shaft"])
	var def: ResearchDef = _state.research_defs[&"excavation_survey"]
	_state.research.ticks_done = ResearchRules.total_ticks(def) - 1
	var system := ResearchSystem.new()
	for tick: int in 10:
		system.tick(_state)
		if _state.research.active == &"lift_shaft":
			break
	assert_str(String(_state.research.active)).is_equal("lift_shaft")
	assert_array(_state.research.queue).is_empty()
	var names: Array[StringName] = StoryFixture.event_names(_state)
	assert_array(names).contains([&"research_queue_started"])


func test_waits_for_funds_and_retries_daily() -> void:
	_state.budget.funds_k = 100000
	_queue(&"excavation_survey")
	_state.budget.funds_k = 0
	_queue(&"second_plant")
	ResearchSystem.finish(_state, _state.research_defs[&"excavation_survey"])
	assert_bool(ResearchSystem.start_next(_state)).is_false()
	assert_str(String(ResearchRules.queue_wait(_state))).is_equal("waiting_for_funds")
	_state.budget.funds_k = 100000
	ResearchSystem.new().on_day(_state)
	assert_str(String(_state.research.active)).is_equal("second_plant")


func test_cancel_keeps_the_queue_and_moves() -> void:
	_state.budget.funds_k = 100000
	_queue(&"excavation_survey")
	_queue(&"second_plant")
	_queue(&"bank_array")
	QueueResearchCommand.new(&"bank_array", 0).apply(_state)
	assert_array(_state.research.queue).is_equal([&"bank_array", &"second_plant"])
	CancelResearchCommand.new().apply(_state)
	assert_array(_state.research.queue).is_equal([&"bank_array", &"second_plant"])
	UnqueueResearchCommand.new(&"bank_array").apply(_state)
	assert_array(_state.research.queue).is_equal([&"second_plant"])
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.from_dict(data).research.queue).is_equal([&"second_plant"])
