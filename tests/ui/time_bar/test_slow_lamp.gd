## The top bar while slowed (M4.7-05): the cruise speed stays shown, the lamp names the reason
## with a shape, Faster overrides when it can and its hint says why when it cannot.
## Bible: docs/content/event-time.md section 4
extends GdUnitTestSuite

const TIME_BAR_SCENE: String = "res://src/ui/time_bar/time_bar.tscn"

var _bar: TimeBar = null
var _state: GameState = null
var _locale: String = ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_state = GameState.new_game(4, Registry.balance())
	GameSetup.build_new(_state, GameDefs.from_registry(Registry))
	SimClock.start(Simulation.new(_state))
	SimClock.set_speed_index(3)
	SimClock.resume()
	_bar = (load(TIME_BAR_SCENE) as PackedScene).instantiate() as TimeBar
	add_child(_bar)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_bar):
		_bar.free()
	TranslationServer.set_locale(_locale)


func _speed_text() -> String:
	return (_bar.find_child("SpeedLabel", true, false) as Label).text


func _slow(reason: StringName, source: StringName = &"") -> void:
	TimeControl.add_slow(_state.clock, reason, source)
	EventBus.slow_changed.emit(_state.clock.slows.duplicate())


func _faster_button() -> Button:
	return _bar.get_buttons()[2]


func test_hidden_at_cruise() -> void:
	assert_bool(_bar.get_slow_lamp().visible).is_false()
	assert_str(_speed_text()).is_equal("10×")


func test_a_call_shows_its_reason_and_faster_overrides() -> void:
	_slow(&"awaiting_answer", &"phone_kindred")
	var lamp: SlowLamp = _bar.get_slow_lamp()
	assert_str(lamp.get_text()).is_equal("SLOW · call waiting")
	assert_str(String(lamp.get_status())).is_equal("warn")
	assert_str(_speed_text()).is_equal("10×")
	assert_str(_faster_button().tooltip_text).contains("10×")
	_bar.faster()
	SimClock.step_ticks(1)
	assert_array(_state.clock.slows).is_empty()
	assert_int(_state.clock.speed_index).is_equal(3)
	assert_bool(lamp.visible).is_false()


func test_a_conversation_cannot_be_overridden() -> void:
	_slow(&"conversation")
	var lamp: SlowLamp = _bar.get_slow_lamp()
	assert_str(lamp.get_text()).is_equal("SLOW · conversation")
	assert_str(String(lamp.get_status())).is_equal("alarm")
	assert_str(_faster_button().tooltip_text).contains("conversation")
	SimClock.set_speed_index(2)
	_bar.faster()
	assert_int(_state.clock.speed_index).is_equal(3)
	assert_array(_state.clock.slows).has_size(1)


func test_labels_for_each_reason() -> void:
	var expected: Dictionary[StringName, String] = {
		&"gate_ops": "gate",
		&"dialling": "dialling",
		&"incursion": "intruders",
		&"awaiting_answer/rescue": "decision waiting",
		&"awaiting_answer/incoming": "call waiting",
	}
	for key: StringName in expected:
		assert_str(tr(SlowLamp.label_key(key))).is_equal(expected[key])


func test_slower_and_pause_work_as_before() -> void:
	_slow(&"gate_ops")
	SimClock.slower()
	assert_int(_state.clock.speed_index).is_equal(2)
	SimClock.toggle_pause()
	assert_bool(SimClock.is_running()).is_false()
	assert_str(_bar.get_slow_lamp().get_text()).is_equal("SLOW · gate")


func test_fits_pt_br() -> void:
	TranslationServer.set_locale("pt_BR")
	await get_tree().process_frame
	var without: float = _bar.get_combined_minimum_size().x
	_slow(&"awaiting_answer", &"rescue")
	await get_tree().process_frame
	var lamp_width: float = _bar.get_slow_lamp().get_combined_minimum_size().x
	assert_float(lamp_width).is_less_equal(240.0)
	assert_float(_bar.get_combined_minimum_size().x - without).is_less_equal(260.0)
