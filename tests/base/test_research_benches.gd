## Tests for the M7 research model: projects visible only when revealed (start disciplines,
## buildings, needs, reveal conditions, story), a bench per research building with its own
## queue, progress only from the building's own staff, the one-time "new research" event,
## materials spent on start, and the saved state.
## Bible: docs/content/research-and-progression.md sections 2-3
extends GdUnitTestSuite

const ART: StringName = &"kindred_loom"

var _state: GameState
var _lab: RoomState


func before_test() -> void:
	_state = ConstructionFixture.state()
	PowerFixture.load_room_defs(_state)
	_state.research_defs.clear()
	_add(&"t_eng", &"engineering", [], [])
	_add(&"t_eng_next", &"engineering", [&"t_eng"], [])
	_add(&"t_sci", &"science", [], [])
	_add(&"t_sci_b", &"science", [], [])
	var held := HasArtefactCondition.new()
	held.artefact = ART
	_add(&"t_sci_art", &"science", [], [held])
	_add(&"t_office", &"office", [], [])
	_add(&"t_story", &"science", [], []).story = true
	_lab = PowerFixture.lab(_state)
	StaffChanges.auto_assign(_state, _lab)
	_state.events.drain()


func _add(
	id: StringName, discipline: StringName, needs: Array[StringName], reveal: Array[ConditionDef]
) -> ResearchDef:
	var def := ResearchDef.new()
	def.id = id
	def.discipline = discipline
	def.hours = 4
	def.cost_k = 100
	def.needs = needs
	def.reveal_when = reveal
	def.order = _state.research_defs.size()
	_state.research_defs[id] = def
	return def


func _ids(defs: Array[ResearchDef]) -> Array[StringName]:
	var found: Array[StringName] = []
	for def: ResearchDef in defs:
		found.append(def.id)
	return found


func _run(command: Command) -> CommandResult:
	return ConstructionFixture.run(_state, command)


func _ticks(count: int) -> void:
	var system := ResearchSystem.new()
	for i: int in count:
		system.tick(_state)
		_state.clock.tick += 1


func test_only_revealed_projects_are_visible() -> void:
	var shown: Array[StringName] = _ids(ResearchRules.visible_projects(_state))
	assert_array(shown).contains_exactly([&"t_eng", &"t_sci", &"t_sci_b"])
	StoryRulesItems.give_artefact(_state, ART)
	assert_array(_ids(ResearchRules.visible_projects(_state, &"science"))).contains([&"t_sci_art"])
	assert_array(_ids(ResearchRules.visible_projects(_state))).not_contains(
		[&"t_story", &"t_office", &"t_eng_next"]
	)


func test_revealed_once_with_an_event_and_stays() -> void:
	assert_int(ResearchSystem.reveal_new(_state)).is_equal(3)
	assert_int(ResearchSystem.reveal_new(_state)).is_equal(0)
	var names: Array[StringName] = StoryFixture.event_names(_state)
	assert_int(names.count(&"research_revealed")).is_equal(3)
	assert_bool(_state.research.is_new(&"t_sci")).is_true()
	StoryRulesItems.give_artefact(_state, ART)
	assert_int(ResearchSystem.reveal_new(_state)).is_equal(1)
	_state.artefacts.items.clear()
	assert_bool(ResearchRules.visible(_state, _state.research_defs[&"t_sci_art"])).is_true()


func test_start_needs_a_building_of_its_discipline() -> void:
	var eng: CommandResult = _run(StartResearchCommand.create(&"t_eng"))
	assert_str(String(eng.error_code)).is_equal("needs_building")
	assert_str(String(_run(StartResearchCommand.create(&"t_office")).error_code)).is_equal(
		"unknown_project"
	)
	var shop: RoomState = ResearchFixture.workshop(_state)
	assert_bool(_run(StartResearchCommand.create(&"t_eng")).is_ok).is_true()
	assert_str(String(_state.research.room_running(&"t_eng"))).is_equal(String(shop.id))
	var wrong: CommandResult = _run(StartResearchCommand.create(&"t_sci", shop.id))
	assert_str(String(wrong.error_code)).is_equal("wrong_building")


