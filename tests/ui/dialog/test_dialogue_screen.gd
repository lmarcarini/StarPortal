## Tests for the dialogue screen (M4.8-04): it opens on a start and moves to the first line,
## shows the top strip, the name plate and the line typing out; Continue shows the whole line,
## then moves on; answers by number or click, locked ones greyed with their reason; the player's
## answers appear as YOU; Close at the end closes it; a conversation already open (a load)
## shows at its phase; it reads only and submits commands.
## Bible: docs/content/dialogue-screen.md sections 1, 2, 5 and 6
extends GdUnitTestSuite

const ConversationTests := preload("res://tests/dialog/test_conversation_runner.gd")
const HAIL: StringName = &"conv_kindred_first_hail"

var _fixture: DialogueFixture
var _screen: DialogueScreen


func before_test() -> void:
	_fixture = DialogueFixture.new(self)
	_screen = _fixture.screen


func after_test() -> void:
	_fixture.dispose()


func _phase() -> ActiveConversation.Phase:
	return _fixture.state.conversations.active.phase


func _buttons() -> Array[Button]:
	return _screen.answers.get_buttons()


func test_opens_at_the_first_line_typing() -> void:
	assert_bool(_screen.visible).is_false()
	_fixture.start(HAIL)
	assert_bool(_screen.visible).is_true()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.LINE)
	var strip: Array[String] = _screen.get_strip_texts()
	assert_str(strip[0]).is_equal(ClockPlate.date_text(_screen.get_simulation().state.clock.tick))
	assert_str(strip[1]).is_equal("BASE ON HOLD")
	assert_str(strip[2]).is_equal("TRANSMISSION · RING · LINTEL")
	assert_int(_screen.transcript.get_current_label().visible_characters).is_equal(0)
	assert_bool(_screen.transcript.is_typing()).is_true()
	var plate: Array[String] = _screen.name_plate.get_texts()
	assert_str(plate[0]).is_equal("KINDRED ELDER")
	assert_str(plate[1]).is_equal("Speaker for the Kindred")
	assert_str(plate[2]).starts_with("STANDING ")
	assert_int(_buttons().size()).is_equal(1)
	assert_str(_buttons()[0].text).is_equal("Continue")


func test_typing_runs_at_forty_characters_a_second() -> void:
	_fixture.start(HAIL)
	_screen.transcript._process(0.5)
	assert_int(_screen.transcript.get_current_label().visible_characters).is_equal(20)
	_screen.transcript._process(60.0)
	assert_bool(_screen.transcript.is_typing()).is_false()
	assert_int(_screen.transcript.get_current_label().visible_characters).is_equal(-1)


func test_continue_shows_the_line_then_moves_on_and_answers_as_you() -> void:
	_fixture.start(HAIL)
	_screen.continue_pressed()
	assert_bool(_screen.transcript.is_typing()).is_false()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.LINE)
	_screen.continue_pressed()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.CHOICE)
	assert_int(_buttons().size()).is_equal(2)
	assert_str(_buttons()[0].text).is_equal("1   We come in peace and want to learn.")
	_screen.continue_pressed()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.CHOICE)
	assert_bool(_screen.pick_number(1)).is_true()
	var texts: Array[String] = _screen.transcript.get_texts()
	assert_str(texts[-2]).is_equal("YOU: We come in peace and want to learn.")
	assert_str(texts[-1]).is_equal("Kindred Elder: Then you are welcome here.")
	assert_bool(_screen.pick_number(1)).is_false()
	_screen.continue_pressed()
	_screen.continue_pressed()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.ENDED)
	assert_str(_buttons()[0].text).is_equal("Close")
	_buttons()[0].pressed.emit()
	assert_bool(_screen.visible).is_false()
	assert_object(_fixture.state.conversations.active).is_null()
	assert_int(_fixture.state.clock.mode).is_equal(ClockState.Mode.RUNNING)


func test_no_answers_while_typing() -> void:
	_fixture.start(HAIL)
	_screen.continue_pressed()
	_screen.continue_pressed()
	_fixture.state.conversations.active.phase = ActiveConversation.Phase.CHOICE
	_screen.transcript.add_line("X", Color.WHITE, "still typing", true)
	assert_bool(_screen.pick_number(1)).is_false()


func test_locked_answers_are_greyed_with_their_reason() -> void:
	_fixture.state.conversation_defs[ConversationTests.CONV] = ConversationTests.make_def()
	_fixture.state.factions.met.clear()
	_fixture.start(ConversationTests.CONV)
	for index: int in 6:
		_screen.continue_pressed()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.CHOICE)
	assert_bool(_buttons()[0].disabled).is_true()
	assert_str(_buttons()[0].text).contains("Requires contact with")
	assert_bool(_screen.pick_number(1)).is_false()
	assert_bool(_buttons()[1].disabled).is_false()


func test_a_click_on_the_transcript_continues() -> void:
	_fixture.start(HAIL)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_screen.transcript._gui_input(click)
	assert_bool(_screen.transcript.is_typing()).is_false()


func test_the_phone_channel_and_a_committee_still() -> void:
	_fixture.start(&"conv_committee_briefing", &"phone")
	assert_str(_screen.get_strip_texts()[2]).is_equal("SECURE LINE · EARTH")
	assert_str(_screen.name_plate.get_texts()[2]).starts_with("CONFIDENCE ")


func test_a_load_shows_the_conversation_at_its_phase() -> void:
	_fixture.start(HAIL)
	_screen.continue_pressed()
	_screen.continue_pressed()
	_screen.pick_number(2)
	var other := DialogueScreen.new()
	_fixture.root.add_child(other)
	other.bind(_fixture.simulation)
	assert_bool(other.visible).is_true()
	assert_array(other.transcript.get_texts()).is_equal(_screen.transcript.get_texts())
	assert_bool(other.transcript.is_typing()).is_false()
	assert_str(other.answers.get_buttons()[0].text).is_equal("Continue")
	_fixture.state.conversations.active = null
	other.bind(_fixture.simulation)
	assert_bool(other.visible).is_false()


func test_it_reads_only() -> void:
	_fixture.start(HAIL)
	var before: String = JSON.stringify(_fixture.state.to_dict())
	_screen.bind(_fixture.simulation)
	_screen.transcript.finish_typing()
	assert_str(JSON.stringify(_fixture.state.to_dict())).is_equal(before)


func test_the_speaker_name_is_readable() -> void:
	var state: GameState = _fixture.state
	for faction: StringName in state.faction_defs:
		var colour: Color = ConversationText.readable_accent(state, faction, DialogueScreen.GROUND)
		assert_float(UiPalette.contrast(colour, DialogueScreen.GROUND)).is_greater_equal(4.5)
	var dark := FactionDef.new()
	dark.id = &"faction_dark"
	dark.accent = Color(0.1, 0.05, 0.3)
	state.faction_defs[dark.id] = dark
	var fixed: Color = ConversationText.readable_accent(state, dark.id, DialogueScreen.GROUND)
	assert_float(UiPalette.contrast(fixed, DialogueScreen.GROUND)).is_greater_equal(4.5)
	assert_object(fixed).is_not_equal(dark.accent)
	_fixture.start(HAIL)
	var name_colour: Color = _screen.transcript.get_current_name_label().get_theme_color(
		&"font_color"
	)
	assert_object(name_colour).is_equal(
		ConversationText.readable_accent(state, &"faction_kindred", DialogueScreen.GROUND)
	)
