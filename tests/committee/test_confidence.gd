## Tests for Committee Confidence: each cause once (across mid-month reloads), the ±15 cap and
## the 0..100 bounds line, the allocation formula, the quarterly review and grant, and the
## warnings. The section 7 examples are in test_confidence_examples.gd.
## Bible: docs/content/m26-staff-and-money.md sections 4, 5, 7 and 8
extends GdUnitTestSuite

## Tick of 1 February 00:00, the first month-end.
const FEB_1: int = 31 * 1440
## Tick of 1 April 00:00, a quarter month-end.
const APR_1: int = (31 + 28 + 31) * 1440


func _game(funds_k: int = 2390) -> GameState:
	var game: GameState = ConstructionFixture.grown()
	game.clock.tick = FEB_1
	game.budget.funds_k = funds_k
	game.events.drain()
	return game


func _finish_research(game: GameState, count: int) -> void:
	for index: int in count:
		game.research.done.append(StringName("project_%d" % index))


func test_allocation_formula() -> void:
	var expected: Dictionary[int, int] = {
		0: 1500, 20: 2100, 35: 2550, 50: 3000, 64: 3420, 65: 3450, 80: 3900, 100: 4500
	}
	for confidence: int in expected:
		assert_int(ConfidenceRules.allocation_k(3000, confidence)).is_equal(expected[confidence])


func test_starting_confidence_is_50_and_idle_month_scores_minus_1() -> void:
	var game := _game()
	assert_int(game.committee.confidence).is_equal(50)
	var report := MonthEnd.close(game, 3000, 270)
	assert_int(report.allocation_k).is_equal(3000)
	assert_array(report.applied_causes()).is_equal([&"reports", &"within_budget", &"idle"])
	assert_int(report.confidence_after).is_equal(49)
	assert_int(report.next_allocation_k).is_equal(2970)


func test_each_cause_counts_once() -> void:
	var game := _game()
	game.worlds.statuses[&"sill"] = WorldsState.WorldStatus.LOCKED
	game.worlds.horizon_records[&"sill"] = true
	_finish_research(game, 1)
	var first := MonthEnd.close(game, 3000, 0)
	assert_int(first.amount_of(&"surveyed")).is_equal(2)
	assert_array(first.locked_worlds).is_equal([&"sill"])
	var second := MonthEnd.close(game, 3000, 0)
	assert_int(second.count_of(&"locked")).is_equal(0)
	assert_int(second.count_of(&"surveyed")).is_equal(0)
	assert_int(second.count_of(&"research")).is_equal(0)
	assert_int(second.amount_of(&"idle")).is_equal(-4)


func test_analyst_counts_only_in_a_control_room_that_is_on() -> void:
	var game := _game()
	assert_int(ConfidenceRules.reporting_analysts(game)).is_equal(1)
	for room: RoomState in game.base.rooms:
		if room.def_id == &"room_control":
			room.powered_on = false
	assert_int(ConfidenceRules.reporting_analysts(game)).is_equal(0)


func test_cap_down_and_bounds() -> void:
	assert_int(ConfidenceRules.capped(-20)).is_equal(-15)
	assert_int(ConfidenceRules.changed(5, -15)).is_equal(0)
	assert_int(ConfidenceRules.changed(95, 15)).is_equal(100)


func test_in_red_three_months_and_zero_only_warn() -> void:
	var game := _game(-100000)
	game.committee.confidence = 6
	for month: int in 3:
		var report := MonthEnd.close(game, 3000, 0)
		assert_int(report.amount_of(&"in_red")).is_equal(-5)
		assert_int(report.months_in_red).is_equal(month + 1)
	var report := game.committee.latest_report()
	assert_bool(report.warn_red_months).is_true()
	assert_bool(report.warn_confidence_zero).is_true()
	assert_int(game.committee.confidence).is_equal(0)
	var names: Array[StringName] = []
	for event: SimEvent in game.events.drain():
		names.append(event.name)
	assert_array(names).contains([&"committee_warning", &"month_report_filed"])
	assert_array(names).not_contains([&"pause_requested"])
	game.budget.funds_k = 100000
	assert_int(MonthEnd.close(game, 3000, 0).months_in_red).is_equal(0)


