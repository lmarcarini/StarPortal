## Tests for Committee Confidence events (applied at once, each once, across reloads), the
## rolling cause list, the drift and allocation rules, the commendation and the saved shape.
## The daily settlement over many days is in test_daily_settlement.gd.
## Bible: docs/content/m27-daily-rhythm.md sections 1, 2 and 7
extends GdUnitTestSuite


func _game() -> GameState:
	var game: GameState = ConstructionFixture.grown()
	game.clock.tick = 3 * TimeMath.TICKS_PER_DAY
	game.events.drain()
	return game


func _names(game: GameState) -> Array[StringName]:
	var names: Array[StringName] = []
	for event: SimEvent in game.events.drain():
		names.append(event.name)
	return names


func _reloaded(game: GameState) -> GameState:
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	loaded.room_defs = game.room_defs
	return loaded


func test_daily_allocation_formula() -> void:
	var expected: Dictionary[int, int] = {
		0: 50, 20: 70, 35: 85, 50: 100, 65: 115, 80: 130, 100: 150
	}
	for confidence: int in expected:
		assert_int(ConfidenceRules.daily_allocation_k(100, confidence)).is_equal(
			expected[confidence]
		)


func test_drift_settles_toward_50_and_falls_in_the_red() -> void:
	assert_int(ConfidenceRules.drift(614, false)).is_equal(-1)
	assert_int(ConfidenceRules.drift(386, false)).is_equal(1)
	assert_int(ConfidenceRules.drift(500, false)).is_equal(0)
	assert_int(ConfidenceRules.drift(500, true)).is_equal(-2)
	assert_int(ConfidenceRules.changed(1, -2)).is_equal(0)
	assert_int(ConfidenceRules.changed(995, 50)).is_equal(1000)


func test_report_days_are_every_15th_day() -> void:
	var days: Array[int] = []
	for day: int in range(1, 61):
		if ConfidenceRules.is_report_day(day):
			days.append(day)
	assert_array(days).is_equal([14, 29, 44, 59])


func test_events_apply_at_once_and_count_once() -> void:
	var game := _game()
	game.worlds.statuses[&"world_sill"] = WorldsState.WorldStatus.LOCKED
	ConfidenceEvents.credit_new(game)
	assert_int(game.committee.confidence).is_equal(550)
	game.worlds.horizon_records[&"world_sill"] = true
	game.research.done.append(&"excavation_survey")
	ConfidenceEvents.credit_new(game)
	assert_int(game.committee.confidence).is_equal(600)
	ConfidenceEvents.credit_new(game)
	assert_int(game.committee.confidence).is_equal(600)
	assert_array(_names(game)).contains([&"confidence_changed"])
	var causes: Array[StringName] = []
	for cause: ConfidenceCause in game.committee.causes:
		causes.append(cause.cause)
	assert_array(causes).is_equal([&"locked", &"surveyed", &"research"])
	assert_int(game.committee.causes[0].change).is_equal(50)
	assert_str(String(game.committee.causes[0].subject)).is_equal("world_sill")


func test_reload_never_counts_an_event_twice() -> void:
	var game := _game()
	game.worlds.statuses[&"world_sill"] = WorldsState.WorldStatus.LOCKED
	ConfidenceEvents.credit_new(game)
	game = _reloaded(game)
	ConfidenceEvents.credit_new(game)
	assert_int(game.committee.confidence).is_equal(550)
	assert_int(game.committee.causes.size()).is_equal(1)


func test_reports_need_an_analyst_in_a_control_room_that_is_on() -> void:
	var game := _game()
	ConfidenceEvents.file_reports(game)
	assert_int(game.committee.confidence).is_equal(510)
	assert_array(_names(game)).contains([&"reports_filed"])
	for room: RoomState in game.base.rooms:
		if room.def_id == &"room_control":
			room.powered_on = false
	ConfidenceEvents.file_reports(game)
	assert_int(game.committee.confidence).is_equal(510)


func test_cause_list_keeps_the_last_ten() -> void:
	var game := _game()
	for index: int in 12:
		game.research.done.append(StringName("project_%d" % index))
		ConfidenceEvents.credit_new(game)
	assert_int(game.committee.causes.size()).is_equal(ConfidenceRules.CAUSES_KEPT)
	assert_str(String(game.committee.causes[0].subject)).is_equal("project_2")


func test_commendation_on_an_event_pays_once_and_rearms_below_60() -> void:
	var game := _game()
	var funds: int = game.budget.funds_k
	game.committee.confidence = 690
	ConfidenceEvents.raise(game, &"research", &"a", Vector2i(1, 30))
	assert_int(game.budget.funds_k).is_equal(funds + 1000)
	assert_array(_names(game)).contains([&"committee_commendation", &"budget_changed"])
	ConfidenceEvents.raise(game, &"research", &"b", Vector2i(1, 30))
	game.committee.confidence = 650
	ConfidenceEvents.raise(game, &"research", &"c", Vector2i(1, 60))
	assert_int(game.budget.funds_k).is_equal(funds + 1000)
	game.committee.confidence = 599
	ConfidenceEvents.check_commendation(game)
	assert_bool(game.committee.commendation_paid).is_false()
	ConfidenceEvents.raise(game, &"research", &"d", Vector2i(1, 110))
	assert_int(game.budget.funds_k).is_equal(funds + 2000)


func test_committee_state_round_trips() -> void:
	var game := _game()
	game.worlds.statuses[&"world_sill"] = WorldsState.WorldStatus.LOCKED
	ConfidenceEvents.credit_new(game)
	game.committee.cost_carry = 17
	game.committee.days_in_red = 3
	game.committee.zero_warned = true
	game.committee.add_funds_record(-40)
	var loaded := _reloaded(game)
	assert_dict(loaded.committee.to_dict()).is_equal(game.committee.to_dict())


func test_bad_committee_data_is_refused() -> void:
	var cases: Array[Dictionary] = [
		{"confidence": 1001},
		{"confidence": 50.5},
		{"cost_carry": 30},
		{"commendation_paid": 1},
		{"funds_history": [1, 2.5]},
		{"causes": [{"tick": 0, "cause": "idle", "subject": "", "count": 1, "change": 1}]},
		{"months_in_red": 0, "days_in_red": -1},
	]
	for change: Dictionary in cases:
		var data: Dictionary = CommitteeState.new().to_dict()
		data.merge(change, true)
		assert_array(CommitteeState.validate_dict(data)).is_not_empty()
	assert_array(CommitteeState.validate_dict(CommitteeState.new().to_dict())).is_empty()
