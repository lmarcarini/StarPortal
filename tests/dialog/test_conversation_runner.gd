## Tests for the conversation runner (M4-08, M4.8-02): a conversation holds the clock from its
## start to its close, lines move on by AdvanceConversationCommand, choices come by command and
## are checked, End applies its effects and ends the link, closing records the transcript and
## releases the clock, a cut-off ends it as signal lost, a save at any phase loads back, and
## pick() chooses the best available conversation.
## Bible: docs/content/m4-core-systems.md section 3, docs/content/dialogue-screen.md
## sections 2 and 7
extends GdUnitTestSuite

const CONV: StringName = &"conv_test"

var _state: GameState
var _simulation: Simulation


static func _effect_money(amount_k: int) -> ChangeMoneyEffect:
	var effect := ChangeMoneyEffect.new()
	effect.amount_k = amount_k
	return effect


static func _line(id: StringName, next: StringName) -> ConversationNodeDef:
	var node := ConversationNodeDef.new()
	node.id = id
	node.text_key = &"K"
	node.next = next
	return node


## l1 (+1k) → l2 → l3 → ask → [0: locked unless met, show_locked;
## 1: +10k → end (+100k)].
static func make_def() -> ConversationDef:
	var def := ConversationDef.new()
	def.id = CONV
	def.faction = &"faction_kindred"
	def.channels = [&"wormhole"]
	def.start = &"l1"
	var l1: ConversationNodeDef = _line(&"l1", &"l2")
	l1.effects.append(_effect_money(1))
	var ask := ConversationNodeDef.new()
	ask.id = &"ask"
	ask.kind = ConversationNodeDef.Kind.CHOICE
	var locked := ConversationChoiceDef.new()
	var met := FactionMetCondition.new()
	met.faction = &"faction_kindred"
	locked.conditions.append(met)
	locked.show_locked = true
	locked.next = &"end"
	var plain := ConversationChoiceDef.new()
	plain.effects.append(_effect_money(10))
	plain.next = &"end"
	ask.choices.append(locked)
	ask.choices.append(plain)
	var end := ConversationNodeDef.new()
	end.id = &"end"
	end.kind = ConversationNodeDef.Kind.END
	end.effects.append(_effect_money(100))
	def.nodes = [l1, _line(&"l2", &"l3"), _line(&"l3", &"ask"), ask, end]
	return def


func before_test() -> void:
	_state = StoryFixture.state()
	_state.conversation_defs[CONV] = make_def()
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.budget.funds_k = 0
	_state.clock.mode = ClockState.Mode.RUNNING
	_simulation = Simulation.new(_state, [ConversationSystem.new()])


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func _node() -> String:
	return String(_state.conversations.active.node)


func _phase() -> ActiveConversation.Phase:
	return _state.conversations.active.phase


func _advance() -> CommandResult:
	return _simulation.submit(AdvanceConversationCommand.new())


func _error(result: CommandResult) -> String:
	return String(result.error_code)


## Starts CONV and advances to the choice.
func _to_choice() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"world_lintel")
	for index: int in 4:
		_advance()


func test_start_holds_the_clock_and_opens() -> void:
	_state.clock.speed_index = ClockState.NORMAL_SPEED_INDEX + 2
	assert_bool(ConversationRules.start(_state, CONV, &"wormhole", &"world_lintel")).is_true()
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.HELD)
	assert_array(_state.clock.holds).contains([ConversationRules.HOLD])
	assert_bool(_state.clock.slows.is_empty()).is_true()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.OPENING)
	assert_int(_state.budget.funds_k).is_equal(0)
	assert_bool(ConversationRules.start(_state, CONV, &"wormhole", &"")).is_false()


func test_lines_advance_by_command() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"world_lintel")
	assert_bool(_advance().is_ok).is_true()
	assert_str(_node()).is_equal("l1")
	assert_int(_phase()).is_equal(ActiveConversation.Phase.LINE)
	assert_int(_state.budget.funds_k).is_equal(1)
	_advance()
	assert_str(_node()).is_equal("l2")
	_advance()
	_advance()
	assert_str(_node()).is_equal("ask")
	assert_int(_phase()).is_equal(ActiveConversation.Phase.CHOICE)
	assert_str(_error(_advance())).is_equal("needs_choice")
	assert_str(_node()).is_equal("ask")


