## Tests for the M4a test content (M4-18): three factions, HEARTH and TOLLGATE held by the
## Kindred and the Ossar, four requests, and conversations whose every path reaches its End;
## the Committee briefing calls on day 2 of a new game.
## Bible: docs/content/m4-core-systems.md section 8
extends GdUnitTestSuite

var _defs: GameDefs


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func _new_game() -> GameState:
	var state := GameState.new_game(5, _defs.balance)
	GameSetup.build_new(state, _defs)
	return state


func test_content_counts() -> void:
	assert_int(_defs.factions.size()).is_equal(3)
	assert_int(_defs.requests.size()).is_equal(4)
	assert_int(_defs.conversations.size()).is_equal(7)
	var state: GameState = _new_game()
	assert_str(String(state.galaxy.get_world(&"world_hearth").controller)).is_equal(
		"faction_kindred"
	)
	assert_str(String(state.galaxy.get_world(&"world_tollgate").controller)).is_equal(
		"faction_ossar"
	)
	assert_int(state.factions.standing[&"faction_ossar"]).is_equal(-40)
	assert_array(state.factions.met).is_equal([&"faction_committee"])


## Every path through every conversation (each answer at each choice) reaches its End.
func test_every_path_reaches_the_end() -> void:
	for def: ConversationDef in _defs.conversations:
		var none: Array[int] = []
		for path: Array in _paths(def, def.start, none):
			var state: GameState = _new_game()
			state.gate.mode = GateState.RingMode.LOCKED
			assert_bool(ConversationRules.start(state, def.id, def.channels[0], &"")).is_true()
			var answers: Array = path.duplicate()
			while state.conversations.active != null:
				var node: ConversationNodeDef = ConversationRules.current_node(state)
				if node.kind == ConversationNodeDef.Kind.LINE:
					ConversationRules.arrive(state, node.next)
				else:
					var answer: int = answers.pop_front()
					ConversationRules.choose(state, answer)
			var record: TranscriptRecord = state.conversations.transcripts[-1]
			assert_bool(record.cut_off).override_failure_message(String(def.id)).is_false()


## The briefing becomes a pending phone call at the start of day 2.
func test_briefing_calls_on_day_two() -> void:
	var state: GameState = _new_game()
	state.clock.tick = TimeMath.TICKS_PER_DAY
	FactionSystem.new().on_day(state)
	assert_int(state.factions.pending.size()).is_equal(1)
	assert_str(String(state.factions.pending[0].conversation)).is_equal("conv_committee_briefing")
	assert_str(String(state.factions.pending[0].channel)).is_equal("phone")


## The briefing files both addresses and offers the HEARTH survey.
func test_briefing_effects() -> void:
	var state: GameState = _new_game()
	var books: int = state.address_book.entries.size()
	ConversationRules.start(state, &"conv_committee_briefing", &"phone", &"")
	while state.conversations.active != null:
		ConversationRules.arrive(state, ConversationRules.current_node(state).next)
	assert_int(state.address_book.entries.size()).is_equal(books + 2)
	assert_str(String(state.requests.items[0].request)).is_equal("request_survey_hearth")


func _paths(def: ConversationDef, node_id: StringName, prefix: Array[int]) -> Array[Array]:
	var node: ConversationNodeDef = def.node(node_id)
	var found: Array[Array] = []
	match node.kind:
		ConversationNodeDef.Kind.END:
			found.append(prefix)
		ConversationNodeDef.Kind.LINE:
			found.append_array(_paths(def, node.next, prefix))
		ConversationNodeDef.Kind.CHOICE:
			for index: int in node.choices.size():
				var longer: Array[int] = prefix.duplicate()
				longer.append(index)
				found.append_array(_paths(def, node.choices[index].next, longer))
	return found
