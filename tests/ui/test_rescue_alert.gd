## Tests for the rescue alert and the top bar's alert stack: the alert opens and takes focus
## when a check-in is missed, is not modal, says the outcome is uncertain and that waiting
## lowers the odds with no percentages (owner), forecasts the charge, Charge at maximum raises
## the banks, Go to Gate Room asks for that tab, Close or B hides it while the stack keeps it,
## the stack reopens it, it redraws while paused, and it fits 1280 × 720 in en and pt_BR with
## the real font. The shell shows check-ins as messages.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const SCREEN: Vector2 = Vector2(1280, 720)

var _root: Control = null
var _alert: RescueAlert = null
var _stack: AlertStack = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = RescueFixture.simulation(Fixture.state(), 0)
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = SCREEN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack = AlertStack.new()
	_alert = RescueAlert.new()
	_root.add_child(_stack)
	_root.add_child(_alert)
	_alert.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_alert.offset_left = 16.0
	_alert.offset_right = -16.0
	_alert.offset_top = 104.0
	add_child(_root)
	_alert.setup(_simulation)
	_stack.setup(_alert)
	await get_tree().process_frame


func after_test() -> void:
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func _state() -> GameState:
	return _simulation.state


func _miss() -> void:
	RescueFixture.send_and_miss(_simulation)
	await get_tree().process_frame
	await get_tree().process_frame


func _cancel() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_alert._unhandled_input(event)


func test_hidden_without_a_rescue() -> void:
	assert_bool(_alert.visible).is_false()
	assert_bool(_stack.get_rescue_button().visible).is_false()


func test_opens_with_focus_on_a_missed_check_in_and_says_the_odds_without_numbers() -> void:
	await _miss()
	assert_bool(_alert.visible).is_true()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_alert.get_default_focus())
	var lines: Array[String] = _alert.texts()
	assert_str(lines[0]).starts_with("T-1 MISSED ITS CHECK-IN (")
	assert_str(lines[1]).starts_with("Window: 71 h")
	assert_str(lines[2]).starts_with("Rescue: dial ")
	assert_str(lines[3]).starts_with("Threat ")
	assert_str(lines[3]).contains("is not certain, and waiting lowers the odds.")
	assert_str(lines[4]).starts_with("Charge needed ")
	for line: String in lines:
		assert_str(line).not_contains("%")


func test_is_not_modal() -> void:
	await _miss()
	assert_bool(_alert.visible).is_true()
	assert_float(_alert.get_combined_minimum_size().y).is_less(SCREEN.y / 2.0)
	assert_float(_alert.get_global_rect().end.y).is_less(SCREEN.y / 2.0 + 104.0)
	assert_int(_root.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_close_and_b_hide_it_and_the_stack_reopens_it() -> void:
	await _miss()
	_alert.get_close_button().pressed.emit()
	assert_bool(_alert.visible).is_false()
	var entry: Button = _stack.get_rescue_button()
	assert_bool(entry.visible).is_true()
	assert_str(entry.text).starts_with("T-1 missing  71 h")
	entry.pressed.emit()
	assert_bool(_alert.visible).is_true()
	_cancel()
	assert_bool(_alert.visible).is_false()
	assert_bool(entry.visible).is_true()


func test_go_to_gate_room_asks_for_the_tab() -> void:
	await _miss()
	var asked: Array[bool] = [false]
	_alert.gate_room_requested.connect(func() -> void: asked[0] = true)
	_alert.get_gate_button().pressed.emit()
	assert_bool(asked[0]).is_true()
	assert_bool(_alert.visible).is_false()


func test_charge_at_maximum_raises_the_banks_when_too_slow() -> void:
	await _miss()
	for room_id: StringName in _state().power.charge_rates:
		_state().power.charge_rates[room_id] = 0
	_state().power.stored_mwh = 0.0
	_alert.refresh()
	assert_str(String(RescueForecast.status(_state()))).is_not_equal(String(RescueForecast.ON_TIME))
	var button: Button = _alert.get_max_button()
	assert_bool(button.visible).is_true()
	assert_str(_alert.texts()[5]).is_not_empty()
	assert_str(_alert.texts()[4]).ends_with("never ready at this rate")
	var expected: Dictionary[StringName, int] = RescueForecast.max_rates(_state())
	button.grab_focus()
	(get_viewport().gui_get_focus_owner() as BaseButton).pressed.emit()
	assert_dict(_state().power.charge_rates).is_equal(expected)


func test_on_time_shows_the_forecast_and_no_button() -> void:
	await _miss()
	_state().power.stored_mwh = PowerRules.capacity_mwh(_state())
	_alert.refresh()
	assert_str(String(RescueForecast.status(_state()))).is_equal(String(RescueForecast.ON_TIME))
	assert_str(_alert.texts()[5]).starts_with("Charge for the rescue dial: ")
	assert_bool(_alert.get_max_button().visible).is_false()


func test_redraws_while_paused_on_the_signal_and_closes_with_the_window() -> void:
	await _miss()
	assert_bool(_state().clock.is_paused).is_true()
	RescueFixture.signal_team(_simulation)
	await get_tree().process_frame
	assert_str(_alert.texts()[2]).starts_with("Signal sent: T-1 reaches the Ring in 15 min")
	Fixture.advance(_simulation, ExpeditionRescue.SIGNAL_TICKS + 1)
	await get_tree().process_frame
	assert_bool(_alert.visible).is_false()
	assert_bool(_stack.get_rescue_button().visible).is_false()


@warning_ignore("unused_parameter")
func test_fits_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	await _miss()
	for room_id: StringName in _state().power.charge_rates:
		_state().power.charge_rates[room_id] = 0
	_alert.refresh()
	await get_tree().process_frame
	assert_float(_alert.get_combined_minimum_size().x).is_less_equal(SCREEN.x - 32.0)
	assert_float(_alert.get_global_rect().end.y).is_less_equal(SCREEN.y)
	assert_float(_stack.get_combined_minimum_size().x).is_less_equal(200.0)
	_assert_glyphs(_root)


func _assert_glyphs(node: Node) -> void:
	for child: Node in node.get_children():
		_assert_glyphs(child)
	var text: String = ""
	if node is Label:
		text = (node as Label).text
	elif node is Button:
		text = (node as Button).text
	if text.is_empty():
		return
	var control: Control = node as Control
	var font: Font = control.get_theme_font(&"font")
	for character: String in control.tr(text) if control.auto_translate_mode != 2 else text:
		if character == "\n":
			continue
		(
			assert_bool(font.has_char(character.unicode_at(0)))
			. override_failure_message("missing glyph '%s' in '%s'" % [character, text])
			. is_true()
		)