func test_no_tick_runs_across_a_whole_conversation() -> void:
	_state.clock.speed_index = ClockState.NORMAL_SPEED_INDEX + 2
	var tick: int = _state.clock.tick
	var funds_before: int = _state.budget.funds_k
	_simulation.submit(HailCommandFake.new())
	_ticks(1)
	assert_int(_state.clock.tick).is_equal(tick)
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.HELD)
	for index: int in 4:
		_advance()
	_simulation.submit(ChooseOptionCommand.new(1))
	assert_int(_phase()).is_equal(ActiveConversation.Phase.ENDED)
	assert_int(_state.clock.tick).is_equal(tick)
	assert_int(_state.budget.funds_k).is_equal(funds_before + 111)
	assert_bool(_advance().is_ok).is_true()
	assert_object(_state.conversations.active).is_null()
	assert_int(_state.clock.tick).is_equal(tick)
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.RUNNING)
	assert_int(_state.clock.speed_index).is_equal(ClockState.NORMAL_SPEED_INDEX + 2)
	_ticks(1)
	assert_int(_state.clock.tick).is_equal(tick + 1)


func test_closing_returns_to_a_paused_clock() -> void:
	_state.clock.mode = ClockState.Mode.PAUSED
	_to_choice()
	TimeControl.request_resume(_state.clock)
	TimeControl.request_pause(_state.clock)
	_simulation.submit(ChooseOptionCommand.new(1))
	_advance()
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.PAUSED)


func test_choices_end_and_close() -> void:
	_to_choice()
	var shown: Array[Dictionary] = ConversationRules.choices(_state)
	assert_int(shown.size()).is_equal(2)
	assert_bool(shown[0]["enabled"]).is_false()
	assert_bool(shown[0]["reason"] is FactionMetCondition).is_true()
	assert_str(_error(_simulation.submit(ChooseOptionCommand.new(0)))).is_equal("choice_locked")
	assert_str(_error(_simulation.submit(ChooseOptionCommand.new(5)))).is_equal("no_such_choice")
	assert_bool(_simulation.submit(ChooseOptionCommand.new(1)).is_ok).is_true()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.ENDED)
	assert_bool(_state.conversations.active.cut_off).is_false()
	assert_int(_state.budget.funds_k).is_equal(111)
	assert_int(_state.conversations.transcripts.size()).is_equal(0)
	assert_str(_error(_simulation.submit(ChooseOptionCommand.new(1)))).is_equal("not_at_choice")
	_advance()
	assert_object(_state.conversations.active).is_null()
	var record: TranscriptRecord = _state.conversations.transcripts[0]
	assert_bool(record.cut_off).is_false()
	assert_int(record.path.size()).is_equal(5)
	assert_int(record.path[3][1]).is_equal(1)
	assert_int(_state.conversations.count[CONV]).is_equal(1)
	assert_str(_error(_advance())).is_equal("no_conversation")
	assert_str(_error(_simulation.submit(ChooseOptionCommand.new(1)))).is_equal("no_conversation")


func test_a_held_wormhole_cannot_be_cut_by_ticks_of_the_clock() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	_advance()
	var tick: int = _state.clock.tick
	_ticks(500)
	assert_int(_state.clock.tick).is_equal(tick)
	assert_str(_node()).is_equal("l1")
	assert_str(_error(_simulation.submit(CloseWormholeCommand.new()))).is_equal(
		"conversation_running"
	)
	assert_int(_phase()).is_equal(ActiveConversation.Phase.LINE)


func test_closing_the_wormhole_cuts_it_off() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	_advance()
	_state.gate.mode = GateState.RingMode.IDLE
	ConversationSystem.new().tick(_state)
	assert_int(_phase()).is_equal(ActiveConversation.Phase.ENDED)
	assert_bool(_state.conversations.active.cut_off).is_true()
	_advance()
	var record: TranscriptRecord = _state.conversations.transcripts[0]
	assert_bool(record.cut_off).is_true()
	assert_int(_state.budget.funds_k).is_equal(1)


func test_an_authored_end_can_lose_the_signal() -> void:
	var def: ConversationDef = _state.conversation_defs[CONV]
	def.node(&"end").signal_lost = true
	_to_choice()
	_simulation.submit(ChooseOptionCommand.new(1))
	assert_bool(_state.conversations.active.cut_off).is_true()
	_advance()
	assert_bool(_state.conversations.transcripts[0].cut_off).is_true()
	assert_int(_state.budget.funds_k).is_equal(111)


