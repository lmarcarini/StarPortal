## Tests for the daily settlement, simulated day by day on a real new game through
## EconomySystem.on_day(): the start's $335k of costs over 30 settlements with the carry (and
## the carry across a save and load), the section 6 standing-still and in-the-red cases, the
## commendation at a settlement (before the drift) and the warnings.
## Bible: docs/content/m27-daily-rhythm.md sections 1, 2, 6 and 7
extends GdUnitTestSuite

const SEED: int = 20260101

var _defs: GameDefs


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func _new_game() -> GameState:
	var state := GameState.new_game(SEED, _defs.balance)
	assert_bool(GameSetup.build(state, _defs).is_ok).is_true()
	state.events.drain()
	return state


func _economy() -> EconomySystem:
	return EconomySystem.new(_defs.balance, _defs.rooms)


## Runs the settlements of days [param first] to [param last] (days since the start).
func _settle_days(state: GameState, first: int, last: int) -> void:
	var economy := _economy()
	for day: int in range(first, last + 1):
		state.clock.tick = day * TimeMath.TICKS_PER_DAY
		economy.on_day(state)


func _reloaded(state: GameState) -> GameState:
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	assert_bool(GameSetup.build(loaded, _defs).is_ok).is_true()
	return loaded


func _warnings(state: GameState, only: StringName = &"") -> Array[StringName]:
	var reasons: Array[StringName] = []
	for event: SimEvent in state.events.drain():
		if event.name == &"committee_warning" and (only.is_empty() or event.args[0] == only):
			reasons.append(event.args[0])
	return reasons


func test_start_pays_335k_over_30_settlements() -> void:
	var state := _new_game()
	var economy := _economy()
	assert_int(economy.costs_k(state)).is_equal(335)
	var charges: Array[int] = []
	var allocations: int = 0
	for day: int in range(1, 31):
		state.clock.tick = day * TimeMath.TICKS_PER_DAY
		var allocation: int = ConfidenceRules.daily_allocation_k(100, state.committee.whole())
		var before: int = state.budget.funds_k
		economy.on_day(state)
		allocations += allocation
		charges.append(before + allocation - state.budget.funds_k)
	assert_int(charges.count(11)).is_equal(25)
	assert_int(charges.count(12)).is_equal(5)
	assert_int(state.budget.funds_k).is_equal(6000 + allocations - 335)
	assert_int(state.committee.cost_carry).is_equal(0)
	assert_int(state.committee.funds_history.size()).is_equal(30)


func test_carry_survives_a_save_and_load() -> void:
	var straight := _new_game()
	_settle_days(straight, 1, 40)
	var split := _new_game()
	_settle_days(split, 1, 17)
	assert_int(split.committee.cost_carry).is_greater(0)
	split = _reloaded(split)
	_settle_days(split, 18, 40)
	assert_int(split.budget.funds_k).is_equal(straight.budget.funds_k)
	assert_dict(split.committee.to_dict()).is_equal(straight.committee.to_dict())


func test_standing_still_90_days_with_one_analyst() -> void:
	var state := _new_game()
	assert_int(ConfidenceRules.reporting_analysts(state)).is_equal(1)
	_settle_days(state, 1, 90)
	assert_int(state.committee.confidence).is_equal(509)
	assert_int(state.committee.days_in_red).is_equal(0)


func test_in_the_red_90_days_with_one_analyst() -> void:
	var state := _new_game()
	state.budget.funds_k = -100000
	_settle_days(state, 1, 90)
	assert_int(state.committee.confidence).is_equal(380)
	assert_int(ConfidenceRules.daily_allocation_k(100, state.committee.whole())).is_equal(88)


func test_red_warning_every_7_settlements_and_reset_at_zero() -> void:
	var state := _new_game()
	state.budget.funds_k = -100000
	_settle_days(state, 1, 6)
	assert_array(_warnings(state)).is_empty()
	_settle_days(state, 7, 7)
	assert_array(_warnings(state)).is_equal([&"red_days"])
	_settle_days(state, 8, 21)
	assert_array(_warnings(state)).is_equal([&"red_days", &"red_days"])
	state.budget.funds_k = 1000
	_settle_days(state, 22, 22)
	assert_int(state.committee.days_in_red).is_equal(0)


func test_confidence_zero_warns_once_and_rearms_above_10() -> void:
	var state := _new_game()
	state.budget.funds_k = -100000
	state.committee.confidence = 3
	_settle_days(state, 1, 5)
	assert_array(_warnings(state)).is_equal([&"confidence_zero"])
	state.committee.confidence = 105
	_settle_days(state, 6, 6)
	state.committee.confidence = 1
	_settle_days(state, 7, 7)
	var zero: StringName = ConfidenceEvents.WARN_CONFIDENCE_ZERO
	assert_array(_warnings(state, zero)).is_equal([zero])


func test_commendation_at_a_settlement_counts_before_the_drift() -> void:
	var state := _new_game()
	state.committee.confidence = 700
	var funds: int = state.budget.funds_k
	_settle_days(state, 1, 1)
	assert_int(state.committee.confidence).is_equal(699)
	assert_bool(state.committee.commendation_paid).is_true()
	var allocation: int = 120
	assert_int(state.budget.funds_k).is_equal(funds + allocation - 11 + 1000)
	state.events.drain()
	_settle_days(state, 2, 40)
	for event: SimEvent in state.events.drain():
		assert_str(String(event.name)).is_not_equal("committee_commendation")
	assert_bool(state.committee.commendation_paid).is_true()


func test_settlement_posts_one_budget_changed_and_no_log_line() -> void:
	var state := _new_game()
	var log_size: int = state.operations_log.entries.size()
	_settle_days(state, 1, 1)
	var budget_events: int = 0
	for event: SimEvent in state.events.drain():
		if event.name == &"budget_changed":
			budget_events += 1
	assert_int(budget_events).is_equal(1)
	assert_int(state.operations_log.entries.size()).is_equal(log_size)
