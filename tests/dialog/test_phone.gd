## Tests for phone calls (M4-12): the call waiting lamp shows while an Earth call waits and is in
## the time bar's focus order; Answer starts the conversation on channel phone (refused while
## another runs); hanging up ends it early as cut off.
## Bible: docs/content/m4-core-systems.md section 3 (Phone)
extends GdUnitTestSuite

const ConversationTests := preload("res://tests/dialog/test_conversation_runner.gd")
const TIME_BAR_SCENE: String = "res://src/ui/time_bar/time_bar.tscn"
const SENATE: StringName = &"faction_senate"

var _state: GameState
var _simulation: Simulation
var _bar: TimeBar = null


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = StoryFixture.state()
	var def: ConversationDef = ConversationTests.make_def()
	def.faction = SENATE
	def.channels = [&"phone"]
	_state.conversation_defs[def.id] = def
	var contact := PendingContact.new()
	contact.faction = SENATE
	contact.conversation = def.id
	contact.channel = &"phone"
	contact.expires_tick = 99999
	_state.factions.pending.append(contact)
	_simulation = Simulation.new(_state, [ConversationSystem.new()])
	SimClock.start(_simulation)
	_bar = (load(TIME_BAR_SCENE) as PackedScene).instantiate() as TimeBar
	add_child(_bar)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_bar):
		_bar.free()


func test_lamp_and_answer() -> void:
	_bar.refresh()
	var lamp: Button = _bar.get_call_button()
	assert_bool(lamp.visible).is_true()
	assert_str(lamp.text).is_equal("faction_senate")
	assert_str(lamp.tooltip_text).is_equal("Call waiting: faction_senate")
	assert_array(_bar.get_buttons()).contains([lamp])
	lamp.pressed.emit()
	assert_str(String(_state.conversations.active.channel)).is_equal("phone")
	assert_array(_state.factions.pending).is_empty()
	_bar.refresh()
	assert_bool(lamp.visible).is_false()
	assert_array(_bar.get_buttons()).not_contains([lamp])


func test_refused_while_a_conversation_runs() -> void:
	_state.conversations.active = ActiveConversation.new()
	assert_str(String(AnswerCallCommand.new().validate(_state).error_code)).is_equal(
		"conversation_running"
	)
	_bar.refresh()
	assert_bool(_bar.get_call_button().disabled).is_true()
	_state.conversations.active = null
	_state.factions.pending.clear()
	assert_str(String(AnswerCallCommand.new().validate(_state).error_code)).is_equal("no_call")


func test_hang_up_is_cut_off() -> void:
	_simulation.submit(AnswerCallCommand.new())
	_simulation.advance_tick()
	assert_bool(_simulation.submit(EndConversationCommand.new()).is_ok).is_true()
	assert_bool(_simulation.submit(AdvanceConversationCommand.new()).is_ok).is_true()
	assert_object(_state.conversations.active).is_null()
	assert_bool(_state.conversations.transcripts[0].cut_off).is_true()