func test_phone_hang_up() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	assert_str(_error(_simulation.submit(EndConversationCommand.new()))).is_equal("not_phone")
	_state.conversations.active.channel = &"phone"
	_state.gate.mode = GateState.RingMode.IDLE
	ConversationSystem.new().tick(_state)
	assert_object(_state.conversations.active).is_not_null()
	assert_bool(_simulation.submit(EndConversationCommand.new()).is_ok).is_true()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.ENDED)
	assert_str(_error(_simulation.submit(EndConversationCommand.new()))).is_equal("already_ended")
	_advance()
	assert_object(_state.conversations.active).is_null()
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.RUNNING)


func _round_trip() -> GameState:
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	GameSetup.build(loaded, GameDefs.from_registry(Registry))
	loaded.conversation_defs[CONV] = make_def()
	return loaded


func test_a_save_at_every_phase_loads_back() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	var steps: Array[Callable] = [_advance, _advance, _advance, _advance]
	var expected: Array[ActiveConversation.Phase] = [
		ActiveConversation.Phase.OPENING,
		ActiveConversation.Phase.LINE,
		ActiveConversation.Phase.LINE,
		ActiveConversation.Phase.LINE,
		ActiveConversation.Phase.CHOICE,
	]
	for index: int in expected.size():
		if index > 0:
			steps[index - 1].call()
		var loaded: GameState = _round_trip()
		assert_int(loaded.conversations.active.phase).is_equal(expected[index])
		assert_str(String(loaded.conversations.active.node)).is_equal(_node())
		assert_array(loaded.clock.holds).contains([ConversationRules.HOLD])
	_simulation.submit(ChooseOptionCommand.new(1))
	var ended: GameState = _round_trip()
	assert_int(ended.conversations.active.phase).is_equal(ActiveConversation.Phase.ENDED)
	var other := Simulation.new(ended, [ConversationSystem.new()])
	other.submit(AdvanceConversationCommand.new())
	_advance()
	assert_str(JSON.stringify(ended.to_dict())).is_equal(JSON.stringify(_state.to_dict()))


func test_once_and_pick() -> void:
	var low := make_def()
	low.id = &"conv_low"
	low.priority = 1
	var high := make_def()
	high.id = &"conv_high"
	high.priority = 5
	high.once = true
	_state.conversation_defs.erase(CONV)
	_state.conversation_defs[low.id] = low
	_state.conversation_defs[high.id] = high
	var kindred: StringName = &"faction_kindred"
	assert_str(String(ConversationRules.pick(kindred, &"wormhole", &"", _state))).is_equal(
		"conv_high"
	)
	assert_str(String(ConversationRules.pick(kindred, &"phone", &"", _state))).is_empty()
	_state.conversations.count[&"conv_high"] = 1
	assert_str(String(ConversationRules.pick(kindred, &"wormhole", &"", _state))).is_equal(
		"conv_low"
	)
	low.worlds = [&"world_lintel"]
	assert_str(String(ConversationRules.pick(kindred, &"wormhole", &"world_x", _state))).is_empty()


func test_command_round_trip() -> void:
	var result: Result = CommandFactory.from_dict(ChooseOptionCommand.new(2).to_dict())
	var command: ChooseOptionCommand = result.value
	assert_int(command.index).is_equal(2)
	assert_bool(CommandFactory.from_dict({"type": "choose_option"}).is_ok).is_false()
	assert_bool(CommandFactory.from_dict(EndConversationCommand.new().to_dict()).is_ok).is_true()
	var advance: Result = CommandFactory.from_dict(AdvanceConversationCommand.new().to_dict())
	assert_bool(advance.value is AdvanceConversationCommand).is_true()


## A command that starts CONV, like a hail (used to start a conversation from a tick's flush).
class HailCommandFake:
	extends Command

	func get_type() -> StringName:
		return &"hail_fake"

	func validate(_state: GameState) -> CommandResult:
		return CommandResult.ok()

	func apply(state: GameState) -> void:
		ConversationRules.start(state, CONV, &"wormhole", &"world_lintel")

	func to_dict() -> Dictionary:
		return {"type": "hail_fake"}
