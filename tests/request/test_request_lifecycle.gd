## Tests for the request lifecycle (M4-15): every transition with its effects exactly once,
## the deadline boundary, deadline_succeeds, refusals with codes, one open instance per request
## and a save between offer and deadline.
## Bible: docs/content/m4-core-systems.md section 4
extends GdUnitTestSuite

const REQUEST: StringName = &"request_survey"

var _state: GameState
var _simulation: Simulation
var _def: RequestDef


static func _money(amount_k: int) -> Array[EffectDef]:
	var effect := ChangeMoneyEffect.new()
	effect.amount_k = amount_k
	var effects: Array[EffectDef] = [effect]
	return effects


func before_test() -> void:
	_state = StoryFixture.state()
	_state.budget.funds_k = 0
	_state.clock.mode = ClockState.Mode.RUNNING
	_def = RequestDef.new()
	_def.id = REQUEST
	_def.offer_days = 2
	_def.deadline_days = 3
	var flag := FlagIsCondition.new()
	flag.flag = &"surveyed"
	_def.objective.append(flag)
	_def.reward = _money(100)
	_def.penalty = _money(-10)
	_def.on_decline = _money(-1)
	_state.request_defs[REQUEST] = _def
	_simulation = Simulation.new(_state, [RequestSystem.new()])


func _offer() -> RequestRecord:
	StoryRulesItems.offer_request(_state, REQUEST)
	return _state.requests.items[-1]


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func test_accept_then_fulfil_once() -> void:
	var record: RequestRecord = _offer()
	assert_bool(_simulation.submit(AcceptRequestCommand.new(record.uid)).is_ok).is_true()
	_ticks(1)
	assert_int(record.state).is_equal(RequestRecord.RequestState.ACTIVE)
	assert_int(record.deadline_tick).is_equal(3 * TimeMath.TICKS_PER_DAY)
	_state.flags[&"surveyed"] = true
	_ticks(3)
	assert_int(record.state).is_equal(RequestRecord.RequestState.FULFILLED)
	assert_int(record.closed_tick).is_equal(1)
	assert_int(_state.budget.funds_k).is_equal(100)


func test_deadline_boundary_fails() -> void:
	var record: RequestRecord = _offer()
	RequestRules.accept(_state, record.uid)
	_state.clock.tick = record.deadline_tick - 1
	RequestRules.check_all(_state)
	assert_int(record.state).is_equal(RequestRecord.RequestState.ACTIVE)
	_state.clock.tick = record.deadline_tick
	RequestRules.check_all(_state)
	RequestRules.check_all(_state)
	assert_int(record.state).is_equal(RequestRecord.RequestState.FAILED)
	assert_int(_state.budget.funds_k).is_equal(-10)


func test_deadline_succeeds() -> void:
	_def.deadline_succeeds = true
	var since := StampFlagEffect.new()
	since.flag = &"closed_since"
	_def.on_accept = [since]
	var no_dial := NoDialSinceCondition.new()
	no_dial.flag = &"closed_since"
	_def.objective = [no_dial]
	var record: RequestRecord = _offer()
	_state.clock.tick = 100
	RequestRules.accept(_state, record.uid)
	assert_int(_state.flags[&"closed_since"]).is_equal(100)
	RequestRules.check_all(_state)
	assert_int(record.state).is_equal(RequestRecord.RequestState.ACTIVE)
	_state.clock.tick = record.deadline_tick
	RequestRules.check_all(_state)
	assert_int(record.state).is_equal(RequestRecord.RequestState.FULFILLED)
	var second: RequestRecord = _offer()
	RequestRules.accept(_state, second.uid)
	_state.gate.dial_started_tick = _state.clock.tick + 5
	_state.clock.tick = second.deadline_tick
	RequestRules.check_all(_state)
	assert_int(second.state).is_equal(RequestRecord.RequestState.FAILED)


func test_decline_and_lapse() -> void:
	var record: RequestRecord = _offer()
	assert_bool(_simulation.submit(DeclineRequestCommand.new(record.uid)).is_ok).is_true()
	_ticks(1)
	assert_int(record.state).is_equal(RequestRecord.RequestState.DECLINED)
	assert_int(_state.budget.funds_k).is_equal(-1)
	var second: RequestRecord = _offer()
	_state.clock.tick = second.offered_tick + 2 * TimeMath.TICKS_PER_DAY - 1
	RequestRules.check_all(_state)
	assert_int(second.state).is_equal(RequestRecord.RequestState.OFFERED)
	_state.clock.tick += 1
	RequestRules.check_all(_state)
	assert_int(second.state).is_equal(RequestRecord.RequestState.LAPSED)
	assert_int(_state.budget.funds_k).is_equal(-2)


func test_refusals_and_one_open_instance() -> void:
	var record: RequestRecord = _offer()
	assert_int(StoryRulesItems.offer_request(_state, REQUEST)).is_equal(-1)
	assert_int(_state.requests.items.size()).is_equal(1)
	assert_str(String(AcceptRequestCommand.new(99).validate(_state).error_code)).is_equal(
		"no_such_request"
	)
	RequestRules.accept(_state, record.uid)
	assert_str(String(DeclineRequestCommand.new(record.uid).validate(_state).error_code)).is_equal(
		"not_offered"
	)
	assert_int(StoryRulesItems.offer_request(_state, REQUEST)).is_equal(-1)
	_state.flags[&"surveyed"] = true
	RequestRules.check_all(_state)
	assert_int(StoryRulesItems.offer_request(_state, REQUEST)).is_equal(1)


func test_save_between_offer_and_deadline() -> void:
	var record: RequestRecord = _offer()
	RequestRules.accept(_state, record.uid)
	_ticks(10)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	GameSetup.build(loaded, GameDefs.from_registry(Registry))
	loaded.request_defs[REQUEST] = _def
	var other := Simulation.new(loaded, [RequestSystem.new()])
	_state.clock.tick = record.deadline_tick - 2
	loaded.clock.tick = record.deadline_tick - 2
	for index: int in 4:
		_simulation.advance_tick()
		other.advance_tick()
	assert_str(JSON.stringify(loaded.to_dict())).is_equal(JSON.stringify(_state.to_dict()))
	assert_int(loaded.requests.items[0].state).is_equal(RequestRecord.RequestState.FAILED)


func test_log_line() -> void:
	TranslationServer.set_locale("en")
	var record: RequestRecord = _offer()
	RequestRules.decline(_state, record.uid)
	var entries: Array[LogEntry] = RequestLog.entries(
		[record.uid, RequestRecord.RequestState.DECLINED], _state, 5
	)
	assert_str(ArchiveLogRow.line_for(entries[0], _state)).is_equal(
		"Request declined: request_survey."
	)
