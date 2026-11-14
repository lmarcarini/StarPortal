## Tests for the conversation runner (M4-08): lines advance by in-game minutes at 1× (faster
## speeds drop to 1×), choices come by command and are checked, End applies its effects and
## records the transcript, closing the wormhole cuts it off, a save mid-line continues, and pick()
## chooses the best available conversation.
## Bible: docs/content/m4-core-systems.md section 3
extends GdUnitTestSuite

const CONV: StringName = &"conv_test"

var _state: GameState
var _simulation: Simulation


static func _effect_money(amount_k: int) -> ChangeMoneyEffect:
	var effect := ChangeMoneyEffect.new()
	effect.amount_k = amount_k
	return effect


static func _line(id: StringName, minutes: int, next: StringName) -> ConversationNodeDef:
	var node := ConversationNodeDef.new()
	node.id = id
	node.text_key = &"K"
	node.minutes = minutes
	node.next = next
	return node


## l1 (2 min, +1k) → l2 (3 min) → l3 (1 min) → ask → [0: locked unless met, show_locked;
## 1: +10k → end (+100k)].
static func make_def() -> ConversationDef:
	var def := ConversationDef.new()
	def.id = CONV
	def.faction = &"faction_kindred"
	def.channels = [&"wormhole"]
	def.start = &"l1"
	var l1: ConversationNodeDef = _line(&"l1", 2, &"l2")
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
	def.nodes = [l1, _line(&"l2", 3, &"l3"), _line(&"l3", 1, &"ask"), ask, end]
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


func test_lines_advance_by_minutes_and_the_clock_slows() -> void:
	_state.clock.speed_index = ClockState.NORMAL_SPEED_INDEX + 2
	assert_bool(ConversationRules.start(_state, CONV, &"wormhole", &"world_lintel")).is_true()
	assert_int(_state.clock.speed_index).is_equal(ClockState.NORMAL_SPEED_INDEX + 2)
	assert_int(TimeControl.effective_speed_index(_state.clock)).is_equal(
		ClockState.NORMAL_SPEED_INDEX
	)
	assert_int(_state.budget.funds_k).is_equal(1)
	assert_bool(ConversationRules.start(_state, CONV, &"wormhole", &"")).is_false()
	_ticks(2)
	assert_str(_node()).is_equal("l1")
	_state.clock.speed_index = ClockState.NORMAL_SPEED_INDEX + 2
	_ticks(1)
	assert_str(_node()).is_equal("l2")
	assert_int(TimeControl.effective_speed_index(_state.clock)).is_equal(
		ClockState.NORMAL_SPEED_INDEX
	)
	_ticks(2)
	assert_str(_node()).is_equal("l2")
	_ticks(1)
	assert_str(_node()).is_equal("l3")
	_ticks(1)
	assert_str(_node()).is_equal("ask")
	_ticks(50)
	assert_str(_node()).is_equal("ask")


func test_choices_and_end() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	_ticks(7)
	var shown: Array[Dictionary] = ConversationRules.choices(_state)
	assert_int(shown.size()).is_equal(2)
	assert_bool(shown[0]["enabled"]).is_false()
	assert_bool(shown[0]["reason"] is FactionMetCondition).is_true()
	assert_str(String(_simulation.submit(ChooseOptionCommand.new(0)).error_code)).is_equal(
		"choice_locked"
	)
	assert_str(String(_simulation.submit(ChooseOptionCommand.new(5)).error_code)).is_equal(
		"no_such_choice"
	)
	assert_bool(_simulation.submit(ChooseOptionCommand.new(1)).is_ok).is_true()
	_ticks(1)
	assert_object(_state.conversations.active).is_null()
	assert_int(_state.budget.funds_k).is_equal(111)
	var record: TranscriptRecord = _state.conversations.transcripts[0]
	assert_bool(record.cut_off).is_false()
	assert_int(record.path.size()).is_equal(5)
	assert_int(record.path[3][1]).is_equal(1)
	assert_int(_state.conversations.count[CONV]).is_equal(1)
	assert_str(String(_simulation.submit(ChooseOptionCommand.new(1)).error_code)).is_equal(
		"no_conversation"
	)


func test_choose_while_paused_applies_at_once() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	_ticks(7)
	_state.clock.mode = ClockState.Mode.PAUSED
	assert_bool(_simulation.submit(ChooseOptionCommand.new(1)).is_ok).is_true()
	assert_object(_state.conversations.active).is_null()
	assert_bool(_simulation.submit(ChooseOptionCommand.new(1)).is_ok).is_false()


func test_closing_the_wormhole_cuts_it_off() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	_ticks(3)
	_state.gate.mode = GateState.RingMode.IDLE
	_ticks(1)
	assert_object(_state.conversations.active).is_null()
	var record: TranscriptRecord = _state.conversations.transcripts[0]
	assert_bool(record.cut_off).is_true()
	assert_int(_state.budget.funds_k).is_equal(1)


func test_close_and_choose_in_one_tick() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	_ticks(7)
	_simulation.submit(ChooseOptionCommand.new(1))
	_state.gate.mode = GateState.RingMode.IDLE
	_ticks(1)
	assert_int(_state.conversations.transcripts.size()).is_equal(1)
	assert_object(_state.conversations.active).is_null()


func test_phone_hang_up() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	assert_str(String(_simulation.submit(EndConversationCommand.new()).error_code)).is_equal(
		"not_phone"
	)
	_state.conversations.active.channel = &"phone"
	_state.gate.mode = GateState.RingMode.IDLE
	_ticks(1)
	assert_object(_state.conversations.active).is_not_null()
	assert_bool(_simulation.submit(EndConversationCommand.new()).is_ok).is_true()
	_ticks(1)
	assert_object(_state.conversations.active).is_null()


func test_save_mid_line_continues_identically() -> void:
	ConversationRules.start(_state, CONV, &"wormhole", &"")
	_ticks(3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	GameSetup.build(loaded, GameDefs.from_registry(Registry))
	loaded.conversation_defs[CONV] = make_def()
	var other := Simulation.new(loaded, [ConversationSystem.new()])
	for index: int in 3:
		_simulation.advance_tick()
		other.advance_tick()
	assert_str(JSON.stringify(loaded.to_dict())).is_equal(JSON.stringify(_state.to_dict()))


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
