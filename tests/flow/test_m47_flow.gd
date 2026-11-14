## The M4.7 flow end to end at 10× cruise: dial (slow), lock and operate (slow), pole camera,
## Stand by (10×), a waiting call (slow), answer it (slow), hang up (10×), an incoming wormhole
## that expires (10×), and an override during a waiting call. The cruise speed never changes.
## Bible: docs/content/event-time.md
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const ConversationTests := preload("res://tests/dialog/test_conversation_runner.gd")
const CRUISE: int = 3
const SLOW: int = ClockState.NORMAL_SPEED_INDEX

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = DialFixture.state(null, false)
	_state.conversation_defs[ConversationTests.CONV] = ConversationTests.make_def()
	var systems: Array[SimSystem] = [
		PowerSystem.new(_state.balance), GateSystem.new(), ConversationSystem.new()
	]
	_simulation = Simulation.new(_state, systems)
	_state.clock.speed_index = CRUISE


func _speed() -> int:
	return TimeControl.effective_speed_index(_state.clock)


func _run(ticks: int) -> void:
	for index: int in ticks:
		_simulation.advance_tick()


func _do(command: Command) -> void:
	var result: CommandResult = _simulation.submit(command)
	assert_bool(result.is_ok).override_failure_message(str(result.error_code)).is_true()
	_run(1)


func _call(until_tick: int) -> void:
	var contact := PendingContact.new()
	contact.faction = &"faction_kindred"
	contact.conversation = ConversationTests.CONV
	contact.channel = &"phone"
	contact.expires_tick = until_tick
	_state.factions.pending.append(contact)
	_run(1)


func test_event_time_flow() -> void:
	# Dial: slow from the first seal to the lock.
	var address: GateAddress = DialFixture.address_of(_state.galaxy, DialFixture.OPEN_ID)
	_do(DialCommand.create(address))
	assert_int(_speed()).is_equal(SLOW)
	_run(_state.balance.dial_duration_ticks)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	# The lock brings the panel up (the shell sends Operate): slow.
	_do(OperateGateCommand.new())
	assert_int(_speed()).is_equal(SLOW)
	_do(ExtendPoleCameraCommand.new())
	assert_int(_speed()).is_equal(SLOW)
	# Stand by: 10× with the wormhole open.
	_do(StandByCommand.new())
	assert_int(_speed()).is_equal(CRUISE)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	RingControl.close(_state.gate)
	_run(1)
	# A waiting call slows; answering keeps it slow; hanging up gives 10× back.
	_call(99999)
	assert_int(_speed()).is_equal(SLOW)
	_do(AnswerCallCommand.new())
	assert_int(_speed()).is_equal(SLOW)
	_do(EndConversationCommand.new())
	assert_int(_speed()).is_equal(CRUISE)
	# An incoming wormhole waits (slow) and expires: 10×.
	_state.gate.incoming_faction = &"faction_kindred"
	_state.gate.incoming_conversation = ConversationTests.CONV
	_state.gate.incoming_until_tick = _state.clock.tick + 3
	_run(1)
	assert_int(_speed()).is_equal(SLOW)
	_run(5)
	assert_bool(_state.gate.has_incoming()).is_false()
	assert_int(_speed()).is_equal(CRUISE)
	# Override during a waiting call: 10× while it still waits.
	_call(99999)
	assert_int(_speed()).is_equal(SLOW)
	_do(OverrideSlowCommand.create())
	_run(3)
	assert_int(_speed()).is_equal(CRUISE)
	assert_bool(_state.factions.pending.is_empty()).is_false()
	assert_int(_state.clock.speed_index).is_equal(CRUISE)