func test_quarterly_review_grant_after_budget_check() -> void:
	var game := _game(-4000)
	game.clock.tick = APR_1
	game.committee.confidence = 75
	var report := MonthEnd.close(game, 3000, 0)
	var salaries: int = report.salaries_k
	assert_int(report.amount_of(&"in_red")).is_equal(-5)
	assert_int(report.confidence_after).is_equal(67)
	assert_str(String(report.review)).is_equal("notes")
	assert_int(report.grant_k).is_equal(0)
	game.committee.confidence = 80
	game.budget.funds_k = 0
	var pleased := MonthEnd.close(game, 3000, 0)
	assert_str(String(pleased.review)).is_equal("pleased")
	assert_int(pleased.grant_k).is_equal(1000)
	assert_int(game.budget.funds_k).is_equal(3900 - salaries + 1000)
	assert_str(String(ConfidenceRules.review_of(29))).is_equal("questions")


func test_no_review_outside_quarter_months() -> void:
	var game := _game()
	game.committee.confidence = 90
	assert_str(String(MonthEnd.close(game, 3000, 0).review)).is_empty()


func test_reports_kept_and_saved() -> void:
	var game := _game()
	game.worlds.statuses[&"sill"] = WorldsState.WorldStatus.LOCKED
	for month: int in 8:
		MonthEnd.close(game, 3000, 0)
	assert_int(game.committee.reports.size()).is_equal(ConfidenceRules.REPORTS_KEPT)
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	assert_dict(loaded.committee.to_dict()).is_equal(game.committee.to_dict())


func test_bad_committee_data_is_refused() -> void:
	var data: Dictionary = CommitteeState.new().to_dict()
	data["confidence"] = 101
	assert_array(CommitteeState.validate_dict(data)).is_not_empty()
	data = CommitteeState.new().to_dict()
	data["reports"] = [{"year": 1}]
	assert_array(CommitteeState.validate_dict(data)).is_not_empty()


func test_bounds_line_when_the_range_cuts_the_change() -> void:
	var game := _game()
	game.committee.confidence = 3
	var report := MonthEnd.close(game, 3000, 0)
	assert_int(report.amount_of(&"idle") + report.amount_of(&"reports")).is_equal(-3)
	assert_int(report.amount_of(&"within_budget")).is_equal(2)
	assert_int(report.confidence_after).is_equal(2)
	assert_int(report.amount_of(&"bounds")).is_equal(0)
	game.committee.confidence = 0
	var cut := MonthEnd.close(game, 3000, 0)
	assert_int(cut.confidence_after).is_equal(0)
	assert_int(cut.amount_of(&"bounds")).is_equal(1)
	var total: int = 0
	for amount: int in cut.amounts:
		total += amount
	assert_int(total).is_equal(cut.confidence_after - cut.confidence_before)
	game.committee.confidence = 99
	game.worlds.statuses[&"world_a"] = WorldsState.WorldStatus.LOCKED
	var top := MonthEnd.close(game, 3000, 0)
	assert_int(top.confidence_after).is_equal(100)
	assert_int(top.amount_of(&"bounds")).is_equal(-7)


func _reloaded(game: GameState) -> GameState:
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	loaded.room_defs = game.room_defs
	return loaded


## A lock (day 5), a survey and a project (day 15), with a save and load on day 10 and day 20:
## each counts once at the month-end, and never again after another reload.
func test_mid_month_reloads_count_each_cause_once() -> void:
	var game := _game()
	game.clock.tick = 4 * 1440
	game.worlds.statuses[&"world_sill"] = WorldsState.WorldStatus.LOCKED
	game.clock.tick = 9 * 1440
	game = _reloaded(game)
	game.clock.tick = 14 * 1440
	game.worlds.horizon_records[&"world_sill"] = true
	game.research.done.append(&"excavation_survey")
	game.clock.tick = 19 * 1440
	game = _reloaded(game)
	game.clock.tick = FEB_1
	var report := MonthEnd.close(game, 3000, 0)
	assert_int(report.amount_of(&"locked")).is_equal(5)
	assert_int(report.amount_of(&"surveyed")).is_equal(2)
	assert_int(report.amount_of(&"research")).is_equal(3)
	game.clock.tick = FEB_1 + 9 * 1440
	game = _reloaded(game)
	var next := MonthEnd.close(game, 3000, 0)
	assert_int(next.count_of(&"locked") + next.count_of(&"surveyed")).is_equal(0)
	assert_int(next.count_of(&"research")).is_equal(0)
	assert_int(next.amount_of(&"idle")).is_equal(-4)


func test_saved_report_confidence_out_of_range_is_refused() -> void:
	var data: Dictionary = MonthReport.blank().to_dict()
	assert_array(MonthReport.validate_dict(data)).is_empty()
	data["confidence_after"] = 101
	assert_array(MonthReport.validate_dict(data)).is_not_empty()
	data["confidence_after"] = 50
	data["confidence_before"] = -1
	assert_array(MonthReport.validate_dict(data)).is_not_empty()
