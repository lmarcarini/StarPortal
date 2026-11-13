## Tests for the conversation panel (M4-13): it opens on a start, adds lines as they arrive,
## shows answers (locked ones greyed with a reason), picks by click and by keys 1-4, shows
## "(signal lost)" on a cut-off, fits the right third, and never changes the state itself.
## Bible: docs/content/m4-core-systems.md section 3
extends GdUnitTestSuite

const ConversationTests := preload("res://tests/dialog/test_conversation_runner.gd")

var _state: GameState
var _simulation: Simulation
var _root: Control
var _panel: ConversationPanel


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = StoryFixture.state()
	_state.conversation_defs[ConversationTests.CONV] = ConversationTests.make_def()
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.clock.mode = ClockState.Mode.RUNNING
	_simulation = Simulation.new(_state, [ConversationSystem.new()])
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	_panel = ConversationPanel.new()
	_root.add_child(_panel)
	add_child(_root)
	_panel.setup(_simulation)


func after_test() -> void:
	EventBus.bind_simulation(null)
	_root.free()


func _start() -> void:
	ConversationRules.start(_state, ConversationTests.CONV, &"wormhole", &"")
	_simulation.advance_tick()


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func test_opens_and_adds_lines() -> void:
	assert_bool(_panel.visible).is_false()
	_start()
	assert_bool(_panel.visible).is_true()
	assert_int(_panel.get_line_texts().size()).is_equal(1)
	_ticks(6)
	assert_int(_panel.get_line_texts().size()).is_equal(3)
	var buttons: Array[Button] = _panel.get_choice_buttons()
	assert_int(buttons.size()).is_equal(2)
	assert_bool(buttons[0].disabled).is_true()
	assert_str(buttons[0].text).contains("(Requires contact with")
	assert_str(buttons[1].text).starts_with("2. ")


func test_click_chooses_and_signal_lost() -> void:
	_start()
	_ticks(6)
	_state.clock.mode = ClockState.Mode.PAUSED
	_panel.get_choice_buttons()[1].pressed.emit()
	assert_object(_state.conversations.active).is_null()
	assert_array(_panel.get_choice_buttons()).is_empty()
	ConversationRules.start(_state, ConversationTests.CONV, &"wormhole", &"")
	_state.gate.mode = GateState.RingMode.IDLE
	_state.clock.mode = ClockState.Mode.RUNNING
	_ticks(1)
	assert_str(_panel.get_line_texts()[-1]).is_equal("(signal lost)")


func test_number_key_chooses() -> void:
	_start()
	_ticks(6)
	_state.clock.mode = ClockState.Mode.PAUSED
	var first := InputEventAction.new()
	first.action = &"dialog_choice_1"
	first.pressed = true
	_panel._unhandled_input(first)
	assert_object(_state.conversations.active).is_not_null()
	var second := InputEventAction.new()
	second.action = &"dialog_choice_2"
	second.pressed = true
	_panel._unhandled_input(second)
	assert_object(_state.conversations.active).is_null()


func test_fits_the_right_third_and_reads_only() -> void:
	_start()
	var before: String = JSON.stringify(_state.to_dict())
	_panel.setup(_simulation)
	assert_str(JSON.stringify(_state.to_dict())).is_equal(before)
	await get_tree().process_frame
	var rect: Rect2 = _panel.get_global_rect()
	assert_float(rect.position.x).is_greater_equal(1280.0 * 2.0 / 3.0 - 1.0)
	assert_float(rect.end.x).is_less_equal(1280.0)
	assert_float(rect.end.y).is_less_equal(720.0)
