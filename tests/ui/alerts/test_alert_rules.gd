## Alerts derived from the state: each kind appears with its cause and goes when it does.
## Bible: docs/content/interface-pass.md section 3 (Alerts)
extends GdUnitTestSuite

var _state: GameState = null


func before_test() -> void:
	var built: Result = GameSetup.build_new(
		GameState.new_game(5, Registry.balance()), GameDefs.from_registry(Registry)
	)
	var simulation: Simulation = built.value
	_state = simulation.state


func _kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for entry: AlertEntry in AlertRules.current(_state):
		kinds.append(entry.kind)
	return kinds


func test_funds_red_comes_and_goes_with_the_balance() -> void:
	_state.budget.funds_k = -10
	assert_array(_kinds()).contains([&"funds_red"])
	_state.budget.funds_k = 10
	assert_array(_kinds()).not_contains([&"funds_red"])


func test_artefact_waiting_at_the_gate() -> void:
	var record := ArtefactRecord.new()
	record.artefact = &"x"
	record.room_uid = ArtefactRecord.AT_GATE
	_state.artefacts.items.append(record)
	assert_array(_kinds()).contains([&"artefact_at_gate"])
	record.room_uid = ArtefactRecord.IN_HOLDING
	assert_array(_kinds()).not_contains([&"artefact_at_gate"])


func test_research_done_lasts_a_day_and_is_dismissible() -> void:
	_state.clock.tick = 5000
	_state.operations_log.entries.append(
		LogEntry.create(4990, &"research", &"", {"project_id": "p"})
	)
	var done: Array[AlertEntry] = AlertRules.current(_state).filter(
		func(e: AlertEntry) -> bool: return e.kind == &"research_done"
	)
	assert_int(done.size()).is_equal(1)
	assert_bool(done[0].dismissible).is_true()
	assert_str(String(done[0].view_id)).is_equal("research")
	_state.clock.tick = 4990 + AlertRules.EVENT_TICKS + 1
	assert_array(_kinds()).not_contains([&"research_done"])


func test_unassigned_staff_and_candidates() -> void:
	for person: PersonState in _state.staff.people:
		person.room_id = &""
	assert_array(_kinds()).contains([&"staff_unassigned"])
	_state.recruitment.candidates.clear()
	assert_array(_kinds()).not_contains([&"candidate_waiting"])


func test_newest_first_and_worst_severity() -> void:
	var a := AlertEntry.create(&"a", AlertEntry.INFO, &"base", 10)
	var b := AlertEntry.create(&"b", AlertEntry.ALARM, &"base", 5)
	var c := AlertEntry.create(&"c", AlertEntry.WARN, &"base", 10)
	var list: Array[AlertEntry] = [b, a, c]
	AlertRules.sort_newest_first(list)
	(
		assert_array(list.map(func(e: AlertEntry) -> StringName: return e.kind))
		. is_equal([&"c", &"a", &"b"])
	)
	assert_str(String(AlertRules.worst(list))).is_equal("alarm")
	assert_str(String(AlertRules.worst([] as Array[AlertEntry]))).is_equal("")


func test_every_kind_has_a_translated_line() -> void:
	var kinds: Array[StringName] = [
		&"lab_idle",
		&"research_done",
		&"staff_unassigned",
		&"beds_full",
		&"candidate_waiting",
		&"request_due",
		&"artefact_hazard",
		&"artefact_at_gate",
		&"site_finished",
		&"team_check_in",
		&"funds_red",
		&"rescue",
	]
	for kind: StringName in kinds:
		var key: StringName = AlertText.key_of(kind)
		assert_str(TranslationServer.translate(key)).is_not_equal(String(key))
