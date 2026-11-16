## Tests for requests answered inside conversations (M4.10-05): an offer step offers its
## request on arrival and answers ACCEPT, DECLINE or "I will think about it"; accepting has
## exactly the effects of the Command screen's AcceptRequestCommand; thinking leaves it
## offered; the validator checks offer steps name real requests; the dialogue screen shows the
## terms on a paper card.
## Bible: docs/content/interface-rethink.md section 6
extends GdUnitTestSuite

const BRIEFING: StringName = &"conv_committee_briefing"
const REQUEST: StringName = &"request_survey_hearth"

var _defs: GameDefs


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func _at_offer() -> GameState:
	var state := GameState.new_game(5, _defs.balance)
	GameSetup.build_new(state, _defs)
	ConversationRules.start(state, BRIEFING, &"phone", &"")
	ConversationDriver.play(state)
	return state


func test_arriving_offers_and_shows_three_answers() -> void:
	var state: GameState = _at_offer()
	assert_bool(ConversationRules.current_node(state).is_offer()).is_true()
	var record: RequestRecord = RequestRules.open_instance(state, REQUEST)
	assert_int(record.state).is_equal(RequestRecord.RequestState.OFFERED)
	var shown: Array[Dictionary] = ConversationRules.choices(state)
	assert_int(shown.size()).is_equal(3)
	var key: StringName = shown[0]["text_key"]
	assert_str(String(key)).is_equal("CONV_OFFER_ACCEPT")


func test_accepting_matches_the_command_screen() -> void:
	var state: GameState = _at_offer()
	var twin: GameState = _at_offer()
	var uid: int = RequestRules.open_instance(twin, REQUEST).uid
	AcceptRequestCommand.new(uid).apply(twin)
	assert_str(String(ChooseOptionCommand.new(0).validate(state).error_code)).is_empty()
	ConversationRules.choose(state, OfferStep.Answer.ACCEPT)
	assert_dict(state.requests.to_dict()).is_equal(twin.requests.to_dict())
	assert_dict(state.budget.to_dict()).is_equal(twin.budget.to_dict())
	assert_dict(state.factions.to_dict()).is_equal(twin.factions.to_dict())


func test_declining_matches_the_command_screen() -> void:
	var state: GameState = _at_offer()
	var twin: GameState = _at_offer()
	DeclineRequestCommand.new(RequestRules.open_instance(twin, REQUEST).uid).apply(twin)
	ConversationRules.choose(state, OfferStep.Answer.DECLINE)
	assert_dict(state.requests.to_dict()).is_equal(twin.requests.to_dict())
	assert_dict(state.factions.to_dict()).is_equal(twin.factions.to_dict())


func test_thinking_leaves_it_offered_and_moves_on() -> void:
	var state: GameState = _at_offer()
	ConversationRules.choose(state, OfferStep.Answer.THINK)
	var record: RequestRecord = RequestRules.open_instance(state, REQUEST)
	assert_int(record.state).is_equal(RequestRecord.RequestState.OFFERED)
	assert_int(state.conversations.active.phase).is_equal(ActiveConversation.Phase.ENDED)
	ConversationRules.advance(state)
	var lines: Array[String] = TranscriptText.lines(state, state.conversations.transcripts[-1])
	assert_str("\n".join(lines)).contains(tr(&"CONV_OFFER_THINK"))


func test_validator_checks_offer_steps() -> void:
	var briefing: ConversationDef = Registry.get_def(BRIEFING).duplicate(true) as ConversationDef
	var refs: Dictionary[StringName, DefBase] = {REQUEST: Registry.get_def(REQUEST)}
	assert_array(briefing.get_content_errors(refs)).is_empty()
	for node: ConversationNodeDef in briefing.nodes:
		if node.is_offer():
			node.offer_request = &"request_nowhere"
	var errors: Array[String] = briefing.get_content_errors(refs)
	assert_str("\n".join(errors)).contains("unknown request")


func test_terms_card_shows_the_request() -> void:
	var state: GameState = _at_offer()
	var card: RequestTermsCard = auto_free(RequestTermsCard.new())
	card.show_terms(state, state.request_defs[REQUEST])
	assert_bool(card.visible).is_true()
	assert_int(card.get_texts().size()).is_greater(1)
	card.show_terms(state, null)
	assert_bool(card.visible).is_false()
