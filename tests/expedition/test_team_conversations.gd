## Tests for team talk as conversations (M4.9-15): a hail opens the hail conversation with the
## team leader, its answers are the orders (Come home now walks the team through), and an
## answered distress call opens the distress conversation whose Hold on ends the call.
## Bible: docs/content/interface-rethink.md section 4 (A team can only talk through an open gate)
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const DAY: int = TimeMath.TICKS_PER_DAY

var _state: GameState


func before_test() -> void:
	_state = Fixture.state()
	for id: StringName in [TeamContactRules.HAIL_CONVERSATION, TeamContactRules.CALL_CONVERSATION]:
		var path: String = "res://data/conversations/%s.tres" % id
		_state.conversation_defs[id] = load(path) as ConversationDef


func _simulation(missed_day: int = -1) -> Simulation:
	var simulation: Simulation = RescueFixture.simulation(_state, missed_day)
	RescueFixture.send(simulation)
	simulation.submit(CloseWormholeCommand.new())
	return simulation


## Advances to the choice, picks [param index], then talks to the end and closes.
func _answer(simulation: Simulation, index: int) -> void:
	for guard: int in 20:
		var active: ActiveConversation = _state.conversations.active
		if active == null:
			return
		if active.phase == ActiveConversation.Phase.CHOICE:
			assert_bool(simulation.submit(ChooseOptionCommand.new(index)).is_ok).is_true()
		else:
			assert_bool(simulation.submit(AdvanceConversationCommand.new()).is_ok).is_true()


func test_hail_opens_the_conversation_and_come_home_is_an_answer() -> void:
	var simulation: Simulation = _simulation()
	Fixture.advance(simulation, 60)
	ProbeFixture.open(simulation)
	assert_bool(simulation.submit(HailTeamCommand.new()).is_ok).is_true()
	var active: ActiveConversation = _state.conversations.active
	assert_object(active).is_not_null()
	assert_str(String(active.conversation)).is_equal(String(TeamContactRules.HAIL_CONVERSATION))
	_answer(simulation, TeamContactRules.Order.COME_HOME)
	assert_object(_state.conversations.active).is_null()
	assert_bool(_state.expedition.coming_home).is_true()


func test_distress_call_hold_on_ends_the_call() -> void:
	var simulation: Simulation = _simulation(0)
	Fixture.advance(simulation, DAY + 3)
	assert_bool(_state.gate.has_incoming()).is_true()
	assert_bool(simulation.submit(AnswerIncomingCommand.new()).is_ok).is_true()
	var active: ActiveConversation = _state.conversations.active
	assert_str(String(active.conversation)).is_equal(String(TeamContactRules.CALL_CONVERSATION))
	_answer(simulation, 1)
	assert_object(_state.conversations.active).is_null()
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