func test_two_buildings_run_in_parallel_one_each() -> void:
	ResearchFixture.workshop(_state)
	assert_bool(_run(StartResearchCommand.create(&"t_sci")).is_ok).is_true()
	assert_bool(_run(StartResearchCommand.create(&"t_eng")).is_ok).is_true()
	var busy: CommandResult = _run(StartResearchCommand.create(&"t_sci_b"))
	assert_str(String(busy.error_code)).is_equal("bench_busy")
	assert_array(_state.research.running()).contains_exactly([&"t_sci", &"t_eng"])
	_ticks(ResearchRules.total_ticks(_state.research_defs[&"t_sci"]) * 4)
	assert_bool(_state.research.is_done(&"t_sci")).is_true()
	assert_bool(_state.research.is_done(&"t_eng")).is_true()


func test_no_staff_of_the_field_no_progress() -> void:
	assert_bool(_run(StartResearchCommand.create(&"t_sci")).is_ok).is_true()
	for person: PersonState in _state.staff.people:
		if person.room_id == _lab.id:
			person.room_id = &""
	assert_int(ResearchSpeed.speed(_state, _lab)).is_equal(0)
	_ticks(100)
	assert_int(_state.research.bench_of(_lab.id).ticks_done).is_equal(0)
	assert_int(ResearchSpeed.ticks_left(_state, _lab)).is_equal(-1)


func test_staff_speed_sets_the_time() -> void:
	assert_int(ResearchSpeed.percent(_state, _lab)).is_equal(100)
	_run(StartResearchCommand.create(&"t_sci"))
	_ticks(ResearchRules.total_ticks(_state.research_defs[&"t_sci"]))
	assert_bool(_state.research.is_done(&"t_sci")).is_true()


func test_each_bench_has_its_own_queue() -> void:
	var shop: RoomState = ResearchFixture.workshop(_state)
	assert_bool(_run(QueueResearchCommand.new(&"t_sci", _lab.id)).is_ok).is_true()
	assert_str(String(_state.research.bench_of(_lab.id).active)).is_equal("t_sci")
	assert_bool(_run(QueueResearchCommand.new(&"t_sci_b", _lab.id)).is_ok).is_true()
	var wrong: CommandResult = _run(QueueResearchCommand.new(&"t_sci_b", shop.id))
	assert_str(String(wrong.error_code)).is_equal("already_queued")
	assert_str(String(ResearchRules.queue_error(_state, &"t_eng", _lab.id))).is_equal(
		"wrong_building"
	)
	_ticks(ResearchRules.total_ticks(_state.research_defs[&"t_sci"]) + 2)
	assert_str(String(_state.research.bench_of(_lab.id).active)).is_equal("t_sci_b")
	assert_bool(_run(CancelResearchCommand.new(_lab.id)).is_ok).is_true()
	assert_str(String(_run(CancelResearchCommand.new(shop.id)).error_code)).is_equal("no_research")


func test_needs_reveal_follow_ups() -> void:
	ResearchFixture.workshop(_state)
	ResearchFixture.finish(_state, &"t_eng")
	assert_array(_ids(ResearchRules.visible_projects(_state, &"engineering"))).contains(
		[&"t_eng_next"]
	)


func test_pieces_are_spent_on_start() -> void:
	var def: ResearchDef = _state.research_defs[&"t_sci_b"]
	def.piece_artefact = ART
	def.piece_count = 1
	assert_str(String(_run(StartResearchCommand.create(&"t_sci_b")).error_code)).is_equal(
		"needs_pieces"
	)
	StoryRulesItems.give_artefact(_state, ART)
	assert_bool(_run(StartResearchCommand.create(&"t_sci_b")).is_ok).is_true()
	assert_int(ResearchMaterials.pieces_held(_state, ART)).is_equal(0)


func test_saved_and_validated() -> void:
	ResearchFixture.workshop(_state)
	_run(StartResearchCommand.create(&"t_sci"))
	_run(QueueResearchCommand.new(&"t_sci_b", _lab.id))
	ResearchSystem.reveal_new(_state)
	_state.research.opened.append(&"t_sci")
	_ticks(30)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.research.to_dict()))
	assert_array(ResearchState.validate_dict(data)).is_empty()
	assert_dict(ResearchState.from_dict(data).to_dict()).is_equal(_state.research.to_dict())
	data["benches"] = {"x": {"active": 3}}
	assert_array(ResearchState.validate_dict(data)).is_not_empty()


func test_commands_round_trip() -> void:
	for command: Command in [
		StartResearchCommand.create(&"t_sci", _lab.id),
		QueueResearchCommand.new(&"t_sci", _lab.id, 0),
		CancelResearchCommand.new(_lab.id),
		UnqueueResearchCommand.new(&"t_sci"),
	]:
		var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
		var rebuilt: Command = CommandFactory.from_dict(data).value
		assert_dict(rebuilt.to_dict()).is_equal(command.to_dict())
