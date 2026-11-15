## Tests for the link opening and closing (M4.8-06): the opening plays on every channel with
## its words and can be skipped; the first line comes when it ends; at the end the picture
## cuts to LINK CLOSED or SIGNAL LOST, the transcript stays and only Close is offered; Close,
## Continue and Enter close it; transitions are skipped headless and with reduced motion.
## Bible: docs/content/dialogue-screen.md section 4
extends GdUnitTestSuite

var _fixture: DialogueFixture
var _screen: DialogueScreen


func before_test() -> void:
	_fixture = DialogueFixture.new(self)
	_screen = _fixture.screen


func after_test() -> void:
	Settings.set_value(&"display", &"ambient_movement", true)
	_fixture.dispose()


func _phase() -> ActiveConversation.Phase:
	return _fixture.state.conversations.active.phase


func test_the_opening_plays_on_each_channel_and_settles() -> void:
	_screen.opening_seconds = 1.0
	_fixture.start(&"conv_kindred_first_hail")
	assert_bool(_screen.link.is_opening()).is_true()
	assert_str(_screen.link.get_text()).is_equal("ESTABLISHING LINK")
	assert_int(_phase()).is_equal(ActiveConversation.Phase.OPENING)
	_screen.link._process(0.5)
	assert_int(_phase()).is_equal(ActiveConversation.Phase.OPENING)
	_screen.link._process(0.6)
	assert_bool(_screen.link.is_opening()).is_false()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.LINE)
	assert_str(_screen.link.get_text()).is_empty()


func test_the_phone_opening_and_skip() -> void:
	_screen.opening_seconds = 1.0
	_fixture.start(&"conv_committee_briefing", &"phone")
	assert_str(_screen.link.get_text()).is_equal("CONNECTING SECURE LINE")
	_screen.continue_pressed()
	assert_bool(_screen.link.is_opening()).is_false()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.LINE)
	assert_bool(_screen.transcript.is_typing()).is_true()


func test_the_end_shows_link_closed_and_only_close() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	for step: int in 2:
		_screen.continue_pressed()
	_screen.pick_number(1)
	_screen.continue_pressed()
	_screen.continue_pressed()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.ENDED)
	assert_str(_screen.link.get_text()).is_equal("LINK CLOSED")
	assert_int(_screen.link.get_mode()).is_equal(LinkTransition.Mode.CLOSED)
	var buttons: Array[Button] = _screen.answers.get_buttons()
	assert_int(buttons.size()).is_equal(1)
	assert_str(buttons[0].text).is_equal("Close")
	assert_int(_screen.transcript.get_texts().size()).is_equal(3)
	_screen.transcript.scroll_by(-100)
	assert_bool(_screen.pick_number(1)).is_false()
	_screen.continue_pressed()
	assert_bool(_screen.visible).is_false()
	assert_object(_fixture.state.conversations.active).is_null()


func test_a_cut_off_shows_signal_lost() -> void:
	_fixture.start(&"conv_committee_briefing", &"phone")
	_fixture.simulation.submit(EndConversationCommand.new())
	assert_str(_screen.link.get_text()).is_equal("SIGNAL LOST")
	assert_str(_screen.answers.get_buttons()[0].text).is_equal("Close")
	_screen.answers.get_buttons()[0].pressed.emit()
	assert_bool(_screen.visible).is_false()


func test_skipped_headless_and_with_reduced_motion() -> void:
	assert_float(LinkTransition.opening_seconds()).is_equal(0.0)
	_fixture.start(&"conv_kindred_first_hail")
	assert_bool(_screen.link.is_opening()).is_false()
	assert_int(_phase()).is_equal(ActiveConversation.Phase.LINE)
	Settings.set_value(&"display", &"ambient_movement", false)
	assert_float(LinkTransition.opening_seconds()).is_equal(0.0)


func test_a_load_at_the_end_shows_the_closed_link() -> void:
	_fixture.start(&"conv_committee_briefing", &"phone")
	_fixture.simulation.submit(EndConversationCommand.new())
	var other := DialogueScreen.new()
	_fixture.root.add_child(other)
	other.bind(_fixture.simulation)
	assert_str(other.link.get_text()).is_equal("SIGNAL LOST")
	assert_str(other.answers.get_buttons()[0].text).is_equal("Close")
