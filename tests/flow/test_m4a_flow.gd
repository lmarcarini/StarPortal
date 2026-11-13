## The M4a loop through commands on the real content (M4-20): the Committee's call on day 2
## files both addresses and offers the HEARTH survey; dial HEARTH, hail the Kindred and answer;
## accept and fulfil the survey and see the reward; an Ossar incoming wormhole answered and one
## ignored; a conversation cut off by closing the wormhole; transcripts in the Archive.
## Bible: docs/content/m4-core-systems.md sections 2 to 4 and 8
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const PowerFixture := preload("res://tests/power/power_fixture.gd")

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_state = GameState.new_game(7, defs.balance)
	_simulation = GameSetup.build_new(_state, defs).value
	_state.clock.mode = ClockState.Mode.RUNNING


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func _submit(command: Command) -> void:
	var result: CommandResult = _simulation.submit(command)
	(
		assert_bool(result.is_ok)
		. override_failure_message("%s refused: %s" % [command.get_type(), result.error_code])
		. is_true()
	)
	_ticks(1)


## Lines advance by themselves; at each choice take the first enabled answer.
func _talk_to_the_end() -> void:
	for guard: int in 200:
		if _state.conversations.active == null:
			return
		for choice: Dictionary in ConversationRules.choices(_state):
			if choice["enabled"]:
				var index: int = choice["index"]
				_submit(ChooseOptionCommand.new(index))
				break
		_ticks(1)


## Builds the first Capacitor Bank and waits until it holds charge.
func _build_bank() -> void:
	_submit(PowerFixture.build_first_bank(_state))
	for guard: int in 30 * TimeMath.TICKS_PER_DAY:
		if PowerRules.capacity_of(_state, PowerRules.totals(_state)) > 0.0:
			return
		_ticks(1)


func _dial(world: StringName) -> void:
	_state.power.stored_mwh = PowerRules.capacity_of(_state, PowerRules.totals(_state))
	_submit(DialCommand.create(DialFixture.address_of(_state.galaxy, world)))
	_ticks(_state.balance.dial_duration_ticks + 1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)


func test_m4a_loop() -> void:
	_ticks(TimeMath.TICKS_PER_DAY + 1)
	assert_int(ContactRules.next_pending(_state, &"phone")).is_equal(0)
	var books: int = _state.address_book.entries.size()
	_submit(AnswerCallCommand.new())
	_talk_to_the_end()
	assert_int(_state.address_book.entries.size()).is_equal(books + 2)
	var survey: RequestRecord = _state.requests.items[0]
	_submit(AcceptRequestCommand.new(survey.uid))
	assert_int(survey.state).is_equal(RequestRecord.RequestState.ACTIVE)
	_build_bank()
	_dial(&"world_hearth")
	_submit(HailCommand.new())
	assert_array(_state.factions.met).contains([&"faction_kindred"])
	_talk_to_the_end()
	assert_bool(_state.conversations.transcripts[-1].cut_off).is_false()
	var funds: int = _state.budget.funds_k
	WorldProgress.raise_status(_state, &"world_hearth", WorldsState.WorldStatus.SURVEYED)
	_ticks(1)
	assert_int(survey.state).is_equal(RequestRecord.RequestState.FULFILLED)
	assert_int(_state.budget.funds_k).is_equal(funds + 500)
	_submit(CloseWormholeCommand.new())
	# An Ossar incoming wormhole: answered, then another ignored.
	_submit(DebugStoryCommand.create(&"contact", &"conv_ossar_demand"))
	_ticks(1)
	assert_bool(_state.gate.has_incoming()).is_true()
	_submit(AnswerIncomingCommand.new())
	assert_str(String(_state.gate.connected_world_id)).is_equal("world_tollgate")
	_talk_to_the_end()
	_submit(CloseWormholeCommand.new())
	var standing: int = FactionRules.standing(_state, &"faction_ossar")
	_submit(DebugStoryCommand.create(&"contact", &"conv_ossar_demand"))
	_ticks(1)
	_submit(IgnoreIncomingCommand.new())
	assert_int(FactionRules.standing(_state, &"faction_ossar")).is_equal(standing - 2)
	# A hail cut off by closing the wormhole.
	_dial(&"world_tollgate")
	_submit(HailCommand.new())
	_submit(CloseWormholeCommand.new())
	_ticks(1)
	assert_bool(_state.conversations.transcripts[-1].cut_off).is_true()
	for record: TranscriptRecord in _state.conversations.transcripts:
		assert_bool(_state.archive.has_document(TranscriptText.archive_id(record.uid))).is_true()
	assert_int(_state.conversations.transcripts.size()).is_greater_equal(4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
